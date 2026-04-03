# Unsaved Changes Protection

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-04-03 | New feature — protection against accidental data loss | Lola review |

## Source

- REQUIREMENTS.md §5 F14 (Unsaved Changes Protection), §9 AC8

## Description

Protection against accidental data loss. The editor tracks dirty state across all three tabs (map, resource, biome). When unsaved changes exist: a visual indicator (asterisk in tab title or dot on tab) is shown, and attempting to close/refresh the browser triggers a `beforeunload` warning. Saving clears the dirty state and the indicator.

## User Stories

- As Andre, I want to see which tabs have unsaved changes so that I know what needs saving
- As Andre, I want the browser to warn me before losing unsaved work so that accidental tab closes don't lose data

## Priority

Must

## Acceptance Criteria

- [ ] Given unsaved changes in the map tab, when the tab title is rendered, then an asterisk or visual indicator is visible
- [ ] Given unsaved changes in any tab, when attempting to close or refresh the browser, then a beforeunload warning dialog appears
- [ ] Given all changes saved, when the tab title is rendered, then no unsaved indicator is visible
- [ ] Given unsaved changes, when pressing Ctrl+S (save), then the dirty state clears and the indicator disappears

---

## Technical Specification

{Added by /aid-specify — do not fill during interview.}
