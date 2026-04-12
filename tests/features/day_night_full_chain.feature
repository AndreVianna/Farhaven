Feature: Day-night full chain integration
  Cross-system integration of DayNightCycle with LightingManager, FaunaManager,
  and the player torch logic. Each scenario drives the real autoload code end
  to end and asserts observable side effects that cross a system boundary (not
  a single-unit path). task-085e (delivery-006d).

  Background:
    Given a clean day-night world wired to LightingManager and FaunaManager

  Scenario: phase_changed signal fires when DayNightCycle advances from DAY
    Given the DayNightCycle phase is DAY
    When the DayNightCycle phase advances
    Then the phase_changed signal was emitted with new phase "DUSK"
    And the DayNightCycle current phase is "DUSK"

  Scenario: DUSK activates structure lights through LightingManager get_active_lights
    Given the DayNightCycle phase is DAY
    And a registered structure light "test:campfire" at position 10,20 radius 12
    And LightingManager reports no active lights
    When the DayNightCycle phase is forced to NIGHT
    Then LightingManager reports 1 active lights
    And LightingManager light at index 0 has radius 12

  Scenario: DAWN deactivates local lights via LightingManager day-phase gate
    Given the DayNightCycle phase is NIGHT
    And a registered structure light "test:torch" at position 0,0 radius 9
    And LightingManager reports 1 active lights
    When the DayNightCycle phase is forced to DAWN
    Then LightingManager reports no active lights

  Scenario: FaunaManager despawns on DayNightCycle dawn signal
    Given a FaunaManager wired to the DayNightCycle
    And the FaunaManager has a seeded fauna entry at 5,5
    When the DayNightCycle emits the dawn signal
    Then the FaunaManager has 0 fauna entries
    And the fauna_despawned signal was emitted once

  Scenario: FaunaManager receives the night signal via production wiring
    Given a FaunaManager wired to the DayNightCycle
    And the FaunaManager is registered to the night signal
    When the DayNightCycle emits the night signal
    Then the FaunaManager received the night wake-up

  Scenario: Player torch with LightCap scanner tool activates at night
    Given the DayNightCycle phase is NIGHT
    And the player is carrying a scanner tool with a LightCap
    When LightingManager updates the player torch from inventory
    Then LightingManager has a player torch light registered
    And LightingManager reports 1 active lights

  Scenario: Player without a light tool reports no player torch light
    Given the DayNightCycle phase is NIGHT
    And the player has no tool equipped in the scanner slot
    When LightingManager updates the player torch from inventory
    Then LightingManager has no player torch light
    And LightingManager reports no active lights

  Scenario: DayNightCycle full rotation increments day counter at NIGHT to DAWN
    Given the DayNightCycle phase is NIGHT
    And the DayNightCycle day count is 3
    When the DayNightCycle phase advances
    Then the DayNightCycle current phase is "DAWN"
    And the DayNightCycle day count is 4
    And the phase_changed signal was emitted with new phase "DAWN"
