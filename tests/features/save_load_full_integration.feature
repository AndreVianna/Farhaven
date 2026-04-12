Feature: Save/Load full integration — every autoload restored
  A single save/load round trip that crosses every autoload with persistent
  state: Journal, EventRegistry, DayNightCycle, Catalog, Inventory, plus the
  SaveManager JSON file boundary. Each scenario exercises at least two
  systems so unit tests alone cannot cover it.

  Background:
    Given a clean full-integration world with Journal, EventRegistry, DayNightCycle, Catalog and Inventory

  Scenario: Full game state round trip — every autoload restored
    Given the Journal has full integration entries "J_FULL_A" and "J_FULL_B" unlocked
    And a GameEvent "E_FULL_A" that has fired 3 times
    And the day-night state is day 5 phase NIGHT elapsed 42.0
    And the Catalog has "P00001" cataloged and "P00108" encountered with label "Hostile"
    And the full inventory has 7 "P00010" and tool "weapon" is "P00204"
    When the full state is saved to disk and loaded into fresh instances
    Then the restored Journal has unlocked "J_FULL_A"
    And the restored Journal has unlocked "J_FULL_B"
    And the restored EventRegistry event "E_FULL_A" has count 3
    And the restored DayNightCycle has day 5 and phase NIGHT and elapsed 42.0
    And the restored Catalog has "P00001" CATALOGED
    And the restored Catalog has "P00108" ENCOUNTERED with label "Hostile"
    And the restored full inventory has 7 "P00010"
    And the restored full inventory tool "weapon" is "P00204"

  Scenario: Journal unlocked entries survive the JSON boundary
    Given the Journal has full integration entries "J_FULL_C" and "J_FULL_D" unlocked
    When the Journal is saved to a JSON file and loaded into a fresh instance
    Then the restored Journal has unlocked "J_FULL_C"
    And the restored Journal has unlocked "J_FULL_D"
    And the restored Journal unlocked count is 2

  Scenario: Catalog UNKNOWN state is persisted implicitly
    Given the Catalog has "P00001" cataloged
    And the Catalog has "P00006" in the default UNKNOWN state
    When the Catalog is saved and loaded into a fresh instance
    Then the restored Catalog has "P00001" CATALOGED
    And the restored Catalog has "P00006" UNKNOWN

  Scenario: Catalog ENCOUNTERED labels round trip
    Given the Catalog has "P00108" encountered with label "Hostile"
    When the Catalog is saved and loaded into a fresh instance
    Then the restored Catalog has "P00108" ENCOUNTERED with label "Hostile"

  Scenario: Recipe pending queue is cleared on load by design
    Given RecipeRuntime has a pending recipe "R00016"
    When the full state is saved to disk and loaded into fresh instances
    Then the restored RecipeRuntime pending queue is empty
    And the documented reason is "RecipeRuntime is transient — pending recipes are not persisted"

  Scenario: EventRegistry event counts preserved through save/load
    Given a GameEvent "E_FULL_B" that has fired 1 times
    And a GameEvent "E_FULL_C" that has fired 5 times
    When EventRegistry is saved and loaded into a fresh instance
    Then the restored EventRegistry event "E_FULL_B" has count 1
    And the restored EventRegistry event "E_FULL_C" has count 5

  Scenario: Inventory regular slots and tool slots preserved together
    Given the full inventory has 3 "P00010" and 2 "P00022"
    And the full inventory tool "weapon" is set to "P00204"
    And the full inventory tool "scanner" is set to "P00205"
    When the full inventory is saved and loaded into a fresh instance
    Then the restored full inventory has 3 "P00010"
    And the restored full inventory has 2 "P00022"
    And the restored full inventory tool "weapon" is "P00204"
    And the restored full inventory tool "scanner" is "P00205"

  Scenario: DayNightCycle day count phase and elapsed all round trip
    Given the day-night state is day 7 phase DAWN elapsed 3.5
    When DayNightCycle is saved and loaded into a fresh instance
    Then the restored DayNightCycle has day 7 and phase DAWN and elapsed 3.5

  Scenario: FaunaManager state is transient by design
    Given FaunaManager has 2 spawned fauna
    When the full state is saved to disk and loaded into fresh instances
    Then FaunaManager state is confirmed transient and not in the save payload

  Scenario: Multiple save slots do not cross-contaminate
    Given slot A has Journal "J_SLOT_A" and day 3
    And slot B has Journal "J_SLOT_B" and day 9
    When both slots are saved and loaded independently
    Then slot A restored Journal has unlocked "J_SLOT_A" and not "J_SLOT_B"
    And slot A restored day is 3
    And slot B restored Journal has unlocked "J_SLOT_B" and not "J_SLOT_A"
    And slot B restored day is 9

  Scenario: Corrupt save file does not crash the loader
    Given a corrupt save file is written to the SaveManager path
    When SaveManager tries to load the corrupt save
    Then SaveManager load_game returns false
    And the corrupt save file has been deleted

  Scenario: Missing save file is reported without crashing
    Given no save file exists at the SaveManager path
    When SaveManager tries to load the corrupt save
    Then SaveManager load_game returns false
