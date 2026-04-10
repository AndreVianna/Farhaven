Feature: Building
  Players build structures by placing them on buildable tiles via recipes.

  Scenario: Build campfire places structure on tile
    Given an inventory with 3 "P00010" and 2 "P00012"
    And recipe "R00019" is known
    And a buildable tile at 1,0
    When the player builds recipe "R00019" on tile 1,0
    Then tile 1,0 has a structure prop "P00101"

  Scenario: Wall blocks movement after placement
    Given a hex grid with tile at 0,0 elevation 0 biome GRASSLAND
    And a hex grid with tile at 1,0 elevation 0 biome GRASSLAND
    And a wall prop on tile 1,0
    Then traversal from 0,0 to 1,0 is BLOCKED

  Scenario: Storage chest increases inventory weight capacity
    Given an inventory with capacity 50.0
    When a storage chest is placed
    Then the inventory capacity is 100.0

  @pending
  Scenario: Torch provides light at night
    # Requires LightingManager wiring + DayNightCycle in NIGHT phase
    Given a torch placed on tile 1,0
    And the day-night cycle is in NIGHT phase
    Then LightingManager reports a light source near tile 1,0

  Scenario: Footprint overlap is rejected
    Given a tile at 1,0 with a structure occupying sub-hex 0,0
    When the player tries to place another structure at sub-hex 0,0 on tile 1,0
    Then the placement is rejected

  Scenario: Placement cancel consumes no materials
    Given an inventory with 3 "P00010" and 2 "P00012"
    When the player cancels placement before confirming
    Then the inventory has 3 "P00010"
    And the inventory has 2 "P00012"
