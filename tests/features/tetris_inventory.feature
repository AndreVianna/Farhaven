Feature: Tetris Inventory — grid placement, rotation, save/load, tool lookup
  Grid-based backpack from delivery-006f. Items occupy cells defined by
  their PortableCap.slot_shape and can be rotated in 90° increments. The
  grid is a flat PackedInt32Array; _items tracks origin + rotation + shape
  per instance. Scanner stays body-integrated; all other tools live in
  the grid and are located via find_best_tool_for_action.

  These scenarios use a standalone in-feature GridModel (see
  tetris_inventory_steps.gd) that mirrors the production invariants
  without a PropRegistry autoload dependency. This is intentionally
  model-level BDD — the cell-writing, fit-check, rotation, rebuild,
  save/load, and slot→grid-aware tool lookup logic mirrors inventory.gd
  so the scenarios describe the contract the production code is expected
  to satisfy. Unit tests in tests/unit/test_inventory_grid.gd exercise
  the real Inventory class directly.

  Scenario: Single-cell item fits on an empty grid
    Given a fresh tetris inventory 4 wide by 4 tall
    When the shape "single" is placed at 2,3 with rotation 0
    Then the placement succeeded
    And the cell at 2,3 is occupied
    And the tetris inventory item count is 1

  Scenario: Multi-cell axe shape occupies all its cells
    Given a fresh tetris inventory 6 wide by 8 tall
    When the shape "axe" is placed at 0,0 with rotation 0
    Then the placement succeeded
    And the cell at 0,0 is occupied
    And the cell at 0,3 is occupied
    And the cell at 1,3 is occupied
    And the cell at 0,5 is occupied
    And the cell at 2,0 is empty

  Scenario: Placement rejected when shape extends out of bounds
    Given a fresh tetris inventory 3 wide by 3 tall
    When the shape "plank" is placed at 0,0 with rotation 0
    Then the placement was rejected
    And the tetris inventory item count is 0

  Scenario: Placement rejected when target cells are already occupied
    Given a fresh tetris inventory 4 wide by 4 tall
    When the shape "single" is placed at 1,1 with rotation 0
    And the shape "single" is placed at 1,1 with rotation 0
    Then the placement was rejected
    And the tetris inventory item count is 1

  Scenario: Auto-placement overflow rejects beyond capacity
    Given a fresh tetris inventory 2 wide by 2 tall
    When 5 copies of "single" are auto-placed
    Then 4 copies of "single" were accepted
    And 1 copies of "single" were rejected

  Scenario: Remove item clears all of its cells
    Given a fresh tetris inventory 6 wide by 8 tall
    And the shape "axe" is placed at 0,0 with rotation 0
    When the last placed item is removed
    Then the cell at 0,0 is empty
    And the cell at 0,3 is empty
    And the cell at 1,3 is empty
    And the tetris inventory item count is 0

  Scenario: Rotation turns a horizontal bar into a vertical one
    Given a fresh tetris inventory 4 wide by 4 tall
    When the shape "stick" is placed at 0,0 with rotation 1
    Then the placement succeeded
    And the cell at 0,0 is occupied
    And the cell at 0,1 is occupied
    And the cell at 0,2 is occupied
    And the cell at 1,0 is empty

  Scenario: Save and load preserves items with origins and rotations
    Given a fresh tetris inventory 5 wide by 5 tall
    And the shape "single" is placed at 4,4 with rotation 0
    And the shape "stick" is placed at 0,0 with rotation 1
    When the tetris inventory is saved and reloaded
    Then the tetris inventory item count is 2
    And the cell at 4,4 is occupied
    And the cell at 0,0 is occupied
    And the cell at 0,2 is occupied

  Scenario: find_best_tool_for_action returns a grid-held tool
    Given a fresh tetris inventory 4 wide by 4 tall
    And a grid item type "P00200" supports action "chop"
    When the shape "single" of type "P00200" is placed at 0,0 with rotation 0
    Then find_best_tool_for_action "chop" returns a grid item

  Scenario: find_best_tool_for_action falls back to the legacy tool slot
    Given a fresh tetris inventory 4 wide by 4 tall
    And the legacy tool slot "axe" holds "P00200"
    Then find_best_tool_for_action "chop" falls back to the tool slot

  Scenario: Legacy slot-based save migrates into the grid
    Given a legacy save with 3 of "single" in slots
    When the legacy save is loaded into a fresh tetris inventory
    Then the tetris inventory item count is 3
