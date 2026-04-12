Feature: Multi-capability PropDef integration
  PropDef composes capability resources — Endurance, Movement, Combat,
  Behavior, Spawnable, Container, Portable, Placeable — and every scenario
  here crosses at least two system boundaries: the data layer that loads
  .tres files, the PropDef/Capability contract, and the Resource round-trip
  path (ResourceSaver/ResourceLoader). These scenarios guard the composition
  contract that content authoring (delivery-007) depends on.

  Scenario: Fauna PropDef with five capabilities loads from disk with no interference
    Given a PropDef loaded from "res://data/props/P00108.tres"
    Then the PropDef has capability "endurance"
    And the PropDef has capability "movement"
    And the PropDef has capability "combat"
    And the PropDef has capability "behavior"
    And the PropDef has capability "spawnable"
    And the PropDef has capability "catalogable"
    And the PropDef does not have capability "portable"
    And the PropDef does not have capability "container"
    And the PropDef does not have capability "light"
    And the PropDef endurance hp is 20
    And the PropDef movement mode 0 has normal speed 1.0
    And the PropDef behavior diet contains "FAUNA"
    And the PropDef spawnable first_spawn_day is 4

  Scenario: A PropDef built programmatically with Container + Portable + Placeable survives save/load
    Given a new PropDef "P_TEST_CHEST" is built with capabilities "portable,placeable,container"
    And the PropDef container has capacity_size 100.0
    And the PropDef portable has size 2.0
    When the PropDef is saved to disk and loaded back
    Then the reloaded PropDef has capability "portable"
    And the reloaded PropDef has capability "placeable"
    And the reloaded PropDef has capability "container"
    And the reloaded PropDef does not have capability "endurance"
    And the reloaded PropDef container capacity_size is 100.0
    And the reloaded PropDef portable size is 2.0

  Scenario: Adding a capability at runtime does not disturb siblings
    Given a PropDef loaded from "res://data/props/P00108.tres"
    When an EnduranceCap with hp 42 is assigned to the PropDef at runtime
    Then the PropDef endurance hp is 42
    And the PropDef has capability "movement"
    And the PropDef has capability "combat"
    And the PropDef has capability "behavior"
    And the PropDef behavior diet contains "FAUNA"

  Scenario: Missing capability returns null on a PropDef without it
    Given a new PropDef "P_TEST_ROCK" is built with capabilities "portable,placeable"
    Then the PropDef does not have capability "endurance"
    And the PropDef endurance is null
    And the PropDef movement is null
    And the PropDef combat is null
    And the PropDef behavior is null
