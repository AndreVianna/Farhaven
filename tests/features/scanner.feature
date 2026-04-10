Feature: Scanner
  The scanner auto-scans nearby props, building catalog knowledge.

  Scenario: Scan starts on proximity to uncataloged prop
    Given an uncataloged prop "P00001" on a neighboring tile
    When the player enters scan range
    Then a scan is in progress for "P00001"

  Scenario: Scan completes after duration and catalogs the prop
    Given a scan in progress for "P00001" with duration 2.0
    When 2.0 seconds elapse
    Then the scan completes
    And catalog entry "P00001" is CATALOGED

  Scenario: Scan interrupts and resets on move out of range
    Given a scan in progress for "P00001"
    When the player moves out of scan range
    Then the scan is interrupted
    And the scan progress is 0
