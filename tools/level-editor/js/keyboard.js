// ============================================================
// KeyboardManager (task-004)
// ============================================================

export class KeyboardManager {
  constructor() {
    /** @type {Map<string, function():void>} */
    this.shortcuts = new Map();
    /** @type {boolean} */
    this.enabled = true;

    document.addEventListener('keydown', (e) => this._handleKeydown(e));
  }

  /**
   * Register a shortcut.
   * @param {string} combo - e.g. 'ctrl+z', 'b', 'escape'
   * @param {function():void} handler
   * @returns {void}
   */
  register(combo, handler) {
    this.shortcuts.set(combo.toLowerCase(), handler);
  }

  /**
   * Unregister a shortcut.
   * @param {string} combo
   * @returns {void}
   */
  unregister(combo) {
    this.shortcuts.delete(combo.toLowerCase());
  }

  /**
   * Normalize a KeyboardEvent to a combo string.
   * Modifier order: ctrl+shift+alt+key (lowercase).
   * @param {KeyboardEvent} event
   * @returns {string}
   */
  _normalizeEvent(event) {
    const parts = [];
    if (event.ctrlKey || event.metaKey) parts.push('ctrl');
    if (event.shiftKey) parts.push('shift');
    if (event.altKey) parts.push('alt');
    const key = event.key.toLowerCase();
    // Avoid duplicating modifier names as the key itself
    if (key !== 'control' && key !== 'shift' && key !== 'alt' && key !== 'meta') {
      parts.push(key);
    }
    return parts.join('+');
  }

  /**
   * Handle keydown events. Dispatch matching shortcuts.
   * @param {KeyboardEvent} event
   * @returns {void}
   */
  _handleKeydown(event) {
    if (!this.enabled) return;

    const combo = this._normalizeEvent(event);
    const handler = this.shortcuts.get(combo);
    if (!handler) return;

    // Check if a text input is focused — suppress single-key shortcuts
    const el = document.activeElement;
    const isTextInput = el && (
      el.tagName === 'INPUT' ||
      el.tagName === 'TEXTAREA' ||
      el.hasAttribute('contenteditable')
    );

    // Single-key shortcuts (no modifier) should be suppressed in text inputs
    const hasModifier = event.ctrlKey || event.metaKey || event.altKey;
    if (isTextInput && !hasModifier) return;

    event.preventDefault();
    handler();
  }
}
