Feature: Inventory Full Integration — grid capacity, tool slots, expansion, save/load
  Exercises the real Inventory class (scripts/inventory/inventory.gd) against
  the real PropRegistry so PortableCap shapes, tool_slot constraints, grid
  capacity, expansion, and save/load round-trip are all verified end to end
  with the post-006f Tetris grid model. SimpleInventory (in common_steps.gd)
  cannot cover these flows because it has no tool slots, no grid composition,
  and no PropRegistry dependency.

  Background:
    Given the test runner has advanced one engine frame for inventory
    And a clean inventory world with a real Inventory backed by PropRegistry

  Scenario: Small-grid capacity enforces partial add and emits inventory_full with rejected count
    Given the real inventory is a 1x3 grid
    When the player attempts to add 5 "P00020" to the real inventory
    Then the real inventory has 3 "P00020"
    And the last add returned 3
    And the inventory_full signal fired for "P00020" with rejected count 2

  Scenario: Tool items are rejected from regular slots
    When the player attempts to add 1 "P00204" to the real inventory
    Then the last add returned 0
    And the real inventory has 0 "P00204"

  Scenario: Non-tool items cannot be placed in a tool slot by add_item
    When the player attempts to add 1 "P00010" to the real inventory
    Then the real inventory has 1 "P00010"
    And the tool slot "weapon" is empty

  Scenario: Tool slots are set via set_tool and emit tool_changed
    When the player sets tool slot "weapon" to "P00204" on the real inventory
    Then the tool slot "weapon" holds "P00204"
    And the tool_changed signal fired for slot "weapon" with new "P00204"

  Scenario: Save and load preserves regular grid items and scanner tool together
    Given the real inventory has 4 "P00010" in regular slots
    And the real inventory has tool "scanner" set to "P00205"
    When the real inventory is saved, cleared, and loaded back
    Then the real inventory has 4 "P00010"
    And the tool slot "scanner" holds "P00205"

  Scenario: Container expansion adds grid rows via expand()
    When the real inventory is expanded by 4 slots
    Then the real inventory has 120 more total slots

  Scenario: Each add_item call places one new instance in its own cells (no stacking)
    Given the real inventory has 3 "P00010" in regular slots
    When the player attempts to add 2 "P00010" to the real inventory
    Then the real inventory has 5 "P00010"
    And the real inventory used slot count is 5

  Scenario: Multiple adds accumulate item instances in the grid
    Given the real inventory has 95 "P00010" in regular slots
    When the player attempts to add 10 "P00010" to the real inventory
    Then the real inventory has 105 "P00010"
    And the real inventory used slot count is 105
