Feature: ID Namespace
  All game entities use prefixed IDs for universal uniqueness.

  Scenario: All prop IDs start with P
    Given all PropDef files are loaded
    Then every prop ID starts with "P"

  Scenario: All recipe IDs start with R
    Given all Recipe files are loaded
    Then every recipe ID starts with "R"

  Scenario: All event IDs start with E
    Given all Event files are loaded
    Then every event ID starts with "E"

  Scenario: No ID collisions across types
    Given all Gear IDs are collected
    Then there are no duplicate IDs
