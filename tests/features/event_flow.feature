Feature: GameEvent Flow — try_fire, effect routing, count persistence
  End-to-end plumbing across EventRegistry, DiscoveryWatcher, and Journal.
  Each scenario exercises the real autoload nodes (instantiated fresh under
  tree.root) so a change anywhere in the signal chain — from GameEvent.fire
  through EventRegistry.try_fire emitting event_fired through a subscriber
  handler landing an effect — surfaces here, not in unit tests.

  Background:
    Given a clean event world with EventRegistry, DiscoveryWatcher and Journal

  Scenario: try_fire on a max_count-saturated event does not emit event_fired
    Given a GameEvent "E_SATURATED" already at max_count
    And the event_fired spy is clean
    When EventRegistry attempts to fire "E_SATURATED"
    Then the event_fired spy has 0 entries
    And the event "E_SATURATED" count is 1
    And the event "E_SATURATED" cannot fire again

  Scenario: try_fire with met precondition emits event_fired and increments count
    Given an unlimited GameEvent "E_GO"
    And the event_fired spy is clean
    When EventRegistry attempts to fire "E_GO"
    Then the event_fired spy recorded "E_GO" once
    And the event "E_GO" count is 1

  Scenario: One-shot GameEvent rejects a second fire after reaching max_count
    Given a one-shot GameEvent "E_ONESHOT"
    And the event_fired spy is clean
    When EventRegistry attempts to fire "E_ONESHOT"
    And EventRegistry attempts to fire "E_ONESHOT"
    Then the event "E_ONESHOT" count is 1
    And the event_fired spy recorded "E_ONESHOT" once
    And the event "E_ONESHOT" cannot fire again

  Scenario: Multi-count GameEvent fires up to max_count then refuses
    Given a GameEvent "E_TRIPLE" with max_count 3
    When EventRegistry attempts to fire "E_TRIPLE"
    And EventRegistry attempts to fire "E_TRIPLE"
    And EventRegistry attempts to fire "E_TRIPLE"
    And EventRegistry attempts to fire "E_TRIPLE"
    Then the event "E_TRIPLE" count is 3
    And the event_fired spy recorded "E_TRIPLE" 3 times

  Scenario: Event effect grant_recipe unlocks a recipe via DiscoveryWatcher
    Given an unlimited GameEvent "E_GRANT" with a grant_recipe effect for "R_GRANTED_X"
    When EventRegistry attempts to fire "E_GRANT"
    Then DiscoveryWatcher knows recipe "R_GRANTED_X"

  Scenario: Event effect unlock_journal_entry adds an entry via Journal
    Given an unlimited GameEvent "E_UNLOCK_J" with an unlock_journal_entry effect for "J_FROM_EVENT"
    When EventRegistry attempts to fire "E_UNLOCK_J"
    Then the Journal has unlocked "J_FROM_EVENT"

  Scenario: Event count persists through save/load via EventRegistry save data
    Given an unlimited GameEvent "E_PERSIST"
    When EventRegistry attempts to fire "E_PERSIST"
    And EventRegistry attempts to fire "E_PERSIST"
    Then the event "E_PERSIST" count is 2
    When the EventRegistry save data is captured, reset, and loaded back
    Then the event "E_PERSIST" count is 2
