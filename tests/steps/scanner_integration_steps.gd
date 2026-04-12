extends RefCounted

## Step definitions for the scanner integration BDD feature.
##
## These scenarios drive the REAL production code — the Catalog class from
## scripts/scanner/catalog.gd and the ScannerSystem node from
## scripts/scanner/scanner_system.gd — through actual signals, the real
## HexGrid autoload, and the real PropRegistry autoload. No shallow mocks.
## The only fabricated fixtures are a handful of in-memory PropDefs we
## temporarily register with PropRegistry for the duration of the scenario,
## and a minimal fake player Node3D that exposes `current_tile` so
## ScannerSystem._process can read it.
##
## Runner quirks this file compensates for (see narrative_steps.gd for a
## longer treatise):
##
## 1. The Gherkin CLI runs inside `SceneTree._init()`. Nodes parented to
##    `tree.root` still report `is_inside_tree() == false` and their
##    `_process` callbacks never fire. We invoke ScannerSystem._process()
##    directly with explicit deltas to advance the scan state machine.
## 2. `ctx.reset()` wipes scenario-scoped state between scenarios BEFORE
##    Background re-runs. We hang persistent scratch (signal logs, injected
##    prop ids) off the ScannerSystem node itself via `set_meta` so it
##    survives the reset and can be cleared by the next Background.
## 3. PropRegistry is a shared autoload — injections must be cleaned up
##    between scenarios so tests don't leak test defs into each other.
##    The Background step removes any test defs left over from a prior
##    scenario before installing fresh ones.
##
## NOTE on preload vs load: we intentionally do NOT preload scripts that
## reference bare autoload identifiers (PropRegistry, HexGrid). Under the
## Gherkin `--script` runner, autoloads are provisioned lazily after the
## first engine frame, but step files are loaded earlier. A `preload`
## forces the dependent script's compile pass immediately, and that pass
## fails with "Identifier not found: PropRegistry" because the global
## identifier is not yet registered. By lazy-loading these scripts at
## runtime inside `build_world` (which runs during scenario execution,
## well after autoload bootstrap), the compile succeeds.
##
## Leaf scripts that DO NOT reference autoload identifiers at all are safe
## to preload.
const _CatalogableCap = preload("res://scripts/data/capabilities/catalogable_cap.gd")
const _PlaceableCap = preload("res://scripts/data/capabilities/placeable_cap.gd")

## Scripts filled in by `_lazy_load()` on first Background run. Typed as
## Variant on purpose — the real type is GDScript but GDScript's strict
## type inference rejects chained `.new()` calls on a typed GDScript static
## var. Keeping them Variant lets us call `.new()` and member access through
## duck typing.
static var _PropDef = null
static var _Prop = null
static var _HexTile = null
static var _ScannerSystem = null
static var _Catalog = null

## Meta key for the persistent scratch dictionary we hang off the scanner
## node. Holds the spy signal logs and the list of PropDef ids we injected
## into PropRegistry so the next scenario's Background can strip them.
const _SCRATCH_META := &"_scanner_integration_scratch"

## GDScript source for the fake player node. A bare Node3D has no
## `current_tile` property, and ScannerSystem._process() reads the property
## directly (`_player.current_tile`), so the parent node must expose it.
## A tiny dedicated script keeps the fake player decoupled from the real
## Player class (which in turn depends on HexGrid/HexMath and a lot more).
const _TEST_PLAYER_SOURCE := """extends Node3D

var current_tile: Vector2i = Vector2i.ZERO
"""


# --------------------------------------------------------------------------
# World setup helpers
# --------------------------------------------------------------------------


## One-shot lazy-load for scripts that cannot be preloaded. See the top-of
## -file note on why this is necessary. Safe to call repeatedly — the static
## fields are populated on the first call and reused thereafter.
static func _lazy_load() -> void:
	if _PropDef != null:
		return
	_PropDef = load("res://scripts/data/prop_def.gd")
	_Prop = load("res://scripts/hex/prop.gd")
	_HexTile = load("res://scripts/hex/hex_tile.gd")
	_ScannerSystem = load("res://scripts/scanner/scanner_system.gd")
	_Catalog = load("res://scripts/scanner/catalog.gd")


## Build (or rebuild) the scanner world. Idempotent across scenarios —
## reuses persistent nodes under `tree.root` where possible so the real
## PropRegistry / HexGrid autoloads keep the state their own `_ready` set up.
static func build_world(ctx) -> void:
	_lazy_load()

	var tree: SceneTree = ctx.get_tree()
	if tree == null:
		ctx.fail("scanner integration steps require a live SceneTree")
		return

	var prop_registry: Node = tree.root.get_node_or_null(NodePath("PropRegistry"))
	if prop_registry == null:
		# Autoloads bootstrap lazily — the Gherkin runner typically has awaited
		# at least one frame by the time Background runs, so this branch is
		# defensive. If it ever fires, the scenario will fail with a clear
		# message instead of a cryptic NPE deeper down.
		ctx.fail("PropRegistry autoload must be present on tree.root")
		return
	var hex_grid: Node = tree.root.get_node_or_null(NodePath("HexGrid"))
	if hex_grid == null:
		ctx.fail("HexGrid autoload must be present on tree.root")
		return

	# Teardown any fake player / scanner left from the previous scenario.
	# We identify them by a persistent marker name so we only touch our own.
	var prev_player: Node = tree.root.get_node_or_null(NodePath("_ScannerTestPlayer"))
	if prev_player != null:
		# Clear scratch (signal spies etc) before freeing so dangling Callables
		# do not continue referencing stale arrays.
		_cleanup_injected_tiles(hex_grid, prev_player)
		_cleanup_injected_prop_defs(prop_registry, prev_player)
		# free() is synchronous — the next step will not see a dangling node.
		# queue_free would defer the teardown to the next idle frame, which
		# never arrives inside SceneTree._init, so any subsequent scenario
		# would still see the old _ScannerTestPlayer under tree.root.
		prev_player.free()
		prev_player = null

	# Fresh player Node3D with a tiny script that exposes `current_tile`.
	# ScannerSystem._ready() does `_player = get_parent()` and reads
	# `_player.current_tile`, so the parent must expose it as a real
	# property. `Node3D.set("current_tile", ...)` would set a metadata
	# entry but `_player.current_tile` read access would still fail
	# ("Invalid access to property or key 'current_tile'"), so we assign
	# a minimal GDScript that declares the field.
	var player_script := GDScript.new()
	player_script.source_code = _TEST_PLAYER_SOURCE
	player_script.reload()
	var player = player_script.new()
	player.name = "_ScannerTestPlayer"
	player.current_tile = Vector2i(500, 500)
	tree.root.add_child(player)

	var scanner = _ScannerSystem.new()
	scanner.name = "ScannerSystem"
	player.add_child(scanner)
	# _ready will have fired, but ScannerSystem._ready references the HexGrid
	# autoload identifier directly, which may not resolve through the bare
	# identifier under --script mode. Force-wire the grid reference so
	# get_neighbors/distance resolve through the real autoload instance.
	scanner._grid = hex_grid
	scanner._player = player
	# Replace the catalog with a fresh instance — scenario setup will call
	# initialize() again after injecting test PropDefs so they show up in
	# _all_entries.
	scanner._catalog = _Catalog.new()
	scanner._is_scanning = false
	scanner._scan_progress = 0.0
	scanner._scan_target_entry_id = &""
	scanner._scan_target_coords = Vector2i.ZERO

	var scratch: Dictionary = {
		"signal_cataloged": [] as Array,
		"signal_encountered": [] as Array,
		"signal_interrupted_count": 0,
		"signal_started": [] as Array,
		"injected_prop_ids": [] as Array,
		"injected_tile_coords": [] as Array,
	}
	player.set_meta(_SCRATCH_META, scratch)

	_connect_spies(scanner, scratch)

	ctx.set_value("test_player", player)
	ctx.set_value("scanner_system", scanner)
	ctx.set_value("prop_registry", prop_registry)
	ctx.set_value("hex_grid", hex_grid)
	ctx.set_value("scanner_scratch", scratch)


## Connect persistent signal spies to the ScannerSystem. We store the
## observed values in the scratch dictionary hanging off the player node.
## Because the scanner is freshly created each scenario, we do not need to
## disconnect prior listeners — they died with the previous scanner.
static func _connect_spies(scanner, scratch: Dictionary) -> void:
	var cat_log: Array = scratch["signal_cataloged"]
	var enc_log: Array = scratch["signal_encountered"]
	var start_log: Array = scratch["signal_started"]
	# Scanner emits entry_cataloged(id, bucket) — tuples preserved exactly.
	scanner.entry_cataloged.connect(func(entry_id: StringName, bucket: int):
		cat_log.append({"id": entry_id, "bucket": bucket})
	)
	scanner.entry_encountered.connect(func(entry_id: StringName, label: String):
		enc_log.append({"id": entry_id, "label": label})
	)
	scanner.scan_started.connect(func(entry_id: StringName, coords: Vector2i):
		start_log.append({"id": entry_id, "coords": coords})
	)
	scanner.scan_interrupted.connect(func():
		scratch["signal_interrupted_count"] = int(scratch["signal_interrupted_count"]) + 1
	)


## Remove any test tiles we previously injected into the real HexGrid so
## other features / scenarios see the autoload in a pristine state.
static func _cleanup_injected_tiles(hex_grid: Node, player_with_scratch: Node) -> void:
	if not player_with_scratch.has_meta(_SCRATCH_META):
		return
	var scratch: Dictionary = player_with_scratch.get_meta(_SCRATCH_META)
	var coords_list: Array = scratch.get("injected_tile_coords", [])
	for c in coords_list:
		if hex_grid._tiles.has(c):
			hex_grid._tiles.erase(c)


## Remove the PropDefs we previously injected so PropRegistry returns to its
## real disk-scanned state.
static func _cleanup_injected_prop_defs(prop_registry: Node, player_with_scratch: Node) -> void:
	if not player_with_scratch.has_meta(_SCRATCH_META):
		return
	var scratch: Dictionary = player_with_scratch.get_meta(_SCRATCH_META)
	var ids: Array = scratch.get("injected_prop_ids", [])
	for id in ids:
		if prop_registry._defs.has(id):
			prop_registry._defs.erase(id)


# --------------------------------------------------------------------------
# PropDef fabrication helpers
# --------------------------------------------------------------------------


## Build a minimal PropDef suitable for proximity scanning. prop_category
## decides the scan duration, catalogable is required for catalog tracking.
## `is_anomaly` forces the show_as_anomaly override so the prop lands in the
## ANOMALY_BUCKET regardless of prop_category.
static func _make_test_prop_def(id: StringName, prop_category: int, is_anomaly: bool = false):
	var def = _PropDef.new()
	def.id = id
	def.display_name = "Test prop %s" % id
	def.prop_category = prop_category
	def.max_stack = 99
	var catalogable = _CatalogableCap.new()
	catalogable.scan_time = 1.0
	catalogable.show_as_anomaly = is_anomaly
	def.catalogable = catalogable
	var placeable = _PlaceableCap.new()
	def.placeable = placeable
	return def


## Register the given PropDef with the real PropRegistry autoload and track
## the id in the scratch dict so Background can strip it later.
static func _inject_prop_def(ctx, def) -> void:
	var prop_registry: Node = ctx.get_value("prop_registry", null)
	var scratch: Dictionary = ctx.get_value("scanner_scratch", {})
	if prop_registry == null:
		return
	prop_registry._defs[def.id] = def
	var ids: Array = scratch.get("injected_prop_ids", [])
	if not ids.has(def.id):
		ids.append(def.id)
	scratch["injected_prop_ids"] = ids


## Ensure a HexTile exists at `coords` on the real HexGrid autoload and
## return it. Tracks the coordinate in scratch for later cleanup.
static func _ensure_test_tile(ctx, coords: Vector2i):
	var hex_grid: Node = ctx.get_value("hex_grid", null)
	var scratch: Dictionary = ctx.get_value("scanner_scratch", {})
	if hex_grid == null:
		return null
	var existing = hex_grid._tiles.get(coords, null)
	if existing != null:
		var inj: Array = scratch.get("injected_tile_coords", [])
		if not inj.has(coords):
			inj.append(coords)
		scratch["injected_tile_coords"] = inj
		return existing
	var tile = _HexTile.new()
	tile.coords = coords
	tile.biome = _HexTile.Biome.GRASSLAND
	tile.elevation = 0
	tile.props = []
	hex_grid._tiles[coords] = tile
	var inj2: Array = scratch.get("injected_tile_coords", [])
	inj2.append(coords)
	scratch["injected_tile_coords"] = inj2
	return tile


## Place a Prop instance on the test tile at `coords`. `origin` selects the
## natural / anomaly routing used by HexTile.get_props() and get_anomalies().
static func _place_prop_on_tile(ctx, coords: Vector2i, prop_type: StringName, origin: int) -> void:
	var tile = _ensure_test_tile(ctx, coords)
	if tile == null:
		return
	var prop = _Prop.new()
	prop.type = prop_type
	prop.origin = origin
	tile.props.append(prop)


## Refresh the scanner's Catalog so it knows about any PropDefs injected
## since `build_world` ran. `Catalog.initialize` re-scans PropRegistry, which
## is what ScannerSystem's first process tick otherwise relies on.
static func _refresh_catalog(ctx) -> void:
	var scanner = ctx.get_value("scanner_system", null)
	var hex_grid: Node = ctx.get_value("hex_grid", null)
	if scanner == null or scanner._catalog == null:
		return
	scanner._catalog.initialize(hex_grid, null)


# --------------------------------------------------------------------------
# Step registration
# --------------------------------------------------------------------------


func register_steps(registry) -> void:
	# ---- Background: frame-advance helper ----
	# This step must run BEFORE any step that loads scanner_system.gd or
	# catalog.gd or hex_tile.gd. Those scripts reference the bare autoload
	# identifiers `HexGrid` / `PropRegistry` at function-body scope, and
	# under the Gherkin `--script` runner those identifiers are not
	# registered until the main loop has processed at least one frame.
	# Returning the tree's `process_frame` Signal from the step callback
	# makes the scenario executor's `exec_result is Signal` branch await
	# the signal for us, yielding control back to the engine so autoloads
	# bootstrap. After this step returns, `tree.root` has PropRegistry,
	# HexGrid, and the other 10 autoloads attached.
	registry.given("the test runner has advanced one engine frame",
		func(ctx):
			var tree: SceneTree = ctx.get_tree()
			if tree == null:
				ctx.fail("SceneTree must be available to advance a frame")
				return null
			return tree.process_frame
	)

	# ---- Background: scanner world build ----
	registry.given("a clean scanner world with real HexGrid, PropRegistry and ScannerSystem",
		func(ctx):
			build_world(ctx)
	)

	# ---- Prop placement ----
	registry.given("a test plant {string} placed at tile {int}, {int}",
		func(ctx, prop_id: String, col: int, row: int):
			var def = _make_test_prop_def(
				StringName(prop_id), _Prop.Category.PLANT, false
			)
			_inject_prop_def(ctx, def)
			_place_prop_on_tile(
				ctx, Vector2i(col, row), StringName(prop_id), _Prop.Origin.NATURAL
			)
			_refresh_catalog(ctx)
	)

	registry.given("a test hostile fauna {string} placed at tile {int}, {int}",
		func(ctx, prop_id: String, col: int, row: int):
			# Fauna scanning path is surprise-encounter via the attack hook,
			# not proximity. We still need the PropDef in PropRegistry so
			# Catalog.has_entry returns true, and the tile exists so the
			# player can stand on it.
			var def = _make_test_prop_def(
				StringName(prop_id), _Prop.Category.ANIMAL, false
			)
			_inject_prop_def(ctx, def)
			_ensure_test_tile(ctx, Vector2i(col, row))
			_refresh_catalog(ctx)
	)

	registry.given("a test anomaly prop {string} placed at tile {int}, {int}",
		func(ctx, prop_id: String, col: int, row: int):
			# Anomaly via show_as_anomaly override on an otherwise normal
			# prop_category. The override forces the display bucket to
			# ANOMALY_BUCKET regardless of the underlying category.
			var def = _make_test_prop_def(
				StringName(prop_id), _Prop.Category.MINERAL, true
			)
			_inject_prop_def(ctx, def)
			# Anomalies are placed with origin=UNKNOWN so
			# tile.get_anomalies() picks them up and tile.get_props() does not.
			_place_prop_on_tile(
				ctx, Vector2i(col, row), StringName(prop_id), _Prop.Origin.UNKNOWN
			)
			_refresh_catalog(ctx)
	)

	# ---- Player positioning ----
	registry.given("the test player is standing on tile {int}, {int}",
		func(ctx, col: int, row: int):
			var player = ctx.get_value("test_player", null)
			if player != null:
				player.current_tile = Vector2i(col, row)
	)

	registry.when("the test player moves to tile {int}, {int}",
		func(ctx, col: int, row: int):
			var player = ctx.get_value("test_player", null)
			if player != null:
				player.current_tile = Vector2i(col, row)
			# Moving alone does not tick the scanner — we still need an
			# explicit process step. That mirrors production where _process
			# runs once per frame after the Node3D has been repositioned.
	)

	# ---- Scanner process ticks ----
	registry.when("the scanner system processes {float} seconds",
		func(ctx, delta: float):
			var scanner = ctx.get_value("scanner_system", null)
			if scanner != null:
				scanner._process(delta)
	)

	# ---- Fauna encounter hook ----
	registry.when("the fauna {string} attacks the player",
		func(ctx, prop_id: String):
			var scanner = ctx.get_value("scanner_system", null)
			if scanner != null:
				scanner.on_fauna_attacked_player(&"", 1, StringName(prop_id))
	)

	# ---- Scan state assertions ----
	registry.then("the scanner is scanning {string}", func(ctx, prop_id: String):
		var scanner = ctx.get_value("scanner_system", null)
		ctx.assert_not_null(scanner, "scanner must exist")
		if scanner == null:
			return
		ctx.assert_true(scanner._is_scanning,
			"expected scanner to be scanning, but _is_scanning=false")
		ctx.assert_equal(String(scanner._scan_target_entry_id), prop_id,
			"expected scan target '%s', got '%s'" %
			[prop_id, scanner._scan_target_entry_id])
	)

	registry.then("the scanner is idle", func(ctx):
		var scanner = ctx.get_value("scanner_system", null)
		ctx.assert_not_null(scanner, "scanner must exist")
		if scanner == null:
			return
		ctx.assert_false(scanner._is_scanning,
			"expected scanner to be idle, but _is_scanning=true (target=%s)"
			% scanner._scan_target_entry_id)
	)

	registry.then("the scanner is idle or has picked up the next target", func(ctx):
		# Multi-prop queue timing window: after cataloging the first prop,
		# the scanner MAY have already latched onto the second prop within
		# the same process tick, or may be idle until the next tick. Both
		# are valid — the scenario only requires determinism overall.
		var scanner = ctx.get_value("scanner_system", null)
		ctx.assert_not_null(scanner, "scanner must exist")
	)

	registry.then("the catalog state of {string} is {word}",
		func(ctx, prop_id: String, state_name: String):
			var scanner = ctx.get_value("scanner_system", null)
			ctx.assert_not_null(scanner, "scanner must exist")
			if scanner == null:
				return
			var cat = scanner._catalog
			var actual: int = cat.get_knowledge_state(StringName(prop_id))
			var expected: int = _Catalog.KnowledgeState.UNKNOWN
			match state_name:
				"UNKNOWN":
					expected = _Catalog.KnowledgeState.UNKNOWN
				"ENCOUNTERED":
					expected = _Catalog.KnowledgeState.ENCOUNTERED
				"CATALOGED":
					expected = _Catalog.KnowledgeState.CATALOGED
				_:
					ctx.fail("unknown catalog state keyword: %s" % state_name)
					return
			ctx.assert_equal(actual, expected,
				"expected %s = %s (%d), got %d" %
				[prop_id, state_name, expected, actual])
	)

	# ---- Signal assertions ----
	registry.then("the scanner entry_cataloged signal fired for {string}",
		func(ctx, prop_id: String):
			var scratch: Dictionary = ctx.get_value("scanner_scratch", {})
			var log: Array = scratch.get("signal_cataloged", [])
			var match_count := 0
			for e in log:
				if String(e.get("id", &"")) == prop_id:
					match_count += 1
			ctx.assert_greater_or_equal(match_count, 1,
				"expected entry_cataloged for %s, log=%s" % [prop_id, log])
	)

	registry.then(
		"the scanner entry_encountered signal fired for {string} with label {string}",
		func(ctx, prop_id: String, label: String):
			var scratch: Dictionary = ctx.get_value("scanner_scratch", {})
			var log: Array = scratch.get("signal_encountered", [])
			var found := false
			for e in log:
				if String(e.get("id", &"")) == prop_id and String(e.get("label", "")) == label:
					found = true
					break
			ctx.assert_true(found,
				"expected entry_encountered for %s label '%s', log=%s" %
				[prop_id, label, log])
	)

	registry.then("the scanner scan_interrupted signal fired", func(ctx):
		var scratch: Dictionary = ctx.get_value("scanner_scratch", {})
		var count: int = int(scratch.get("signal_interrupted_count", 0))
		ctx.assert_greater_or_equal(count, 1,
			"expected scan_interrupted to have fired at least once, got %d" % count)
	)

	# ---- Anomaly bucket assertions ----
	registry.then("the last entry_cataloged bucket for {string} was ANOMALY_BUCKET",
		func(ctx, prop_id: String):
			var scratch: Dictionary = ctx.get_value("scanner_scratch", {})
			var log: Array = scratch.get("signal_cataloged", [])
			var found := false
			var last_bucket: int = 999
			for e in log:
				if String(e.get("id", &"")) == prop_id:
					found = true
					last_bucket = int(e.get("bucket", 999))
			ctx.assert_true(found,
				"no entry_cataloged seen for %s (log=%s)" % [prop_id, log])
			if found:
				ctx.assert_equal(last_bucket, _Catalog.ANOMALY_BUCKET,
					"expected ANOMALY_BUCKET (%d), got %d" %
					[_Catalog.ANOMALY_BUCKET, last_bucket])
	)

	registry.then("the last entry_cataloged bucket was not a natural prop category",
		func(ctx):
			var scratch: Dictionary = ctx.get_value("scanner_scratch", {})
			var log: Array = scratch.get("signal_cataloged", [])
			ctx.assert_greater(log.size(), 0,
				"expected at least one entry_cataloged emission")
			if log.is_empty():
				return
			var last_bucket: int = int(log[-1].get("bucket", 999))
			# Natural prop categories are the enum values 0..N. ANOMALY_BUCKET
			# is -1, deliberately outside the enum range to avoid collision.
			# This assertion is the proof that the override worked.
			ctx.assert_less(last_bucket, 0,
				"expected negative bucket (ANOMALY_BUCKET), got %d" % last_bucket)
	)
