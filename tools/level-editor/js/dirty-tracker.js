// ============================================================
// DirtyTracker (task-005)
// ============================================================

export class DirtyTracker {
  constructor() {
    /** @type {Set<string>} */
    this.dirtyTabs = new Set();
    /** @type {function():void|null} */
    this.onChange = null;
  }

  /**
   * Mark a tab as dirty.
   * @param {string} tab - 'map' | 'resources' | 'biomes'
   * @returns {void}
   */
  markDirty(tab) {
    if (!this.dirtyTabs.has(tab)) {
      this.dirtyTabs.add(tab);
      if (this.onChange) this.onChange();
    }
  }

  /**
   * Clear dirty flag for a tab.
   * @param {string} tab
   * @returns {void}
   */
  markClean(tab) {
    if (this.dirtyTabs.has(tab)) {
      this.dirtyTabs.delete(tab);
      if (this.onChange) this.onChange();
    }
  }

  /**
   * Clear all dirty flags.
   * @returns {void}
   */
  markAllClean() {
    if (this.dirtyTabs.size > 0) {
      this.dirtyTabs.clear();
      if (this.onChange) this.onChange();
    }
  }

  /**
   * @param {string} tab
   * @returns {boolean}
   */
  isDirty(tab) {
    return this.dirtyTabs.has(tab);
  }

  /**
   * @returns {boolean}
   */
  hasUnsavedChanges() {
    return this.dirtyTabs.size > 0;
  }
}
