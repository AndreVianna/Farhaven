Feature: SSH Grid Placement
  Structures snap to sub-sub-hex grid at 32cm resolution.

  Scenario: Structure placement snaps to SSH center
    Given a tile at 0, 0
    When a structure is placed at world position near an SSH center
    Then the structure position is snapped to the nearest SSH center
    And the position is within 0.16m of the requested position

  Scenario: Two structures at different SSH positions coexist
    Given a tile at 0, 0
    When a campfire is placed at SSH 0, 0
    And a torch is placed at SSH 1, 0
    Then both structures exist on the tile
