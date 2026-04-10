Feature: Event System
  Game events track occurrences and drive progression.

  Scenario: Discovery event fires on catalog trigger
    Given a discovery event with condition cataloged "P00004"
    And the event has effect grant_recipe "R00001"
    When prop P00004 is cataloged
    Then the event fires
    And recipe R00001 becomes known

  Scenario: One-shot event fires only once
    Given an event with max_count 1
    When the event fires
    Then count is 1
    And the event cannot fire again

  Scenario: Unlimited event fires multiple times
    Given an event with max_count 0
    When the event fires 3 times
    Then count is 3
    And the event can still fire

  Scenario: Event count persists on save/load
    Given an event that has fired twice
    When the game saves and loads
    Then the event count is still 2
