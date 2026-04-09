Feature: Gathering and Discovery
  Scanning sources unlocks recipes, tools gate certain gathering actions,
  and gathering depletes the source.

  Scenario: Scan source unlocks its recipe
    Given a catalog with "00001" in UNKNOWN state
    When the player scans prop "00001" to completion
    Then catalog entry "00001" is CATALOGED

  Scenario: Tool-gated gathering requires the right tool
    Given a recipe "00007" that requires tool "pickaxe"
    When the player has no pickaxe equipped
    Then the recipe "00007" condition check fails for has_tool

  Scenario: Gathering depletes source remaining count
    Given a prop "00001" on tile 0,0 with remaining 5
    When the prop is gathered once
    Then the prop remaining on tile 0,0 is 4

  Scenario: Anomaly Fragment is scannable
    Given all PropDefs are loaded
    Then PropDef "10001" has a catalogable capability
