Feature: Inventory Weight System
  Inventory uses weight-based capacity. Items are accepted or rejected
  based on total weight, not slot count.

  Scenario: Weight increases on item pickup
    Given an empty inventory with capacity 50.0
    When the player picks up 3 "P00010"
    Then the inventory weight is greater than 0

  Scenario: Item rejected when inventory capacity is exhausted
    Given an empty inventory with capacity 0.5
    When the player picks up 1 "P00010"
    Then the inventory has 0 "P00010"

  Scenario: Starting loadout on fresh game matches chapter 1 map
    Given a fresh game with chapter 1 map
    Then tool "weapon" is "P00204"
    And tool "scanner" is "P00205"
    And tool "firestarter" is "P00206"
