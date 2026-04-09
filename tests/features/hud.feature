Feature: HUD State
  The heads-up display shows survival stats, day counter, and panels.

  @pending
  Scenario: Stat bars reflect current survival values
    # Requires HUD scene tree + SurvivalSystem wiring
    Given the player has health 75.0 hunger 50.0 thirst 25.0
    Then the health bar shows 75 percent
    And the hunger bar shows 50 percent
    And the thirst bar shows 25 percent

  @pending
  Scenario: Day counter shows current day
    # Requires HUD scene tree
    Given the day count is 5
    Then the day counter label shows "Day 5"

  @pending
  Scenario: Inventory panel opens and closes
    # Requires HUD scene tree + panel mutual exclusion
    When the inventory panel is opened
    Then the inventory panel is visible
    When the inventory panel is closed
    Then the inventory panel is hidden

  @pending
  Scenario: Catalog panel opens and closes
    # Requires HUD scene tree + panel mutual exclusion
    When the catalog panel is opened
    Then the catalog panel is visible

  @pending
  Scenario: Panel mutual exclusion
    # Requires HUD scene tree
    When the inventory panel is opened
    And the catalog panel is opened
    Then the inventory panel is hidden
    And the catalog panel is visible
