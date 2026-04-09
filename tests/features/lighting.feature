Feature: Lighting
  Campfires and torches emit light at night, persisting across save/load.

  Scenario: Campfire lights terrain at night
    Given a campfire light source at world position 10.0, 10.0 with radius 5.0
    When the lighting manager registers the source
    Then the active lights list contains 1 entry
    And the light at index 0 has radius 5.0

  Scenario: Save and load preserves light sources
    Given a campfire light source registered at world position 10.0, 10.0
    When the lighting state is saved and restored
    Then the active lights list contains 1 entry

  @pending
  Scenario: Player torch lights on game start at night
    # Requires scene tree + player node + DayNightCycle in NIGHT phase
    Given a fresh game at night
    Then the player torch light is active
