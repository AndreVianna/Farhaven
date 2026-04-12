Feature: Combat — damage pipeline, multipliers, death, auto-defend gating
  Runtime combat from delivery-006e (tasks 102-116). DamageResolver
  applies EnduranceCap vulnerability / resistance / immunity multipliers
  (2x / 0.5x / 0x) then subtracts from hp. CombatRuntime dispatches
  attacks via DamageResolver. Auto-defend fires only when the target
  fauna is ENCOUNTERED or CATALOGED — the first encounter with an
  UNKNOWN fauna is a "free attack" so the player can gather information
  before engaging.

  These scenarios drive DamageResolver and EnduranceCap directly so they
  run with no scene tree, no autoloads, and no physics. The auto-defend
  gating scenarios simulate the knowledge-state gate with a dictionary
  flag rather than the full Catalog system.

  Scenario: Player attacks fauna — HP decreases by raw damage
    Given a target with hp 100 and no multipliers
    When a "PHYSICAL" damage event of 20 is resolved
    Then the damage dealt was 20
    And the target hp is 80

  Scenario: Fauna with a vulnerability takes 2x damage
    Given a target with hp 100 and vulnerability to "FIRE"
    When a "FIRE" damage event of 20 is resolved
    Then the damage dealt was 40
    And the target hp is 60

  Scenario: Fauna with a resistance takes half damage
    Given a target with hp 100 and resistance to "PHYSICAL"
    When a "PHYSICAL" damage event of 20 is resolved
    Then the damage dealt was 10
    And the target hp is 90

  Scenario: Fauna with immunity takes no damage
    Given a target with hp 100 and immunity to "POISON"
    When a "POISON" damage event of 50 is resolved
    Then the damage dealt was 0
    And the target hp is 100

  Scenario: Immunity wins over vulnerability when both are listed
    Given a target with hp 100 and vulnerability to "FIRE"
    And the target is also immune to "FIRE"
    When a "FIRE" damage event of 30 is resolved
    Then the damage dealt was 0
    And the target hp is 100

  Scenario: Damage reduces hp below zero — target is dead
    Given a target with hp 10 and no multipliers
    When a "PHYSICAL" damage event of 25 is resolved
    Then the damage dealt was 25
    And the target hp is -15
    And the target is dead

  Scenario: Auto-defend fires when fauna is ENCOUNTERED
    Given a fauna with knowledge state "ENCOUNTERED"
    When the auto-defend check runs
    Then the auto-defend fired

  Scenario: Auto-defend skipped when fauna is UNKNOWN (free first attack)
    Given a fauna with knowledge state "UNKNOWN"
    When the auto-defend check runs
    Then the auto-defend did not fire
