Feature: Survival Stats
  Hunger, thirst, and health drain over time and restore from consumables.

  Scenario: Thirst decreases over time
    Given the player has thirst 100.0
    When survival ticks for 10.0 seconds
    Then the player thirst is less than 100.0

  Scenario: Hunger decreases over time
    Given the player has hunger 100.0
    When survival ticks for 10.0 seconds
    Then the player hunger is less than 100.0

  Scenario: Health drains when hunger is zero
    Given the player has hunger 0 and health 100.0
    When survival ticks for 10.0 seconds
    Then the player health is less than 100.0

  Scenario: Health drains when thirst is zero
    Given the player has thirst 0 and health 100.0
    When survival ticks for 10.0 seconds
    Then the player health is less than 100.0

  Scenario: Health regenerates during daytime with food and water
    Given the player has health 50.0 hunger 50.0 thirst 50.0
    And it is daytime
    When survival ticks for 10.0 seconds
    Then the player health is greater than 50.0

  Scenario: Eating restores hunger
    Given the player has hunger 50.0
    When the player eats a berry restoring 5 hunger
    Then the player hunger is 55.0
