Feature: Capability extension points integrate with engine subsystems
  These scenarios exercise the published extension points on capability
  classes — BehaviorCap.reactions, CombatCap.attacks/defenses,
  MovementCap.modes, EnduranceCap damage-tag arrays, CatalogableCap
  show_as_anomaly. Each scenario crosses at least two system boundaries:
  PropDef → Capability → GameEvent/EventRegistry, or PropDef → Capability
  → ResourceSaver round-trip, or PropDef → Catalog anomaly categorization.
  Combat runtime is deferred (see task-088); attack/defense coverage here
  proves the schema + iteration contract rather than a live combat loop.

  Background:
    Given a capability extension test world

  Scenario: BehaviorCap reaction GameEvent fires through EventRegistry
    Given a PropDef loaded from "res://data/props/P00108.tres"
    And a GameEvent "E_TEST_FLEE_REACTION" with max_count 0 is attached to behavior.reactions
    When the first behavior reaction event is fired through EventRegistry
    Then the fired event was accepted
    And the GameEvent "E_TEST_FLEE_REACTION" count is 1

  Scenario: CombatCap attacks array is iterable and each entry fires through EventRegistry
    Given a PropDef loaded from "res://data/props/P00108.tres"
    And GameEvents "E_TEST_ATTACK_A,E_TEST_ATTACK_B" with max_count 0 are attached to combat.attacks
    And GameEvents "E_TEST_DEFENSE_A" with max_count 0 are attached to combat.defenses
    When every combat attack event is fired through EventRegistry
    And every combat defense event is fired through EventRegistry
    Then the GameEvent "E_TEST_ATTACK_A" count is 1
    And the GameEvent "E_TEST_ATTACK_B" count is 1
    And the GameEvent "E_TEST_DEFENSE_A" count is 1

  Scenario: MovementCap modes Dictionary survives ResourceSaver round-trip
    Given a new PropDef "P_TEST_AMPHIB" is built with capabilities "movement"
    And the PropDef movement modes are set to "WALK=1.0,1.5;SWIM=0.8,1.2"
    When the PropDef is saved to disk and loaded back
    Then the reloaded PropDef movement mode 0 has normal speed 1.0
    And the reloaded PropDef movement mode 0 has max speed 1.5
    And the reloaded PropDef movement mode 1 has normal speed 0.8
    And the reloaded PropDef movement mode 1 has max speed 1.2

  Scenario: EnduranceCap damage-tag arrays round-trip and match by tag
    Given a new PropDef "P_TEST_ICEBEAST" is built with capabilities "endurance"
    And the PropDef endurance vulnerabilities are "FIRE,SHOCK"
    And the PropDef endurance resistances are "BLUNT"
    And the PropDef endurance immunities are "COLD"
    When the PropDef is saved to disk and loaded back
    Then the reloaded PropDef endurance is vulnerable to "FIRE"
    And the reloaded PropDef endurance is vulnerable to "SHOCK"
    And the reloaded PropDef endurance resists "BLUNT"
    And the reloaded PropDef endurance is immune to "COLD"
    And the reloaded PropDef endurance is not vulnerable to "COLD"

  Scenario: CatalogableCap show_as_anomaly override routes through ANOMALY_BUCKET
    Given a new PropDef "P_TEST_BEACON" is built with capabilities "catalogable"
    And the PropDef catalogable show_as_anomaly is true
    Then the PropDef resolves to the ANOMALY_BUCKET display bucket
    And a PropDef loaded from "res://data/props/P00108.tres" resolves to its prop_category display bucket
