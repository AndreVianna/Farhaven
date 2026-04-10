Feature: Crafting
  Player can craft items from gathered materials using known recipes.

  Scenario: Craft stone axe with sufficient materials
    Given an inventory with 2 "P00010" and 1 "P00011"
    And recipe "R00016" is known
    When the player crafts recipe "R00016"
    Then tool "axe" is "P00201"

  Scenario: Craft fails with insufficient materials
    Given an inventory with 1 "P00010" and 0 "P00011"
    And recipe "R00016" is known
    When the player attempts recipe "R00016"
    Then the recipe attempt returns null

  Scenario: Crafting recipes show affordability based on inventory
    Given recipe "R00016" requires 2 "P00010" and 1 "P00011"
    And the inventory has 2 "P00010"
    And the inventory has 1 "P00011"
    Then recipe "R00016" is affordable
