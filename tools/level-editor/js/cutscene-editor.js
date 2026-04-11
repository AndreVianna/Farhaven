// ============================================================
// CutsceneEditor — Scaffolding stub (delivery-006c Wave 0)
// Real implementation lands in task-077.
// ============================================================

/**
 * Render the Cutscene editor into the given container.
 * Wave 0 placeholder — renders a friendly "Coming in task-077" notice
 * so the tab can be wired up without crashing the app.
 *
 * @param {HTMLElement} container - The tab panel element (e.g. #tab-cutscenes)
 * @param {Object} [_options] - Same shape as renderRecipeEditor / renderEventEditor
 *   (commandHistory, onChange, onSave). Ignored by the stub.
 * @returns {void}
 */
export function renderCutsceneEditor(container, _options) {
  if (!container) return;
  container.innerHTML = '';

  const wrap = document.createElement('div');
  wrap.style.padding = '24px';
  wrap.style.color = 'var(--text-secondary)';

  const h = document.createElement('h2');
  h.textContent = 'Cutscenes';
  h.style.marginTop = '0';
  wrap.appendChild(h);

  const p = document.createElement('p');
  p.textContent = 'Editor coming in task-077. This tab is scaffolding — '
    + 'CutsceneDef data class exists, but the master-detail UI '
    + '(metadata, video path, trigger event link) lands with task-077.';
  wrap.appendChild(p);

  container.appendChild(wrap);
}
