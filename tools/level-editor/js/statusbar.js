/* ============================================================
 * Farhaven Editor — Status bar enhancements (NH2)
 *
 * Replaces the minimal status-text span with a structured sb-group
 * layout matching the prototype: dirty indicator · route · chapter ·
 * encoding · accent+density.
 *
 * The existing status-text + tool-indicator IDs remain inside the new
 * structure so setStatus() and tool-change handlers continue to work.
 * ============================================================ */

import { iconSvg } from './icons.js';

/**
 * Mount extended status bar content into container.
 *
 * @param {HTMLElement} container - <footer class="statusbar">
 * @param {Object} opts
 * @param {() => string} opts.route       - current route id
 * @param {() => boolean} opts.isDirty    - any dirty tabs?
 * @param {() => string} [opts.chapter]   - chapter / map id, e.g. "ch1"
 * @param {() => string} [opts.accent]    - 'amber' | 'blue' | 'green' | 'violet'
 * @param {() => string} [opts.density]   - 'comfortable' | 'compact'
 * @returns {{refresh: () => void}}
 */
export function mountStatusbar(container, opts) {
  container.innerHTML = '';
  container.classList.add('statusbar');

  const left = document.createElement('div');
  left.className = 'sb-group';

  const dot = document.createElement('span');
  dot.className = 'sb-dot';
  left.appendChild(dot);

  const statusText = document.createElement('span');
  statusText.id = 'status-text';
  statusText.className = 'sb-item strong';
  statusText.textContent = 'Ready';
  left.appendChild(statusText);

  // Existing callers mutate #tool-indicator — keep it adjacent to the
  // status text so nothing breaks while the map tab rewires.
  const toolIndicator = document.createElement('span');
  toolIndicator.id = 'tool-indicator';
  toolIndicator.className = 'sb-item';
  left.appendChild(toolIndicator);

  container.appendChild(left);

  const right = document.createElement('div');
  right.className = 'sb-group';

  const routeEl = _sbItem('route', '—');
  const chapterEl = _sbItem('chapter', opts.chapter ? opts.chapter() : 'ch1');
  const encodingEl = _sbItem('utf', 'LF · UTF-8');
  const accentEl = _sbItem('', '');
  const densityEl = _sbItem('', '');

  right.appendChild(routeEl.wrap);
  right.appendChild(chapterEl.wrap);
  right.appendChild(encodingEl.wrap);
  right.appendChild(accentEl.wrap);
  right.appendChild(densityEl.wrap);

  container.appendChild(right);

  function refresh() {
    const dirty = opts.isDirty && opts.isDirty();
    dot.classList.toggle('dirty', !!dirty);
    routeEl.val.textContent = opts.route ? opts.route() : '—';
    chapterEl.val.textContent = opts.chapter ? opts.chapter() : 'ch1';
    if (opts.accent) accentEl.val.textContent = 'accent:' + opts.accent();
    if (opts.density) densityEl.val.textContent = opts.density();
  }

  refresh();
  return { refresh };
}

function _sbItem(label, value) {
  const wrap = document.createElement('span');
  wrap.className = 'sb-item';
  const lbl = document.createElement('span');
  lbl.className = 'label';
  lbl.textContent = label || '';
  if (label) wrap.appendChild(lbl);
  const val = document.createElement('span');
  val.className = 'value';
  val.textContent = value || '';
  wrap.appendChild(val);
  return { wrap, val };
}
