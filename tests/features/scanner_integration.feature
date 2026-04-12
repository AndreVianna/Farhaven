Feature: Scanner Integration — ScannerSystem + Catalog + HexGrid wiring
  End-to-end scanner flows that exercise the real ScannerSystem, real Catalog,
  and the real HexGrid autoload together. Unit tests cover individual systems;
  these scenarios verify the boundary signals, multi-prop queue behaviour, and
  range-based interruption/resume that depend on more than one component.

  Background:
    Given the test runner has advanced one engine frame
    And a clean scanner world with real HexGrid, PropRegistry and ScannerSystem

  Scenario: Unknown plant transitions UNKNOWN to CATALOGED through a full scan
    Given a test plant "PTEST_PLANT_A" placed at tile 500, 500
    And the test player is standing on tile 500, 500
    When the scanner system processes 0.05 seconds
    Then the scanner is scanning "PTEST_PLANT_A"
    When the scanner system processes 2.5 seconds
    Then the catalog state of "PTEST_PLANT_A" is CATALOGED
    And the scanner entry_cataloged signal fired for "PTEST_PLANT_A"

  Scenario: Hostile fauna surprise flips UNKNOWN to ENCOUNTERED via attack hook
    Given a test hostile fauna "PTEST_FAUNA_A" placed at tile 500, 500
    And the test player is standing on tile 500, 500
    When the fauna "PTEST_FAUNA_A" attacks the player
    Then the catalog state of "PTEST_FAUNA_A" is ENCOUNTERED
    And the scanner entry_encountered signal fired for "PTEST_FAUNA_A" with label "Hostile"

  Scenario: Anomaly override routes the display bucket to ANOMALY_BUCKET
    Given a test anomaly prop "PTEST_ANOMALY_A" placed at tile 500, 500
    And the test player is standing on tile 500, 500
    When the scanner system processes 0.05 seconds
    And the scanner system processes 3.5 seconds
    Then the catalog state of "PTEST_ANOMALY_A" is CATALOGED
    And the last entry_cataloged bucket for "PTEST_ANOMALY_A" was ANOMALY_BUCKET
    And the last entry_cataloged bucket was not a natural prop category

  Scenario: Scanner interrupts when the player moves out of range mid-scan
    Given a test plant "PTEST_PLANT_B" placed at tile 500, 500
    And the test player is standing on tile 500, 500
    When the scanner system processes 0.05 seconds
    Then the scanner is scanning "PTEST_PLANT_B"
    When the test player moves to tile 510, 510
    And the scanner system processes 0.05 seconds
    Then the scanner is idle
    And the scanner scan_interrupted signal fired
    And the catalog state of "PTEST_PLANT_B" is UNKNOWN

  Scenario: Scanner resumes a new scan when the player re-enters range
    Given a test plant "PTEST_PLANT_C" placed at tile 500, 500
    And the test player is standing on tile 500, 500
    When the scanner system processes 0.05 seconds
    Then the scanner is scanning "PTEST_PLANT_C"
    When the test player moves to tile 510, 510
    And the scanner system processes 0.05 seconds
    Then the scanner is idle
    When the test player moves to tile 500, 500
    And the scanner system processes 0.05 seconds
    Then the scanner is scanning "PTEST_PLANT_C"
    When the scanner system processes 2.5 seconds
    Then the catalog state of "PTEST_PLANT_C" is CATALOGED

  Scenario: Multi-prop proximity queue catalogs props one at a time deterministically
    Given a test plant "PTEST_PLANT_D1" placed at tile 500, 500
    And a test plant "PTEST_PLANT_D2" placed at tile 501, 500
    And the test player is standing on tile 500, 500
    When the scanner system processes 0.05 seconds
    Then the scanner is scanning "PTEST_PLANT_D1"
    When the scanner system processes 2.5 seconds
    Then the catalog state of "PTEST_PLANT_D1" is CATALOGED
    And the scanner is idle or has picked up the next target
    When the scanner system processes 0.05 seconds
    Then the scanner is scanning "PTEST_PLANT_D2"
    When the scanner system processes 2.5 seconds
    Then the catalog state of "PTEST_PLANT_D2" is CATALOGED
    And the scanner entry_cataloged signal fired for "PTEST_PLANT_D1"
    And the scanner entry_cataloged signal fired for "PTEST_PLANT_D2"
