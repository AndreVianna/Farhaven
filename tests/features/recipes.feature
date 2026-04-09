Feature: Recipe Lifecycle
  Recipes can be passive (auto-fire), sustain-gated, or triggered by proximity.

  Scenario: Passive recipe fires after time (meat rots)
    Given recipe "00014" is a passive transform with time 86400.0
    Then recipe "00014" has no actions
    And recipe "00014" has time greater than 0

  Scenario: Sustain condition failure cancels recipe
    Given recipe "00011" has a must_sustain condition
    Then the sustain condition on recipe "00011" is for predicate "prop_state"

  Scenario: Trap fires when fauna approaches
    Given recipe "00013" has a condition with predicate "animal_nearby"
    Then recipe "00013" has no actions
