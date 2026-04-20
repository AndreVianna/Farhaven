/* ============================================================
 * Farhaven Editor — Tweaks panel (NH5)
 *
 * Floating runtime tweaks: accent color swap + density.
 * Applied via `data-accent` / `data-density` attrs on <body>;
 * tokens.css / shell.css react via attribute selectors.
 *
 * Toggled by a button in the titlebar right group. State persists
 * to localStorage so the user's preference sticks across reloads.
 * ============================================================ */

const STORAGE_KEY = 'farhaven-editor-tweaks-v1';
const DEFAULT = { accent: 'amber', density: 'comfortable' };

const ACCENTS = ['amber', 'blue', 'green', 'violet'];
const DENSITIES = ['comfortable', 'compact'];

function _load() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return { ...DEFAULT };
    const parsed = JSON.parse(raw);
    return { ...DEFAULT, ...parsed };
  } catch (_e) {
    return { ...DEFAULT };
  }
}

function _save(state) {
  try { localStorage.setItem(STORAGE_KEY, JSON.stringify(state)); } catch (_e) {}
}

/**
 * Apply the given tweak state to <body> attrs so CSS reacts.
 * @param {{accent: string, density: string}} state
 */
function _apply(state) {
  if (state.accent && state.accent !== 'amber') {
    document.body.setAttribute('data-accent', state.accent);
  } else {
    document.body.removeAttribute('data-accent');
  }
  if (state.density && state.density !== 'comfortable') {
    document.body.setAttribute('data-density', state.density);
  } else {
    document.body.removeAttribute('data-density');
  }
}

/** Public: apply persisted state on boot. */
export function applyPersistedTweaks() {
  _apply(_load());
}

let _panelOpen = null;

/**
 * Toggle the tweaks floating panel near the bottom-right corner.
 * @param {{getAccent: () => string}} [ctx]
 */
export function toggleTweaksPanel() {
  if (_panelOpen) {
    _panelOpen.remove();
    _panelOpen = null;
    document.removeEventListener('click', _outsideClick, true);
    return;
  }
  const state = _load();

  const panel = document.createElement('div');
  panel.className = 'tweaks';
  panel.innerHTML = `
    <div class="tweaks-head">Tweaks</div>
    <div class="tweaks-body">
      <div class="tweak-row">
        <div class="tweak-label">Accent</div>
        <div class="tweak-seg" id="tweak-accent"></div>
      </div>
      <div class="tweak-row">
        <div class="tweak-label">Density</div>
        <div class="tweak-seg" id="tweak-density"></div>
      </div>
    </div>
  `;

  const accentSeg = panel.querySelector('#tweak-accent');
  for (const a of ACCENTS) {
    const b = document.createElement('button');
    b.textContent = a;
    b.className = 'tweak-toggle' + (state.accent === a ? ' active' : '');
    b.addEventListener('click', (e) => {
      e.stopPropagation();
      state.accent = a;
      _save(state);
      _apply(state);
      for (const btn of accentSeg.children) btn.classList.toggle('active', btn.textContent === a);
    });
    accentSeg.appendChild(b);
  }

  const densitySeg = panel.querySelector('#tweak-density');
  for (const d of DENSITIES) {
    const b = document.createElement('button');
    b.textContent = d;
    b.className = 'tweak-toggle' + (state.density === d ? ' active' : '');
    b.addEventListener('click', (e) => {
      e.stopPropagation();
      state.density = d;
      _save(state);
      _apply(state);
      for (const btn of densitySeg.children) btn.classList.toggle('active', btn.textContent === d);
    });
    densitySeg.appendChild(b);
  }

  document.body.appendChild(panel);
  _panelOpen = panel;
  // Next tick so the open click doesn't immediately close.
  setTimeout(() => document.addEventListener('click', _outsideClick, true), 0);
}

function _outsideClick(e) {
  if (!_panelOpen) return;
  if (_panelOpen.contains(e.target)) return;
  _panelOpen.remove();
  _panelOpen = null;
  document.removeEventListener('click', _outsideClick, true);
}
