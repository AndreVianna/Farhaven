Feature: Day-Night Cycle
  The world cycles through DAY, DUSK, NIGHT, DAWN phases.

  Scenario: Phase transitions in correct order
    Given the phase is DAY
    When the phase advances
    Then the phase is "DUSK"
    When the phase advances
    Then the phase is "NIGHT"
    When the phase advances
    Then the phase is "DAWN"
    When the phase advances
    Then the phase is "DAY"

  Scenario: Day counter increments at dawn
    Given the day count is 1
    And the phase is NIGHT
    When the phase advances to DAWN
    Then the day count is 2

  Scenario: Lighting parameters change per phase
    Given the phase is DAY
    Then the ambient energy is 0.4
    When the phase is set to NIGHT
    Then the ambient energy is 0.03
