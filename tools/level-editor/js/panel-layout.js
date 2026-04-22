/* ============================================================
 * panel-layout.js — Collapsible panels + drag-resizable splitters
 *
 * Wires toggle chevrons + drag handles to the outer workspace
 * panels (left nav, right map sidebar). Persists widths and
 * collapsed state in localStorage so the layout survives refreshes.
 * ============================================================ */

const LS_KEY = 'farhaven-editor-layout-v1';

const DEFAULT_STATE = {
  collapsedLeft: false,
  collapsedRight: false,
  navWidth: null,       // width of left sidebar when expanded
  mapRightWidth: null,  // width of right map sidebar when expanded
};

function _loadState() {
  try {
    const raw = localStorage.getItem(LS_KEY);
    if (!raw) return { ...DEFAULT_STATE };
    return { ...DEFAULT_STATE, ...JSON.parse(raw) };
  } catch {
    return { ...DEFAULT_STATE };
  }
}

function _saveState(state) {
  try {
    localStorage.setItem(LS_KEY, JSON.stringify(state));
  } catch { /* ignore */ }
}

const CHEVRON_LEFT  = '<svg width="12" height="12" viewBox="0 0 12 12" fill="none"><path d="M7.5 2.5L4 6l3.5 3.5" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/></svg>';
const CHEVRON_RIGHT = '<svg width="12" height="12" viewBox="0 0 12 12" fill="none"><path d="M4.5 2.5L8 6l-3.5 3.5" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/></svg>';

/**
 * Build and return a drag-resizer handle element. The handle lives
 * between `panel` and the adjacent flex sibling.
 *
 * @param {HTMLElement} panel - the panel whose width changes on drag
 * @param {'left'|'right'} side - 'left' if panel is on the left of the handle, 'right' if on the right
 * @param {{min: number, max: number, onPersist: (w: number) => void}} opts
 */
function _makeResizer(panel, side, opts) {
  const handle = document.createElement('div');
  handle.className = 'panel-resizer';
  handle.setAttribute('role', 'separator');
  handle.setAttribute('aria-orientation', 'vertical');
  let dragging = false;
  let startX = 0;
  let startWidth = 0;
  handle.addEventListener('mousedown', (e) => {
    dragging = true;
    startX = e.clientX;
    startWidth = panel.getBoundingClientRect().width;
    document.body.style.cursor = 'ew-resize';
    document.body.style.userSelect = 'none';
    e.preventDefault();
  });
  document.addEventListener('mousemove', (e) => {
    if (!dragging) return;
    const dx = e.clientX - startX;
    const delta = side === 'left' ? dx : -dx;
    const next = Math.max(opts.min, Math.min(opts.max, startWidth + delta));
    panel.style.width = `${next}px`;
    panel.style.minWidth = `${next}px`;
    panel.style.flexBasis = `${next}px`;
  });
  document.addEventListener('mouseup', () => {
    if (!dragging) return;
    dragging = false;
    document.body.style.cursor = '';
    document.body.style.userSelect = '';
    opts.onPersist(Math.round(panel.getBoundingClientRect().width));
  });
  return handle;
}

/**
 * Mount a toggle chevron positioned on the outer edge of a
 * collapsible panel. The chevron stays visible even when collapsed
 * (see CSS) so the panel can always be reopened.
 */
function _mountToggle(panel, side, getCollapsed, setCollapsed) {
  const btn = document.createElement('button');
  btn.type = 'button';
  btn.className = `panel-toggle panel-toggle-${side}`;
  btn.title = side === 'left'
    ? 'Collapse/expand left nav (Ctrl+\\)'
    : 'Collapse/expand right sidebar (Ctrl+Shift+\\)';
  const render = () => {
    const c = getCollapsed();
    btn.innerHTML = (side === 'left')
      ? (c ? CHEVRON_RIGHT : CHEVRON_LEFT)
      : (c ? CHEVRON_LEFT : CHEVRON_RIGHT);
  };
  btn.addEventListener('click', () => {
    setCollapsed(!getCollapsed());
    render();
  });
  render();
  panel.appendChild(btn);
  return render;
}

function _isEditable(target) {
  return target instanceof Element
    && target.matches('input, textarea, select, [contenteditable]');
}

export function initPanelLayout() {
  const state = _loadState();

  // ---- Outer left nav ----
  const navEl = document.getElementById('sidebar-nav');
  let renderNavToggle = () => {};
  if (navEl) {
    const applyNavCollapsed = () => {
      navEl.classList.toggle('panel-collapsed', state.collapsedLeft);
    };
    const applyNavWidth = () => {
      if (state.navWidth && !state.collapsedLeft) {
        navEl.style.width = `${state.navWidth}px`;
        navEl.style.minWidth = `${state.navWidth}px`;
        navEl.style.flexBasis = `${state.navWidth}px`;
      }
    };
    applyNavCollapsed();
    applyNavWidth();
    renderNavToggle = _mountToggle(navEl, 'left',
      () => state.collapsedLeft,
      (v) => { state.collapsedLeft = v; applyNavCollapsed(); _saveState(state); });

    const tabContent = document.getElementById('tab-content');
    if (tabContent && navEl.nextElementSibling === tabContent) {
      const resizer = _makeResizer(navEl, 'left', {
        min: 180, max: 400,
        onPersist: (w) => { state.navWidth = w; _saveState(state); },
      });
      navEl.parentElement.insertBefore(resizer, tabContent);
    }
  }

  // ---- Right map sidebar (only mounted inside #tab-map) ----
  const mapRight = document.getElementById('sidebar');
  let renderRightToggle = () => {};
  if (mapRight) {
    const applyRightCollapsed = () => {
      mapRight.classList.toggle('panel-collapsed', state.collapsedRight);
    };
    const applyRightWidth = () => {
      if (state.mapRightWidth && !state.collapsedRight) {
        mapRight.style.width = `${state.mapRightWidth}px`;
        mapRight.style.minWidth = `${state.mapRightWidth}px`;
        mapRight.style.flexBasis = `${state.mapRightWidth}px`;
      }
    };
    applyRightCollapsed();
    applyRightWidth();
    renderRightToggle = _mountToggle(mapRight, 'right',
      () => state.collapsedRight,
      (v) => { state.collapsedRight = v; applyRightCollapsed(); _saveState(state); });

    const canvas = document.getElementById('hex-canvas');
    if (canvas && canvas.nextElementSibling === mapRight) {
      const resizer = _makeResizer(mapRight, 'right', {
        min: 240, max: 600,
        onPersist: (w) => { state.mapRightWidth = w; _saveState(state); },
      });
      mapRight.parentElement.insertBefore(resizer, mapRight);
    }
  }

  // ---- Keyboard shortcuts: Ctrl+\ left, Ctrl+Shift+\ right ----
  document.addEventListener('keydown', (e) => {
    if (!(e.ctrlKey || e.metaKey)) return;
    if (e.key !== '\\' && e.key !== '|') return;
    if (_isEditable(e.target)) return;
    e.preventDefault();
    if (e.shiftKey) {
      if (!mapRight) return;
      state.collapsedRight = !state.collapsedRight;
      mapRight.classList.toggle('panel-collapsed', state.collapsedRight);
      renderRightToggle();
    } else {
      if (!navEl) return;
      state.collapsedLeft = !state.collapsedLeft;
      navEl.classList.toggle('panel-collapsed', state.collapsedLeft);
      renderNavToggle();
    }
    _saveState(state);
  });
}
