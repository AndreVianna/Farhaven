Feature: Save and Load
  Game state persists correctly through save and load cycles.

  Scenario: Save preserves player position
    Given the player is at tile 2, 1
    When the game is saved and loaded
    Then the player is at tile 2, 1

  Scenario: Save preserves inventory contents and weight
    Given the inventory has 5 "P00010"
    When the game is saved and loaded
    Then the inventory has 5 "P00010"
    And the inventory weight is greater than 0

  Scenario: Save preserves equipped tools
    Given tool "weapon" is set to "P00204"
    And tool "scanner" is set to "P00205"
    When the inventory is saved and loaded
    Then tool "weapon" is "P00204"
    And tool "scanner" is "P00205"

  Scenario: Save preserves catalog knowledge state
    Given catalog entry "P00001" is cataloged
    When the catalog is saved and loaded
    Then catalog entry "P00001" is CATALOGED

  Scenario: Save preserves known recipes list
    Given recipe "R00016" is known
    When the discovery state is saved and loaded
    Then recipe "R00016" is known

  @pending
  Scenario: Save preserves placed structures
    # Requires full HexGrid save/load with prop serialization
    Given a campfire structure on tile 1,0
    When the game is saved and loaded
    Then tile 1,0 has a structure prop "P00101"

  Scenario: Save preserves day count and phase
    Given the day count is 3 and phase is NIGHT
    When the day-night state is saved and loaded
    Then the day count is 3
    And the phase is "NIGHT"

  Scenario: Load restores all correctly after round-trip
    Given a full game state with inventory tools catalog and day 5
    When the full state is saved and loaded
    Then the inventory has 5 "P00010"
    And tool "weapon" is "P00204"
    And the day count is 5

  Scenario: Fresh game after delete save equals clean baseline
    Given a save file exists
    When the save is deleted and a fresh game starts
    Then the day count is 1
    And the phase is "DAY"
    And the inventory is empty
