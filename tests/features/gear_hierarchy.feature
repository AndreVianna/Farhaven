Feature: Gear Hierarchy
  All game entities follow the Gear base class hierarchy.

  Scenario: Every PropDef extends Gear
    Given all PropDef resources are loaded
    Then every PropDef has id, display_name, short_description, long_description fields

  Scenario: Every Recipe extends ScriptBase
    Given all Recipe resources are loaded
    Then every Recipe has conditions, effects, actions, duration fields
    And no Recipe has a field named "time"
    And no Recipe has a field named "unlock_when"

  Scenario: Recipe has no unlock_when
    Given all Recipe resources are loaded
    Then no Recipe has unlock_when data
