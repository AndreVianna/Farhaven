Feature: Cross-System Chains
  End-to-end flows that exercise multiple systems in sequence.

  Scenario: Full survival chain - gather then eat restores hunger
    Given the player has hunger 80.0
    And the inventory has 1 "00020"
    When the player eats "00020" restoring 5 hunger
    Then the player hunger is 85.0
    And the inventory has 0 "00020"

  Scenario: Full craft chain - gather materials then craft axe
    Given an inventory with 2 "00010" and 1 "00011"
    And recipe "00016" is known
    When the player crafts recipe "00016"
    Then tool "axe" is "00201"
    And the inventory has 0 "00010"
    And the inventory has 0 "00011"

  @pending
  Scenario: Full build chain - gather materials build campfire and light at night
    # Requires BuildingSystem + LightingManager + DayNightCycle wiring
    Given the inventory has 3 "00010" and 2 "00012"
    And recipe "00019" is known
    When the player builds a campfire on tile 1,0
    And night arrives
    Then LightingManager reports a light source near tile 1,0
