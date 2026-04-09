Feature: Crafting
  Player can craft items from gathered materials using known recipes.

  Scenario: Craft stone axe with sufficient materials
    Given an inventory with 2 "00010" and 1 "00011"
    And recipe "00016" is known
    When the player crafts recipe "00016"
    Then tool "axe" is "00201"

  Scenario: Craft fails with insufficient materials
    Given an inventory with 1 "00010" and 0 "00011"
    And recipe "00016" is known
    When the player attempts recipe "00016"
    Then the recipe attempt returns null

  Scenario: Crafting recipes show affordability based on inventory
    Given recipe "00016" requires 2 "00010" and 1 "00011"
    And the inventory has 2 "00010"
    And the inventory has 1 "00011"
    Then recipe "00016" is affordable
