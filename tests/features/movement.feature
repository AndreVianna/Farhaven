Feature: Player Movement
  Player can move between hex tiles subject to biome, elevation, and structure rules.

  Scenario: Walk to adjacent passable tile succeeds
    Given a hex grid with tiles at 0,0 and 1,0 both elevation 0 biome GRASSLAND
    When the player walks from 0,0 to 1,0
    Then the traversal result is WALK

  Scenario: Walk to water tile is blocked
    Given a hex grid with tile at 0,0 elevation 0 biome GRASSLAND
    And a hex grid with tile at 1,0 elevation 0 biome WATER
    When the player checks traversal from 0,0 to 1,0
    Then the traversal result is BLOCKED

  Scenario: Walk across elevation diff 0-2 is WALK
    Given a hex grid with tile at 0,0 elevation 0 biome GRASSLAND
    And a hex grid with tile at 1,0 elevation 2 biome GRASSLAND
    When the player checks traversal from 0,0 to 1,0
    Then the traversal result is WALK

  Scenario: Walk across elevation diff 3-4 uphill is JUMP
    Given a hex grid with tile at 0,0 elevation 0 biome GRASSLAND
    And a hex grid with tile at 1,0 elevation 3 biome GRASSLAND
    When the player checks traversal from 0,0 to 1,0
    Then the traversal result is JUMP

  Scenario: Walk across elevation diff 5+ is BLOCKED
    Given a hex grid with tile at 0,0 elevation 0 biome GRASSLAND
    And a hex grid with tile at 1,0 elevation 5 biome GRASSLAND
    When the player checks traversal from 0,0 to 1,0
    Then the traversal result is BLOCKED

  Scenario: Wall structure blocks movement
    Given a hex grid with tile at 0,0 elevation 0 biome GRASSLAND
    And a hex grid with tile at 1,0 elevation 0 biome GRASSLAND
    And a wall prop on tile 1,0
    When the player checks traversal from 0,0 to 1,0
    Then the traversal result is BLOCKED

  Scenario: Walkable structures do not block movement
    Given a hex grid with tile at 0,0 elevation 0 biome GRASSLAND
    And a hex grid with tile at 1,0 elevation 0 biome GRASSLAND
    And a campfire prop on tile 1,0
    When the player checks traversal from 0,0 to 1,0
    Then the traversal result is WALK
