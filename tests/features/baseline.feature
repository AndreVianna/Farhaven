Feature: Fresh Game State
  A new game with chapter 1 map must start with correct defaults.

  Background:
    Given a fresh game with chapter 1 map

  Scenario: World state matches ch1 map
    Then the world has more than 0 tiles

  Scenario: Player at spawn tile with correct position
    Then the player is at tile 0, 0

  Scenario: Starting loadout has knife, scanner, and flint_steel equipped
    Then tool "weapon" is "00204"
    And tool "scanner" is "00205"
    And tool "firestarter" is "00206"

  Scenario: All recipes are known from start
    Then every recipe with empty unlock_when is known
    And no recipe with non-empty unlock_when is known

  Scenario: Catalog is empty on fresh game
    Then the catalog has 0 cataloged entries

  Scenario: Day 1 and phase DAY on fresh game
    Then the day count is 1
    And the phase is "DAY"
