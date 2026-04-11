Feature: Narrative — Journal, Cutscenes, Events
  Engine plumbing that ties GameEvents, Recipe effects, the Journal autoload,
  and CutsceneManager together. No story content — just the wiring delivery-007
  will pour narrative into. Each scenario exercises at least two systems
  crossing a signal or autoload boundary so unit tests alone cannot cover it.

  Background:
    Given a clean narrative world with EventRegistry, Journal and CutsceneManager

  Scenario: Journal unlocks via EventRegistry effect dispatch
    Given a GameEvent "E_TEST_JOURNAL_A" with an unlock_journal_entry effect for "J_TEST_001"
    And the Journal has no entries unlocked
    When EventRegistry fires "E_TEST_JOURNAL_A"
    Then the Journal has unlocked "J_TEST_001"
    And the journal_entry_added signal was emitted once for "J_TEST_001"

  Scenario: Journal unlocks via RecipeRuntime effect path
    Given a Recipe with an unlock_journal_entry effect for "J_TEST_002"
    And the Journal has no entries unlocked
    When RecipeRuntime applies the recipe effects
    Then the Journal has unlocked "J_TEST_002"
    And the journal_entry_added signal was emitted once for "J_TEST_002"

  Scenario: Duplicate unlock through EventRegistry is idempotent
    Given the Journal already has "J_TEST_003" unlocked
    And a GameEvent "E_TEST_JOURNAL_B" with an unlock_journal_entry effect for "J_TEST_003"
    When EventRegistry fires "E_TEST_JOURNAL_B"
    Then the Journal unlocked count is unchanged
    And the journal_entry_added signal was not emitted

  Scenario: Journal save and load restores unlocked entries
    Given the Journal has "J_TEST_004" and "J_TEST_005" unlocked
    When the Journal save data is captured, cleared, and loaded back
    Then the Journal has unlocked "J_TEST_004"
    And the Journal has unlocked "J_TEST_005"
    And the Journal unlocked count is 2

  Scenario: CutsceneManager plays a cutscene triggered by a GameEvent
    Given a CutsceneDef "C_TEST_001" registered with trigger_event "E_TEST_CUTSCENE_A"
    And a GameEvent "E_TEST_CUTSCENE_A"
    When EventRegistry fires "E_TEST_CUTSCENE_A"
    Then CutsceneManager is playing "C_TEST_001"
    And the cutscene overlay is attached to the scene tree

  Scenario: CutsceneManager rejects a second play while already playing
    Given a CutsceneDef "C_TEST_002" registered
    And a CutsceneDef "C_TEST_003" registered
    And CutsceneManager is playing "C_TEST_002"
    When CutsceneManager.play is called for "C_TEST_003"
    Then the play call returned false
    And CutsceneManager is still playing "C_TEST_002"

  Scenario: Skipping a cutscene emits cutscene_finished with skipped=true
    Given a CutsceneDef "C_TEST_004" registered
    And CutsceneManager is playing "C_TEST_004"
    When CutsceneManager.skip is called
    Then cutscene_finished was emitted once for "C_TEST_004" with skipped true
    And CutsceneManager is idle

  Scenario: Natural end of a cutscene emits cutscene_finished with skipped=false
    Given a CutsceneDef "C_TEST_005" registered
    And CutsceneManager is playing "C_TEST_005"
    When the cutscene video reaches its natural end
    Then cutscene_finished was emitted once for "C_TEST_005" with skipped false
    And CutsceneManager is idle
    And the cutscene overlay is no longer attached to the scene tree

  Scenario: GameEvent with unlock_journal_entry fires without side effects on unrelated systems
    Given a GameEvent "E_TEST_JOURNAL_C" with an unlock_journal_entry effect for "J_TEST_006"
    And a CutsceneDef "C_TEST_006" registered with trigger_event "E_TEST_CUTSCENE_UNRELATED"
    When EventRegistry fires "E_TEST_JOURNAL_C"
    Then the Journal has unlocked "J_TEST_006"
    And CutsceneManager is idle

  Scenario: JournalEntryRegistry loads the committed fixture from disk
    Given JournalEntryRegistry has scanned the journal data directory
    Then JournalEntryRegistry has entry "J00001"
    And the entry "J00001" has a non-empty display_name

  Scenario: CutsceneManager loads the committed fixture from disk
    Given CutsceneManager has scanned the cutscene data directory
    Then CutsceneManager has def "C00001"
    And the def "C00001" has a non-empty display_name
