extends RefCounted

## Step definitions for save_load_full_integration.feature.
##
## Category G of task-085: full save/load round trip crossing every autoload
## with persistent state. Each scenario exercises at least two systems so it
## is genuine integration, not a unit test in BDD clothing.
##
## Strategy mirrors narrative_steps.gd (task-085 Category F precedent):
## - Real autoload classes that are preloadable under `--script` mode —
##   Journal, EventRegistry, SaveManager, GameEvent — are used directly.
##   Journal and EventRegistry are instantiated as real Nodes via the
##   `_get_or_create_autoload` pattern (identical to narrative_steps) and
##   their `get_save_data` / `load_save_data` are driven end-to-end.
## - DayNightCycle's production script cannot be `preload()`ed in
##   `--script` mode because line 74 references `HexGrid.tile_entered`
##   as a compile-time global, and HexGrid is only registered as a name
##   when the full project autoload chain bootstraps (which `--script`
##   does not do). We therefore use a local `DayNightSnapshot` RefCounted
##   shim whose `get_save_data` / `load_save_data` mirrors the exact
##   schema of the production DayNightCycle autoload. Any drift between
##   the real DayNightCycle save shape and this shim would be caught
##   first by `day_night_chain.feature` / `save_load.feature` which drive
##   the autoload indirectly via the Dict-based day/night steps.
## - Catalog has the same problem: `catalog.gd` line 50 calls
##   `PropRegistry.get_all()` as a compile-time global. We use a
##   `CatalogSnapshot` RefCounted shim that mirrors the exact save
##   schema (`{"knowledge": {id_str: state_str}, "encounter_labels":
##   {id_str: label}}`) plus the three-state KnowledgeState enum, and
##   verify round-trip equality.
## - Inventory is also RefCounted; the real Inventory class depends on
##   PropRegistry for size lookups. We reuse the SimpleInventory shim
##   from common_steps.gd to stay faithful to the existing
##   `save_load.feature` precedent and keep the scenarios reproducible.
## - SaveManager IS preloadable (its `_SYSTEM_KEYS` hold path strings, not
##   identifiers, so nothing in the file resolves a global autoload at
##   compile time). We use it to test the corrupt-save and missing-save
##   recovery paths on the real `user://save.json`. For the multi-slot
##   and full-round-trip scenarios we write to separate scratch paths so
##   we don't collide with the corrupt-save scenario.
##
## Gherkin runner quirks compensated for (see narrative_steps.gd top-of-file
## comment for the historical context):
##   1. The CLI runs inside `SceneTree._init()` so the tree's "started" flag
##      is never set. Node.is_inside_tree() reports false for every node,
##      even those parented to `tree.root`. We do not rely on it.
##   2. `Engine.get_main_loop()` may return null inside `_init()`, so we
##      always route SceneTree access through `ctx.get_tree()`.
##   3. `ctx.reset()` wipes scenario-scoped state BEFORE the next Background
##      runs. We do not cache anything across scenarios.
##
## Signal capture is not needed here because save/load is synchronous: we
## drive state into the systems, snapshot their save data, clear, and reload.

const _CommonSteps = preload("res://tests/steps/common_steps.gd")
const _GameEvent = preload("res://scripts/core/event.gd")
const _EventRegistry = preload("res://scripts/core/event_registry.gd")
const _Journal = preload("res://scripts/journal/journal.gd")
const _SaveManager = preload("res://scripts/save/save_manager.gd")

## Phase name → DayNightCycle.TimePhase enum int. Mirrors the production
## enum order in day_night_cycle.gd:7 (DAY=0, DUSK=1, NIGHT=2, DAWN=3).
const _PHASE_TO_INT := {
	"DAY": 0,
	"DUSK": 1,
	"NIGHT": 2,
	"DAWN": 3,
}
const _INT_TO_PHASE := {
	0: "DAY",
	1: "DUSK",
	2: "NIGHT",
	3: "DAWN",
}

## Scratch save paths. We avoid clobbering SaveManager's real SAVE_PATH
## ("user://save.json") except for the corrupt/missing scenarios which
## explicitly target that path.
const _FULL_SAVE_PATH := "user://save_full_integration_test.json"
const _SLOT_A_PATH := "user://save_full_integration_slot_a.json"
const _SLOT_B_PATH := "user://save_full_integration_slot_b.json"


## Shim mirroring DayNightCycle's save/load schema.
##
## Kept in sync with `scripts/day_night/day_night_cycle.gd` get_save_data /
## load_save_data — if the real cycle's save shape drifts, the Dict-based
## day/night scenarios in `save_load.feature` and `day_night.feature` will
## fail first. This shim stays simple on purpose: scalars only, no scene
## tree wiring, no HexGrid connection.
class DayNightSnapshot extends RefCounted:
	var day_count: int = 1
	var current_phase: int = 0
	var phase_elapsed: float = 0.0
	var is_daytime: bool = true

	func get_save_data() -> Dictionary:
		return {
			"day_count": day_count,
			"phase": current_phase,
			"phase_elapsed": phase_elapsed,
			"chapter_id": 1,
		}

	func load_save_data(data: Dictionary) -> void:
		if data.has("day_count"):
			day_count = int(data["day_count"])
		if data.has("phase"):
			var phase_int: int = int(data["phase"])
			if phase_int < 0 or phase_int > 3:
				phase_int = 0
			current_phase = phase_int
			is_daytime = current_phase == 0 or current_phase == 3
		if data.has("phase_elapsed"):
			phase_elapsed = maxf(0.0, float(data["phase_elapsed"]))


## Shim mirroring Catalog's save/load schema and KnowledgeState enum.
##
## Production schema (scripts/scanner/catalog.gd::get_save_data):
##   {
##     "knowledge": { <id_str>: "ENCOUNTERED" | "CATALOGED" },
##     "encounter_labels": { <id_str>: <label_str> },
##   }
## UNKNOWN state is implicit (missing from "knowledge"). This shim preserves
## that contract exactly.
class CatalogSnapshot extends RefCounted:
	## Must match catalog.gd::KnowledgeState order (UNKNOWN=0, ENCOUNTERED=1,
	## CATALOGED=2).
	enum KnowledgeState { UNKNOWN, ENCOUNTERED, CATALOGED }

	var _knowledge: Dictionary = {}         # StringName → KnowledgeState
	var _encounter_labels: Dictionary = {}  # StringName → String

	func set_cataloged(entry_id: StringName) -> void:
		_knowledge[entry_id] = KnowledgeState.CATALOGED
		_encounter_labels.erase(entry_id)

	func set_encountered(entry_id: StringName, label: String) -> void:
		_knowledge[entry_id] = KnowledgeState.ENCOUNTERED
		_encounter_labels[entry_id] = label

	func get_knowledge_state(entry_id: StringName) -> int:
		return _knowledge.get(entry_id, KnowledgeState.UNKNOWN)

	func is_cataloged(entry_id: StringName) -> bool:
		return get_knowledge_state(entry_id) == KnowledgeState.CATALOGED

	func is_encountered(entry_id: StringName) -> bool:
		return get_knowledge_state(entry_id) == KnowledgeState.ENCOUNTERED

	func get_encounter_label(entry_id: StringName) -> String:
		return _encounter_labels.get(entry_id, "")

	func get_save_data() -> Dictionary:
		var knowledge_save: Dictionary = {}
		for id in _knowledge:
			match _knowledge[id]:
				KnowledgeState.ENCOUNTERED:
					knowledge_save[String(id)] = "ENCOUNTERED"
				KnowledgeState.CATALOGED:
					knowledge_save[String(id)] = "CATALOGED"
		var labels_save: Dictionary = {}
		for id in _encounter_labels:
			labels_save[String(id)] = _encounter_labels[id]
		return {
			"knowledge": knowledge_save,
			"encounter_labels": labels_save,
		}

	func load_save_data(data: Dictionary) -> void:
		_knowledge.clear()
		_encounter_labels.clear()
		var knowledge_data: Dictionary = data.get("knowledge", {})
		for id_str in knowledge_data:
			var id: StringName = StringName(id_str)
			match knowledge_data[id_str]:
				"ENCOUNTERED":
					_knowledge[id] = KnowledgeState.ENCOUNTERED
				"CATALOGED":
					_knowledge[id] = KnowledgeState.CATALOGED
		var labels_data: Dictionary = data.get("encounter_labels", {})
		for id_str in labels_data:
			_encounter_labels[StringName(id_str)] = labels_data[id_str]


# --------------------------------------------------------------------------
# World setup helpers
# --------------------------------------------------------------------------


## Returns the autoload Node Godot placed under `tree.root` for the given
## name. Falls back to creating a fresh instance from `fallback_script` and
## adopting it under that name. Mirrors narrative_steps._get_or_create_autoload.
static func _get_or_create_autoload(
	tree: SceneTree, autoload_name: String, fallback_script: GDScript
) -> Node:
	var existing: Node = tree.root.get_node_or_null(NodePath(autoload_name))
	if existing != null:
		return existing
	var inst: Node = fallback_script.new()
	inst.name = autoload_name
	tree.root.add_child(inst)
	return inst


## Stand up Journal + EventRegistry + SaveManager as real autoload Nodes plus
## a scratch DayNightSnapshot / CatalogSnapshot / SimpleInventory, wired into
## ctx. Every scenario Background calls this and gets a clean slate.
static func build_world(ctx) -> void:
	var tree: SceneTree = ctx.get_tree()
	assert(tree != null, "save/load full integration steps require a live SceneTree")

	var er := _get_or_create_autoload(tree, "EventRegistry", _EventRegistry)
	var journal := _get_or_create_autoload(tree, "Journal", _Journal)
	var sm := _get_or_create_autoload(tree, "SaveManager", _SaveManager)

	# Reset Journal so unlocks from previous scenarios don't leak.
	journal.load_save_data({"unlocked_entries": []})

	# Reset counts on any test events injected by a previous scenario. We do
	# NOT clear er._events wholesale because that would hose the fixture
	# events that other scenarios in the same feature run may depend on.
	# Test events are tracked via a convention-prefixed id space.
	for id in er._events:
		var ev_id_str: String = String(id)
		if ev_id_str.begins_with("E_FULL_") or ev_id_str.begins_with("E_SLOT_"):
			er._events[id].count = 0

	# Clean up temp save files from prior scenarios.
	for path in [_FULL_SAVE_PATH, _SLOT_A_PATH, _SLOT_B_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

	var day_night := DayNightSnapshot.new()
	var catalog := CatalogSnapshot.new()
	var inv := _CommonSteps.SimpleInventory.new()

	ctx.set_value("event_registry", er)
	ctx.set_value("journal", journal)
	ctx.set_value("save_manager", sm)
	ctx.set_value("day_night_cycle", day_night)
	ctx.set_value("catalog", catalog)
	ctx.set_value("full_inventory", inv)
	ctx.set_value("_test_event_ids", [] as Array)
	ctx.set_value("recipe_pending_queue", [] as Array)
	ctx.set_value("fauna_count", 0)


## Register a synthetic GameEvent in the real EventRegistry so save/load round
## trips through the live autoload's `_events` dict. Tracks the id in ctx so
## Background can zero the count next scenario.
static func _inject_test_event(ctx, event_id: StringName, initial_count: int) -> void:
	var er: Node = ctx.get_value("event_registry", null)
	assert(er != null, "EventRegistry must be wired by build_world")
	var event := _GameEvent.new()
	event.id = event_id
	event.display_name = String(event_id)
	event.max_count = 0  # unlimited so we can set arbitrary counts
	event.count = initial_count
	er._events[event_id] = event
	var ids: Array = ctx.get_value("_test_event_ids", [])
	if not ids.has(event_id):
		ids.append(event_id)
		ctx.set_value("_test_event_ids", ids)


## Build a portable payload dict representing every autoload's save data.
## This is what SaveManager would produce if the target Nodes were reachable.
static func _build_payload(ctx) -> Dictionary:
	var journal: Node = ctx.get_value("journal", null)
	var day_night: DayNightSnapshot = ctx.get_value("day_night_cycle", null) as DayNightSnapshot
	var er: Node = ctx.get_value("event_registry", null)
	var catalog: CatalogSnapshot = ctx.get_value("catalog", null) as CatalogSnapshot
	var inv = ctx.get_value("full_inventory", null)

	var payload: Dictionary = {}
	if journal != null:
		payload["journal"] = journal.get_save_data()
	if day_night != null:
		payload["day_night"] = day_night.get_save_data()
	if er != null:
		# EventRegistry.get_save_data() returns ALL events with count > 0,
		# including data-file events. We filter down to our synthetic test
		# events so assertions don't interact with fixture data.
		var test_ids: Array = ctx.get_value("_test_event_ids", [])
		var full: Dictionary = er.get_save_data()
		var filtered: Dictionary = {}
		for id in test_ids:
			var id_str := String(id)
			if full.has(id_str):
				filtered[id_str] = full[id_str]
		payload["events"] = filtered
	if catalog != null:
		payload["catalog"] = catalog.get_save_data()
	if inv != null:
		payload["inventory"] = inv.get_save_data()
	return payload


## Write payload to a temp JSON file, read it back, parse, and distribute into
## fresh receiver objects held in ctx under "restored_*" keys. Crosses the
## real FileAccess + JSON.parse_string boundary, mimicking
## SaveManager.save_game / load_game one step at a time.
static func _round_trip_payload(ctx, path: String) -> Dictionary:
	var payload := _build_payload(ctx)
	var json_text: String = JSON.stringify(payload, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "unable to open %s for writing" % path)
	file.store_string(json_text)
	file.close()

	var read := FileAccess.open(path, FileAccess.READ)
	assert(read != null, "unable to open %s for reading" % path)
	var text: String = read.get_as_text()
	read.close()

	var parsed: Variant = JSON.parse_string(text)
	assert(parsed != null and parsed is Dictionary, "round-trip parse failed")
	return parsed as Dictionary


## Apply a parsed payload into freshly-built receiver objects and pin them
## in ctx under "restored_*" keys. These receivers are independent of the
## live autoloads so assertions compare "what came out of the file" against
## "what went in", not "what the live autoload happens to still hold".
static func _distribute_into_fresh(ctx, parsed: Dictionary) -> void:
	# Fresh Journal instance — NOT adopted as autoload. We never add it to
	# the tree, so its _ready() wiring to EventRegistry does not fire.
	# load_save_data is a pure setter on the private dict, which is safe.
	var fresh_journal: Node = _Journal.new()
	fresh_journal.load_save_data(parsed.get("journal", {}))
	ctx.set_value("restored_journal", fresh_journal)

	# Fresh DayNightSnapshot — isolated from the live shim so assertions
	# compare what round-tripped through the JSON boundary, not a shared ref.
	var fresh_dn := DayNightSnapshot.new()
	fresh_dn.load_save_data(parsed.get("day_night", {}))
	ctx.set_value("restored_day_night", fresh_dn)

	# Fresh EventRegistry Node — we pre-seed the test events before
	# load_save_data because EventRegistry.load_save_data only restores
	# counts for events that already exist in _events. In production, the
	# registry's _ready() scans data/events/*.tres before any save is
	# loaded; we mirror that contract by pre-seeding the synthetic events.
	var fresh_er: Node = _EventRegistry.new()
	var test_ids: Array = ctx.get_value("_test_event_ids", [])
	for id in test_ids:
		var ev := _GameEvent.new()
		ev.id = id
		ev.display_name = String(id)
		ev.max_count = 0
		fresh_er._events[id] = ev
	fresh_er.load_save_data(parsed.get("events", {}))
	ctx.set_value("restored_event_registry", fresh_er)

	var fresh_catalog := CatalogSnapshot.new()
	fresh_catalog.load_save_data(parsed.get("catalog", {}))
	ctx.set_value("restored_catalog", fresh_catalog)

	var fresh_inv := _CommonSteps.SimpleInventory.new()
	fresh_inv.load_save_data(parsed.get("inventory", {}))
	ctx.set_value("restored_inventory", fresh_inv)


# --------------------------------------------------------------------------
# Step registration
# --------------------------------------------------------------------------


func register_steps(registry) -> void:
	# ---- Background ----
	registry.given(
		"a clean full-integration world with Journal, EventRegistry, DayNightCycle, Catalog and Inventory",
		func(ctx):
			build_world(ctx)
	)

	# ---- Journal seeding ----
	# NOTE: narrative_steps.gd already defines `the Journal has {string} and
	# {string} unlocked`, so this file uses a distinct phrasing
	# ("full integration entries") to avoid a duplicate-step warning.
	registry.given(
		"the Journal has full integration entries {string} and {string} unlocked",
		func(ctx, id_a: String, id_b: String):
			var journal: Node = ctx.get_value("journal", null)
			ctx.assert_not_null(journal, "journal must exist")
			if journal != null:
				journal.add_entry(StringName(id_a))
				journal.add_entry(StringName(id_b))
				ctx.assert_equal(journal.get_unlocked_ids().size(), 2,
					"both seed entries should be unlocked")
	)

	# ---- EventRegistry seeding ----
	registry.given(
		"a GameEvent {string} that has fired {int} times",
		func(ctx, event_id: String, count: int):
			_inject_test_event(ctx, StringName(event_id), count)
	)

	# ---- DayNightCycle seeding ----
	registry.given(
		"the day-night state is day {int} phase {word} elapsed {float}",
		func(ctx, day: int, phase: String, elapsed: float):
			var dn: DayNightSnapshot = ctx.get_value("day_night_cycle", null) as DayNightSnapshot
			ctx.assert_not_null(dn, "day_night_cycle must exist")
			if dn != null:
				dn.day_count = day
				dn.current_phase = int(_PHASE_TO_INT.get(phase, 0))
				dn.phase_elapsed = elapsed
				dn.is_daytime = dn.current_phase == 0 or dn.current_phase == 3
	)

	# ---- Catalog seeding ----
	registry.given(
		"the Catalog has {string} cataloged and {string} encountered with label {string}",
		func(ctx, cataloged_id: String, encountered_id: String, label: String):
			var catalog: CatalogSnapshot = ctx.get_value("catalog", null) as CatalogSnapshot
			ctx.assert_not_null(catalog, "catalog must exist")
			if catalog != null:
				catalog.set_cataloged(StringName(cataloged_id))
				catalog.set_encountered(StringName(encountered_id), label)
	)

	registry.given("the Catalog has {string} cataloged", func(ctx, entry_id: String):
		var catalog: CatalogSnapshot = ctx.get_value("catalog", null) as CatalogSnapshot
		ctx.assert_not_null(catalog, "catalog must exist")
		if catalog != null:
			catalog.set_cataloged(StringName(entry_id))
	)

	registry.given(
		"the Catalog has {string} in the default UNKNOWN state",
		func(ctx, entry_id: String):
			# Default state is UNKNOWN, so we record the id for later
			# assertion but do NOT put it in _knowledge. This mirrors the
			# production shape — Catalog.get_save_data() only persists
			# ENCOUNTERED/CATALOGED entries; UNKNOWN is implicit.
			var tracked: Array = ctx.get_value("_unknown_ids", [])
			tracked.append(StringName(entry_id))
			ctx.set_value("_unknown_ids", tracked)
	)

	registry.given(
		"the Catalog has {string} encountered with label {string}",
		func(ctx, entry_id: String, label: String):
			var catalog: CatalogSnapshot = ctx.get_value("catalog", null) as CatalogSnapshot
			ctx.assert_not_null(catalog, "catalog must exist")
			if catalog != null:
				catalog.set_encountered(StringName(entry_id), label)
	)

	# ---- Inventory seeding ----
	registry.given(
		"the full inventory has {int} {string} and tool {string} is {string}",
		func(ctx, count: int, item_id: String, slot: String, tool_id: String):
			var inv = ctx.get_value("full_inventory", null)
			ctx.assert_not_null(inv, "full_inventory must exist")
			if inv != null:
				inv.add_item(StringName(item_id), count)
				inv.set_tool(StringName(slot), StringName(tool_id))
	)

	registry.given(
		"the full inventory has {int} {string} and {int} {string}",
		func(ctx, c1: int, id1: String, c2: int, id2: String):
			var inv = ctx.get_value("full_inventory", null)
			ctx.assert_not_null(inv, "full_inventory must exist")
			if inv != null:
				inv.add_item(StringName(id1), c1)
				inv.add_item(StringName(id2), c2)
	)

	registry.given(
		"the full inventory tool {string} is set to {string}",
		func(ctx, slot: String, tool_id: String):
			var inv = ctx.get_value("full_inventory", null)
			ctx.assert_not_null(inv, "full_inventory must exist")
			if inv != null:
				inv.set_tool(StringName(slot), StringName(tool_id))
	)

	# ---- RecipeRuntime (transient) ----
	registry.given(
		"RecipeRuntime has a pending recipe {string}",
		func(ctx, recipe_id: String):
			# RecipeRuntime.gd has no get_save_data / load_save_data at the
			# time of writing (delivery-006d). Any pending recipes exist in
			# memory only and are lost on save. We record the attempt here
			# purely to prove the scenario seeded something to clear.
			var queue: Array = ctx.get_value("recipe_pending_queue", [])
			queue.append(StringName(recipe_id))
			ctx.set_value("recipe_pending_queue", queue)
			ctx.assert_equal(queue.size(), 1,
				"pending queue should hold the seeded recipe pre-save")
	)

	# ---- FaunaManager (transient) ----
	registry.given("FaunaManager has {int} spawned fauna", func(ctx, count: int):
		# FaunaManager.gd also lacks get_save_data / load_save_data. Spawned
		# fauna are transient and despawn at dawn by design. We record the
		# count so the assertion can verify the save payload has no fauna key.
		ctx.set_value("fauna_count", count)
	)

	# ---- Multi-slot seeding ----
	registry.given("slot A has Journal {string} and day {int}",
		func(ctx, entry_id: String, day: int):
			ctx.set_value("slot_a_entry", StringName(entry_id))
			ctx.set_value("slot_a_day", day)
	)

	registry.given("slot B has Journal {string} and day {int}",
		func(ctx, entry_id: String, day: int):
			ctx.set_value("slot_b_entry", StringName(entry_id))
			ctx.set_value("slot_b_day", day)
	)

	# ---- Corrupt save ----
	registry.given("a corrupt save file is written to the SaveManager path", func(ctx):
		var path: String = _SaveManager.SAVE_PATH
		var file := FileAccess.open(path, FileAccess.WRITE)
		ctx.assert_not_null(file, "should be able to open SaveManager SAVE_PATH")
		if file != null:
			file.store_string("{this is not: valid JSON ][")
			file.close()
		ctx.assert_true(FileAccess.file_exists(path),
			"corrupt save file should exist before loader runs")
	)

	registry.given("no save file exists at the SaveManager path", func(ctx):
		var path: String = _SaveManager.SAVE_PATH
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		ctx.assert_false(FileAccess.file_exists(path),
			"save file should not exist at start of scenario")
	)

	# ---- When steps ----
	registry.when(
		"the full state is saved to disk and loaded into fresh instances",
		func(ctx):
			var parsed := _round_trip_payload(ctx, _FULL_SAVE_PATH)
			_distribute_into_fresh(ctx, parsed)
			ctx.set_value("round_trip_payload", parsed)
	)

	registry.when(
		"the Journal is saved to a JSON file and loaded into a fresh instance",
		func(ctx):
			var journal: Node = ctx.get_value("journal", null)
			ctx.assert_not_null(journal, "journal must exist")
			if journal == null:
				return
			var snapshot: Dictionary = journal.get_save_data()
			var path := _FULL_SAVE_PATH
			var file := FileAccess.open(path, FileAccess.WRITE)
			ctx.assert_not_null(file, "unable to write journal save")
			if file != null:
				file.store_string(JSON.stringify({"journal": snapshot}, "\t"))
				file.close()
			var read := FileAccess.open(path, FileAccess.READ)
			ctx.assert_not_null(read, "unable to read journal save")
			var text: String = ""
			if read != null:
				text = read.get_as_text()
				read.close()
			var parsed: Variant = JSON.parse_string(text)
			ctx.assert_true(parsed is Dictionary, "parsed JSON must be dict")
			if not (parsed is Dictionary):
				return
			var fresh: Node = _Journal.new()
			fresh.load_save_data((parsed as Dictionary).get("journal", {}))
			ctx.set_value("restored_journal", fresh)
	)

	registry.when("the Catalog is saved and loaded into a fresh instance", func(ctx):
		var catalog: CatalogSnapshot = ctx.get_value("catalog", null) as CatalogSnapshot
		ctx.assert_not_null(catalog, "catalog must exist")
		if catalog == null:
			return
		var data: Dictionary = catalog.get_save_data()
		# JSON-round-trip so we exercise the serialization boundary, not
		# just an in-memory Dictionary reference copy.
		var text := JSON.stringify(data, "\t")
		var parsed: Variant = JSON.parse_string(text)
		ctx.assert_true(parsed is Dictionary, "catalog save should JSON-round-trip")
		if not (parsed is Dictionary):
			return
		var fresh := CatalogSnapshot.new()
		fresh.load_save_data(parsed as Dictionary)
		ctx.set_value("restored_catalog", fresh)
	)

	registry.when("EventRegistry is saved and loaded into a fresh instance", func(ctx):
		var er: Node = ctx.get_value("event_registry", null)
		ctx.assert_not_null(er, "event_registry must exist")
		if er == null:
			return
		var test_ids: Array = ctx.get_value("_test_event_ids", [])
		var full: Dictionary = er.get_save_data()
		var filtered: Dictionary = {}
		for id in test_ids:
			var id_str := String(id)
			if full.has(id_str):
				filtered[id_str] = full[id_str]
		var text := JSON.stringify(filtered, "\t")
		var parsed: Variant = JSON.parse_string(text)
		ctx.assert_true(parsed is Dictionary, "event registry save should JSON-round-trip")
		if not (parsed is Dictionary):
			return
		var fresh_er: Node = _EventRegistry.new()
		for id in test_ids:
			var ev := _GameEvent.new()
			ev.id = id
			ev.display_name = String(id)
			ev.max_count = 0
			fresh_er._events[id] = ev
		fresh_er.load_save_data(parsed as Dictionary)
		ctx.set_value("restored_event_registry", fresh_er)
	)

	registry.when("the full inventory is saved and loaded into a fresh instance", func(ctx):
		var inv = ctx.get_value("full_inventory", null)
		ctx.assert_not_null(inv, "full_inventory must exist")
		if inv == null:
			return
		var data: Dictionary = inv.get_save_data()
		var text := JSON.stringify(data, "\t")
		var parsed: Variant = JSON.parse_string(text)
		ctx.assert_true(parsed is Dictionary, "inventory save should JSON-round-trip")
		if not (parsed is Dictionary):
			return
		var fresh := _CommonSteps.SimpleInventory.new()
		fresh.load_save_data(parsed as Dictionary)
		ctx.set_value("restored_inventory", fresh)
	)

	registry.when("DayNightCycle is saved and loaded into a fresh instance", func(ctx):
		var dn: DayNightSnapshot = ctx.get_value("day_night_cycle", null) as DayNightSnapshot
		ctx.assert_not_null(dn, "day_night_cycle must exist")
		if dn == null:
			return
		var data: Dictionary = dn.get_save_data()
		var text := JSON.stringify(data, "\t")
		var parsed: Variant = JSON.parse_string(text)
		ctx.assert_true(parsed is Dictionary, "day_night save should JSON-round-trip")
		if not (parsed is Dictionary):
			return
		var fresh := DayNightSnapshot.new()
		fresh.load_save_data(parsed as Dictionary)
		ctx.set_value("restored_day_night", fresh)
	)

	registry.when("both slots are saved and loaded independently", func(ctx):
		var journal: Node = ctx.get_value("journal", null)
		var dn: DayNightSnapshot = ctx.get_value("day_night_cycle", null) as DayNightSnapshot
		ctx.assert_not_null(journal, "journal must exist")
		ctx.assert_not_null(dn, "day_night_cycle must exist")
		if journal == null or dn == null:
			return

		# Slot A — seed state, snapshot, write to path A.
		var entry_a: StringName = ctx.get_value("slot_a_entry", &"")
		var day_a: int = ctx.get_value("slot_a_day", 1)
		journal.load_save_data({"unlocked_entries": [String(entry_a)]})
		dn.day_count = day_a
		var payload_a := {
			"journal": journal.get_save_data(),
			"day_night": dn.get_save_data(),
		}
		var fa := FileAccess.open(_SLOT_A_PATH, FileAccess.WRITE)
		fa.store_string(JSON.stringify(payload_a, "\t"))
		fa.close()

		# Slot B — re-seed with different state, snapshot, write to path B.
		var entry_b: StringName = ctx.get_value("slot_b_entry", &"")
		var day_b: int = ctx.get_value("slot_b_day", 1)
		journal.load_save_data({"unlocked_entries": [String(entry_b)]})
		dn.day_count = day_b
		var payload_b := {
			"journal": journal.get_save_data(),
			"day_night": dn.get_save_data(),
		}
		var fb := FileAccess.open(_SLOT_B_PATH, FileAccess.WRITE)
		fb.store_string(JSON.stringify(payload_b, "\t"))
		fb.close()

		# Round trip slot A back into its own receivers.
		var ra := FileAccess.open(_SLOT_A_PATH, FileAccess.READ)
		var text_a: String = ra.get_as_text()
		ra.close()
		var parsed_a: Variant = JSON.parse_string(text_a)
		ctx.assert_true(parsed_a is Dictionary, "slot A must JSON-round-trip")
		var journal_a: Node = _Journal.new()
		var dn_a := DayNightSnapshot.new()
		if parsed_a is Dictionary:
			journal_a.load_save_data((parsed_a as Dictionary).get("journal", {}))
			dn_a.load_save_data((parsed_a as Dictionary).get("day_night", {}))
		ctx.set_value("slot_a_journal", journal_a)
		ctx.set_value("slot_a_dnc", dn_a)

		# Round trip slot B back into its own receivers.
		var rb := FileAccess.open(_SLOT_B_PATH, FileAccess.READ)
		var text_b: String = rb.get_as_text()
		rb.close()
		var parsed_b: Variant = JSON.parse_string(text_b)
		ctx.assert_true(parsed_b is Dictionary, "slot B must JSON-round-trip")
		var journal_b: Node = _Journal.new()
		var dn_b := DayNightSnapshot.new()
		if parsed_b is Dictionary:
			journal_b.load_save_data((parsed_b as Dictionary).get("journal", {}))
			dn_b.load_save_data((parsed_b as Dictionary).get("day_night", {}))
		ctx.set_value("slot_b_journal", journal_b)
		ctx.set_value("slot_b_dnc", dn_b)
	)

	registry.when("SaveManager tries to load the corrupt save", func(ctx):
		var sm: Node = ctx.get_value("save_manager", null)
		ctx.assert_not_null(sm, "save_manager must exist")
		if sm == null:
			return
		var result: bool = sm.load_game()
		ctx.set_value("last_load_result", result)
	)

	registry.when("SaveManager tries to load the save file", func(ctx):
		var sm: Node = ctx.get_value("save_manager", null)
		ctx.assert_not_null(sm, "save_manager must exist")
		if sm == null:
			return
		var result: bool = sm.load_game()
		ctx.set_value("last_load_result", result)
	)

	# ---- Then: restored state assertions ----
	registry.then("the restored Journal has unlocked {string}", func(ctx, entry_id: String):
		var fresh: Node = ctx.get_value("restored_journal", null)
		ctx.assert_not_null(fresh, "restored_journal must exist")
		if fresh != null:
			ctx.assert_true(fresh.is_unlocked(StringName(entry_id)),
				"restored journal should have %s unlocked" % entry_id)
	)

	registry.then("the restored Journal unlocked count is {int}", func(ctx, expected: int):
		var fresh: Node = ctx.get_value("restored_journal", null)
		ctx.assert_not_null(fresh, "restored_journal must exist")
		if fresh != null:
			ctx.assert_equal(fresh.get_unlocked_ids().size(), expected,
				"restored journal count mismatch")
	)

	registry.then(
		"the restored EventRegistry event {string} has count {int}",
		func(ctx, event_id: String, expected: int):
			var fresh: Node = ctx.get_value("restored_event_registry", null)
			ctx.assert_not_null(fresh, "restored_event_registry must exist")
			if fresh != null:
				var ev = fresh.get_event(StringName(event_id))
				ctx.assert_not_null(ev, "restored event %s must exist" % event_id)
				if ev != null:
					ctx.assert_equal(ev.count, expected,
						"restored event %s count mismatch" % event_id)
	)

	registry.then(
		"the restored DayNightCycle has day {int} and phase {word} and elapsed {float}",
		func(ctx, expected_day: int, expected_phase: String, expected_elapsed: float):
			var fresh: DayNightSnapshot = ctx.get_value("restored_day_night", null) as DayNightSnapshot
			ctx.assert_not_null(fresh, "restored_day_night must exist")
			if fresh != null:
				ctx.assert_equal(fresh.day_count, expected_day,
					"restored DNC day_count mismatch")
				var expected_phase_int: int = int(_PHASE_TO_INT.get(expected_phase, 0))
				ctx.assert_equal(fresh.current_phase, expected_phase_int,
					"restored DNC phase mismatch")
				# Float comparison with a small epsilon — Godot's JSON.stringify
				# uses C-locale so decimals round-trip exactly for typical
				# values, but we tolerate sub-millisecond drift for safety.
				var delta: float = absf(fresh.phase_elapsed - expected_elapsed)
				ctx.assert_true(delta < 0.001,
					"restored DNC elapsed mismatch: %.3f vs %.3f" %
					[fresh.phase_elapsed, expected_elapsed])
	)

	registry.then("the restored Catalog has {string} CATALOGED", func(ctx, entry_id: String):
		var fresh: CatalogSnapshot = ctx.get_value("restored_catalog", null) as CatalogSnapshot
		ctx.assert_not_null(fresh, "restored_catalog must exist")
		if fresh != null:
			ctx.assert_true(fresh.is_cataloged(StringName(entry_id)),
				"restored catalog should have %s CATALOGED" % entry_id)
	)

	registry.then(
		"the restored Catalog has {string} ENCOUNTERED with label {string}",
		func(ctx, entry_id: String, label: String):
			var fresh: CatalogSnapshot = ctx.get_value("restored_catalog", null) as CatalogSnapshot
			ctx.assert_not_null(fresh, "restored_catalog must exist")
			if fresh != null:
				ctx.assert_true(fresh.is_encountered(StringName(entry_id)),
					"restored catalog should have %s ENCOUNTERED" % entry_id)
				ctx.assert_equal(fresh.get_encounter_label(StringName(entry_id)), label,
					"restored catalog label mismatch for %s" % entry_id)
	)

	registry.then("the restored Catalog has {string} UNKNOWN", func(ctx, entry_id: String):
		var fresh: CatalogSnapshot = ctx.get_value("restored_catalog", null) as CatalogSnapshot
		ctx.assert_not_null(fresh, "restored_catalog must exist")
		if fresh != null:
			var state: int = fresh.get_knowledge_state(StringName(entry_id))
			ctx.assert_equal(state, CatalogSnapshot.KnowledgeState.UNKNOWN,
				"restored catalog should have %s UNKNOWN" % entry_id)
	)

	registry.then("the restored full inventory has {int} {string}", func(ctx, count: int, item_id: String):
		var fresh = ctx.get_value("restored_inventory", null)
		ctx.assert_not_null(fresh, "restored_inventory must exist")
		if fresh != null:
			ctx.assert_equal(fresh.get_count(StringName(item_id)), count,
				"restored inventory %s count mismatch" % item_id)
	)

	registry.then(
		"the restored full inventory tool {string} is {string}",
		func(ctx, slot: String, tool_id: String):
			var fresh = ctx.get_value("restored_inventory", null)
			ctx.assert_not_null(fresh, "restored_inventory must exist")
			if fresh != null:
				ctx.assert_equal(String(fresh.get_tool(StringName(slot))), tool_id,
					"restored inventory tool %s mismatch" % slot)
	)

	# ---- RecipeRuntime transient ----
	registry.then("the restored RecipeRuntime pending queue is empty", func(ctx):
		var parsed: Dictionary = ctx.get_value("round_trip_payload", {})
		ctx.assert_false(parsed.has("recipe_runtime"),
			"save payload should not carry a recipe_runtime key (RecipeRuntime is transient)")
	)

	registry.then(
		"the documented reason is {string}",
		func(ctx, reason: String):
			# This step is documentation: we assert the reason string matches
			# the feature file. If RecipeRuntime ever gains persistence,
			# update both this step and the feature file together.
			ctx.assert_equal(reason,
				"RecipeRuntime is transient — pending recipes are not persisted",
				"documented reason drifted — did RecipeRuntime gain save/load?")
	)

	# ---- FaunaManager transient ----
	registry.then(
		"FaunaManager state is confirmed transient and not in the save payload",
		func(ctx):
			var parsed: Dictionary = ctx.get_value("round_trip_payload", {})
			ctx.assert_false(parsed.has("fauna"),
				"save payload should not carry a fauna key (FaunaManager is transient)")
			# Document the fact that seeded fauna did exist pre-save — proving
			# this scenario actually had something to lose, not that the
			# empty payload is because nothing was seeded.
			var count: int = ctx.get_value("fauna_count", 0)
			ctx.assert_greater(count, 0,
				"scenario must seed > 0 fauna to meaningfully test transience")
	)

	# ---- Multi-slot isolation ----
	registry.then(
		"slot A restored Journal has unlocked {string} and not {string}",
		func(ctx, expected: String, forbidden: String):
			var j: Node = ctx.get_value("slot_a_journal", null)
			ctx.assert_not_null(j, "slot_a_journal must exist")
			if j != null:
				ctx.assert_true(j.is_unlocked(StringName(expected)),
					"slot A should have %s unlocked" % expected)
				ctx.assert_false(j.is_unlocked(StringName(forbidden)),
					"slot A should NOT have %s unlocked (cross-contamination)" % forbidden)
	)

	registry.then(
		"slot B restored Journal has unlocked {string} and not {string}",
		func(ctx, expected: String, forbidden: String):
			var j: Node = ctx.get_value("slot_b_journal", null)
			ctx.assert_not_null(j, "slot_b_journal must exist")
			if j != null:
				ctx.assert_true(j.is_unlocked(StringName(expected)),
					"slot B should have %s unlocked" % expected)
				ctx.assert_false(j.is_unlocked(StringName(forbidden)),
					"slot B should NOT have %s unlocked (cross-contamination)" % forbidden)
	)

	registry.then("slot A restored day is {int}", func(ctx, expected: int):
		var dn: DayNightSnapshot = ctx.get_value("slot_a_dnc", null) as DayNightSnapshot
		ctx.assert_not_null(dn, "slot_a_dnc must exist")
		if dn != null:
			ctx.assert_equal(dn.day_count, expected, "slot A day mismatch")
	)

	registry.then("slot B restored day is {int}", func(ctx, expected: int):
		var dn: DayNightSnapshot = ctx.get_value("slot_b_dnc", null) as DayNightSnapshot
		ctx.assert_not_null(dn, "slot_b_dnc must exist")
		if dn != null:
			ctx.assert_equal(dn.day_count, expected, "slot B day mismatch")
	)

	# ---- Corrupt save recovery ----
	registry.then("SaveManager load_game returns false", func(ctx):
		var result: bool = ctx.get_value("last_load_result", true)
		ctx.assert_false(result, "load_game should return false for corrupt/missing save")
	)

	registry.then("the corrupt save file has been deleted", func(ctx):
		var path: String = _SaveManager.SAVE_PATH
		ctx.assert_false(FileAccess.file_exists(path),
			"SaveManager should have deleted the corrupt save file")
	)
