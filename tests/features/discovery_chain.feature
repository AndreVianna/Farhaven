Feature: Discovery Chain — Catalog → Event → Content Unlock
  End-to-end cross-system flow: when the scanner signals a newly-cataloged
  entry, DiscoveryWatcher processes its entry_cataloged connection, the
  bound discovery GameEvent fires through EventRegistry, and its effect
  lands on the Journal (for documentation) and DiscoveryWatcher (for
  recipe-grant). This is the plumbing chapter-1 content will depend on.

  Background:
    Given a clean discovery chain world

  Scenario: Scanner-driven entry_cataloged fires the bound discovery event end-to-end
    Given a discovery GameEvent "E_DISC_A" that grants recipe "R_DISC_A" and unlocks entry "J_DISC_A"
    And the event "E_DISC_A" is registered on EventRegistry
    And the journal starts empty
    When the scanner signals entry_cataloged for "P_TEST_AA"
    And DiscoveryWatcher runs check_unlocks with catalog tracking "P_TEST_AA"
    Then DiscoveryWatcher knows recipe "R_DISC_A"
    And the Journal has unlocked "J_DISC_A"
    And the event "E_DISC_A" count is 1

  Scenario: Discovery event with unmet condition does not fire even after catalog signal
    Given a discovery GameEvent "E_DISC_B" that grants recipe "R_DISC_B"
    And the event "E_DISC_B" has an impossible cataloged condition for "P_NEVER"
    And the event "E_DISC_B" is registered on EventRegistry
    When the scanner signals entry_cataloged for "P_TEST_BB"
    And DiscoveryWatcher runs check_unlocks with catalog tracking "P_TEST_BB"
    Then DiscoveryWatcher does not know recipe "R_DISC_B"
    And the event "E_DISC_B" cannot fire again

  Scenario: Second catalog signal does not re-fire a one-shot discovery event
    Given a discovery GameEvent "E_DISC_C" that grants recipe "R_DISC_C"
    And the event "E_DISC_C" is registered on EventRegistry
    When the scanner signals entry_cataloged for "P_TEST_CC"
    And DiscoveryWatcher runs check_unlocks with catalog tracking "P_TEST_CC"
    And the scanner signals entry_cataloged for "P_TEST_CC"
    And DiscoveryWatcher runs check_unlocks with catalog tracking "P_TEST_CC"
    Then DiscoveryWatcher knows recipe "R_DISC_C"
    And the event "E_DISC_C" count is 1
