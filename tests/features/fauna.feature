Feature: Fauna
  Hostile fauna spawn at night from day 4+, deal contact damage,
  and drop resources when killed.

  Scenario: No fauna spawn before day 4
    Given the day count is 3
    When night arrives
    Then the fauna count is 0

  Scenario: Fauna spawn at night on day 4+
    Given the day count is 4
    And valid spawn tiles exist outside light radius
    When night arrives and spawn is triggered
    Then the fauna count is between 1 and 3

  Scenario: Contact damage applies unless in shelter
    Given a fauna adjacent to the player
    And the player is not on a shelter tile
    When the fauna attacks
    Then the player takes 10 damage

  Scenario: Shelter grants immunity to contact damage
    Given a fauna adjacent to the player
    And the player is on a shelter tile
    When the fauna attacks
    Then the player takes 0 damage

  Scenario: Fauna killed drops via breakdown recipe
    Given a fauna at tile 2,0 with hp 0
    When the fauna dies
    Then a corpse prop is placed on tile 2,0
