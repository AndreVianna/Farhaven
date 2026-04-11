// ============================================================
// JournalEditor — Scaffolding stub (delivery-006c Wave 0)
// Real implementation lands in task-076.
// ============================================================

/**
 * Render the Journal Entry editor into the given container.
 * Wave 0 placeholder — renders a friendly "Coming in task-076" notice
 * so the tab can be wired up without crashing the app.
 *
 * @param {HTMLElement} container - The tab panel element (e.g. #tab-journal)
 * @param {Object} [_options] - Same shape as renderRecipeEditor / renderEventEditor
 *   (commandHistory, onChange, onSave). Ignored by the stub.
 * @returns {void}
 */
export function renderJournalEditor(container, _options) {
  if (!container) return;
  container.innerHTML = '';

  const wrap = document.createElement('div');
  wrap.style.padding = '24px';
  wrap.style.color = 'var(--text-secondary)';

  const h = document.createElement('h2');
  h.textContent = 'Journal Entries';
  h.style.marginTop = '0';
  wrap.appendChild(h);

  const p = document.createElement('p');
  p.textContent = 'Editor coming in task-076. This tab is scaffolding — '
    + 'JournalEntry data class and Journal autoload exist, but the master-detail UI '
    + 'lands with task-076.';
  wrap.appendChild(p);

  container.appendChild(wrap);
}
