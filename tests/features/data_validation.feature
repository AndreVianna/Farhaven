Feature: Data Integrity
  All PropDef and Recipe .tres files must follow naming and structural rules
  to ensure the game data pipeline works correctly.

  # --- PropDef Validation ---

  Scenario: Every PropDef has a non-empty id
    Given all PropDefs are loaded
    Then every PropDef has a non-empty id

  Scenario: Every PropDef has a non-empty display_name
    Given all PropDefs are loaded
    Then every PropDef has a non-empty display_name

  Scenario: PropDef ids are unique
    Given all PropDefs are loaded
    Then all PropDef ids are unique

  Scenario: Source props have the catalogable capability
    Given all PropDefs are loaded
    Then every PropDef tagged "SOURCE" has a catalogable capability

  Scenario: Portable props have a positive weight
    Given all PropDefs are loaded
    Then every PropDef with a portable capability has weight greater than 0

  Scenario: Structure placeable props have a non-empty footprint
    Given all PropDefs are loaded
    Then every PropDef tagged "STRUCTURE" with a placeable capability has a non-empty footprint

  # --- Recipe Validation ---

  Scenario: Every Recipe has a non-empty id
    Given all Recipes are loaded
    Then every Recipe has a non-empty id

  Scenario: Every Recipe has a non-empty display_name
    Given all Recipes are loaded
    Then every Recipe has a non-empty display_name

  Scenario: Recipe ids are unique
    Given all Recipes are loaded
    Then all Recipe ids are unique

  Scenario: Recipe inputs with numeric ids reference valid props
    Given all PropDefs are loaded
    And all Recipes are loaded
    Then every Recipe input with numeric ref references a valid PropDef id

  Scenario: Recipe outputs with numeric ids reference valid props
    Given all PropDefs are loaded
    And all Recipes are loaded
    Then every Recipe output with numeric ref references a valid PropDef id

  Scenario: Recipe output probabilities are between 0 and 1
    Given all Recipes are loaded
    Then every Recipe output has prob between 0 and 1

  Scenario: Recipe ids start with R prefix
    Given all Recipes are loaded
    Then every Recipe id starts with R prefix
