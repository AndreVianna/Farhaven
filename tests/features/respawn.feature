Feature: Death and Respawn
  When the player dies, they respawn at the crash site or nearest shelter.

  Scenario: Death respawns at crash site when no shelter exists
    Given the player has no shelter built
    And the spawn tile is 0,0
    When the player dies
    Then the respawn tile is 0,0

  Scenario: Death respawns at nearest shelter
    Given a shelter on tile 3,0
    And the player is closer to tile 3,0 than to spawn
    When the player dies
    Then the respawn tile is 3,0

  Scenario: Map edge blocks movement
    Given a hex grid with tile at 0,0 elevation 0 biome GRASSLAND
    And no tile exists at -1,0
    When the player checks traversal from 0,0 to -1,0
    Then the traversal result is BLOCKED
