# task-001: App Shell HTML Skeleton and Tab Switching

**Type:** IMPLEMENT

**Source:** feature-007-file-discovery -> delivery-001

**Depends on:** -- (none)

**Scope:**
- Create `tools/level-editor/index.html` with the full HTML skeleton: `#app`, `#toolbar`, `#tabs` (Map Editor, Resources, Biomes), `#tab-content` with three tab panels, `#welcome` overlay, `#hex-tooltip`
- Implement CSS styles for the app layout: dark theme, tab buttons, toolbar, sidebar placeholder, full-viewport layout
- Implement tab switching logic: click tab button -> hide all `.tab-panel`, show target, update `active` class
- Implement the `activeTab` module-level variable updated by tab switching (needed by feature-008 for shortcut scoping)
- Welcome overlay visible on load, editor workspace hidden until project is opened

**Acceptance Criteria:**
- [ ] `tools/level-editor/index.html` exists as a single HTML file with embedded CSS and JS
- [ ] Three tabs render and clicking each switches the visible panel
- [ ] Welcome overlay is visible on initial load; editor workspace is hidden
- [ ] `activeTab` variable correctly tracks which tab is active
- [ ] No external dependencies (zero imports, zero build step)
- [ ] File opens correctly via `file://` protocol in Chrome
- [ ] All code uses strict mode and follows project conventions (static-like typing via JSDoc where applicable)
