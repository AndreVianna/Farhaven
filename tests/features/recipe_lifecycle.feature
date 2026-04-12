Feature: Recipe Lifecycle — Consumption, Duration, Sustain, Scopes
  End-to-end plumbing for the recipe runtime: inputs consumed atomically,
  duration-based pending queue advancing via ticks, sustain conditions
  cancelling on failure, concurrent resolution, container/station/tile
  source priority, and tag-based input matching. Each scenario exercises
  the recipe runtime contract together with either Journal, DiscoveryWatcher,
  or the world-state containers it mutates — never the runtime in isolation.

  Background:
    Given a clean recipe runtime world with Journal and DiscoveryWatcher

  Scenario: Recipe start is rejected when required input is missing
    Given a recipe "R_MISSING" requiring 2 "P00010" from the tile
    And the tile has 0 "P00010"
    When the player tries to start recipe "R_MISSING"
    Then the start attempt returned null
    And the tile still has 0 "P00010"
    And no pending recipes are queued

  Scenario: Recipe consumes inputs atomically and enqueues when duration is positive
    Given a recipe "R_DURATION" requiring 2 "P00010" from the tile with duration 5.0
    And the tile has 3 "P00010"
    When the player tries to start recipe "R_DURATION"
    Then the tile has 1 "P00010"
    And the pending queue has 1 recipe
    And the recipe_started signal was emitted once for "R_DURATION"

  Scenario: Duration-based recipe resolves after enough ticks
    Given a recipe "R_DURATION2" requiring 1 "P00010" from the tile with duration 4.0
    And the recipe "R_DURATION2" unlocks journal entry "J_R_DURATION2"
    And the tile has 1 "P00010"
    When the player tries to start recipe "R_DURATION2"
    And the recipe runtime ticks 2.0 seconds
    Then the pending queue has 1 recipe
    When the recipe runtime ticks 2.5 seconds
    Then the pending queue has 0 recipes
    And the Journal has unlocked "J_R_DURATION2"
    And the recipe_resolved signal was emitted once for "R_DURATION2"

  Scenario: Sustain condition failure cancels the recipe and returns inputs
    Given a recipe "R_SUSTAIN" requiring 2 "P00010" from the tile with duration 6.0
    And the recipe "R_SUSTAIN" has a must_sustain world_flag "fireplace_lit" condition
    And the tile has 2 "P00010"
    And the world flag "fireplace_lit" is true
    When the player tries to start recipe "R_SUSTAIN"
    Then the tile has 0 "P00010"
    And the pending queue has 1 recipe
    When the world flag "fireplace_lit" is false
    And the recipe runtime ticks 1.0 seconds
    Then the pending queue has 0 recipes
    And the tile has 2 "P00010"
    And the recipe_cancelled signal was emitted once for "R_SUSTAIN" with reason "sustain_failed"

  Scenario: Two simultaneous recipes resolve independently
    Given a recipe "R_A" requiring 1 "P00010" from the tile with duration 3.0
    And a recipe "R_B" requiring 1 "P00011" from the tile with duration 6.0
    And the recipe "R_A" unlocks journal entry "J_R_A"
    And the recipe "R_B" unlocks journal entry "J_R_B"
    And the tile has 1 "P00010"
    And the tile has 1 "P00011"
    When the player tries to start recipe "R_A"
    And the player tries to start recipe "R_B"
    Then the pending queue has 2 recipes
    When the recipe runtime ticks 4.0 seconds
    Then the pending queue has 1 recipe
    And the Journal has unlocked "J_R_A"
    And the Journal is not unlocked "J_R_B"
    When the recipe runtime ticks 3.0 seconds
    Then the pending queue has 0 recipes
    And the Journal has unlocked "J_R_B"

  Scenario: Container-scope input is consumed from the container even when tile has matches
    Given a recipe "R_FUEL" requiring 1 "P00010" from the player vicinity
    And the tile has 1 "P00010"
    And the player is interacting with a container holding 1 "P00010"
    When the player tries to start recipe "R_FUEL"
    Then the container has 0 "P00010"
    And the tile still has 1 "P00010"

  Scenario: Station falls back to tile when container is empty
    Given a recipe "R_STATION_FALLBACK" requiring 1 "P00010" from the player vicinity
    And the tile has 1 "P00010"
    And the player is at a station with 0 "P00010"
    When the player tries to start recipe "R_STATION_FALLBACK"
    Then the tile has 0 "P00010"

  Scenario: Tag input resolves via a tag registry scan
    Given a recipe "R_TAG" requiring 1 tag "&BURNABLE" from the tile
    And the tag "&BURNABLE" includes "P00010"
    And the tile has 1 "P00010"
    When the player tries to start recipe "R_TAG"
    Then the tile has 0 "P00010"
    And the pending queue has 0 recipes
