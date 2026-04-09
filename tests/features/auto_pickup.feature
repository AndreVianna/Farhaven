Feature: Auto Pickup
  Ground items are automatically picked up when the player enters a tile.

  Scenario: Ground items picked up on tile entry
    Given a ground item "00010" with count 2 on tile 1,0
    And the inventory is empty
    When the player enters tile 1,0
    Then the inventory has 2 "00010"
    And the ground item is removed from tile 1,0
