/* ============================================================
 * Farhaven Editor — Command Palette ⌘K
 *
 * Fuzzy-search overlay listing navigation routes + common actions +
 * every loaded entity (prop / biome / recipe / event / journal /
 * cutscene). Open with Ctrl/⌘+K or via the titlebar hint; dismiss
 * with Escape.
 *
 * Match scoring is a simple "all search terms appear as substrings
 * in any of the item's indexable strings" filter, weighted by
 * section priority (Navigation → Commands → Entities).
 * ============================================================ */

import { iconSvg } from './icons.js';
import { NAV } from './sidebar.js';
import { ProjectContext } from './file-discovery.js';

/**
 * @typedef {Object} PaletteItem
 * @property {string} id
 * @property {string} label
 * @property {string} section
 * @property {string} icon
 * @property {string} [sub]
 * @property {string} [kbd]
 * @property {() => void} action
 */

let _openOverlay = null;
let _cleanupHandlers = null;

/**
 * Build the full item list from app state + the external commands
 * map passed in by app.js. Called once per open so routes + counts
 * reflect the live project state.
 * @param {Object} ctx
 * @param {Object.<string, () => void>} ctx.commands - { 'save': fn, 'undo': fn, ... }
 * @param {(routeId: string) => void} ctx.onRoute
 * @returns {PaletteItem[]}
 */
function _buildItems(ctx) {
  const items = [];
  const commands = ctx.commands || {};

  // Navigation — every NAV route
  for (const n of NAV) {
    items.push({
      id: `nav:${n.id}`,
      label: n.label,
      section: 'Navigation',
      icon: n.icon,
      sub: n.section,
      action: () => ctx.onRoute(n.id),
    });
  }

  // Commands — bound actions passed in from app.js
  const CMD_DEFS = [
    { id: 'save', label: 'Save All', icon: 'save', kbd: 'Ctrl+S' },
    { id: 'undo', label: 'Undo', icon: 'undo', kbd: 'Ctrl+Z' },
    { id: 'redo', label: 'Redo', icon: 'redo', kbd: 'Ctrl+Shift+Z' },
    { id: 'newMap', label: 'New Map', icon: 'plus' },
    { id: 'generateMap', label: 'Generate Procedural Map', icon: 'map' },
    { id: 'populate', label: 'Populate Natural Props', icon: 'brush' },
    { id: 'clearProps', label: 'Clear Natural Props', icon: 'trash' },
    { id: 'help', label: 'Show Keyboard Shortcuts', icon: 'menu' },
  ];
  for (const c of CMD_DEFS) {
    if (!commands[c.id]) continue;
    items.push({
      id: `cmd:${c.id}`,
      label: c.label,
      section: 'Command',
      icon: c.icon,
      kbd: c.kbd,
      action: commands[c.id],
    });
  }

  // Entities — every prop / biome / recipe / event / journal / cutscene
  const entitySources = [
    { map: ProjectContext.files.props, kind: 'Prop', icon: 'tree', routeFromData: d => d && d.category ? d.category : 'plant' },
    { map: ProjectContext.files.biomes, kind: 'Biome', icon: 'brush', routeFromData: () => 'biomes' },
    { map: ProjectContext.files.recipes, kind: 'Recipe', icon: 'flask', routeFromData: () => 'recipes' },
    { map: ProjectContext.files.events, kind: 'Event', icon: 'bolt', routeFromData: () => 'events' },
    { map: ProjectContext.files.journal, kind: 'Journal', icon: 'book', routeFromData: () => 'journal' },
    { map: ProjectContext.files.cutscenes, kind: 'Cutscene', icon: 'film', routeFromData: () => 'cutscenes' },
  ];
  for (const src of entitySources) {
    for (const [filename, entry] of src.map) {
      const id = filename.replace(/\.(tres|json)$/i, '');
      const d = entry && entry.data;
      const name = (d && (d.display_name || d.name || d.id)) || id;
      items.push({
        id: `entity:${src.kind}:${id}`,
        label: name,
        section: src.kind + 's',
        icon: src.icon,
        sub: id,
        action: () => {
          const route = src.routeFromData(d);
          ctx.onRoute(route);
        },
      });
    }
  }

  // Maps
  for (const [filename, entry] of ProjectContext.files.maps) {
    const id = filename.replace(/\.json$/i, '');
    const d = entry && entry.data;
    const name = (d && (d.name || d.chapter_id)) || id;
    items.push({
      id: `entity:Map:${id}`,
      label: name,
      section: 'Maps',
      icon: 'map',
      sub: id,
      action: () => ctx.onRoute('map'),
    });
  }

  return items;
}

function _matches(item, query) {
  if (!query) return true;
  const terms = query.toLowerCase().split(/\s+/).filter(Boolean);
  const hay = (item.label + ' ' + item.section + ' ' + (item.sub || '')).toLowerCase();
  return terms.every(t => hay.includes(t));
}

/**
 * Open the command palette overlay. If already open, just focuses
 * the input.
 *
 * @param {Object} ctx
 * @param {Object.<string, () => void>} ctx.commands
 * @param {(routeId: string) => void} ctx.onRoute
 */
export function openCommandPalette(ctx) {
  if (_openOverlay) {
    const input = _openOverlay.querySelector('input');
    if (input) input.focus();
    return;
  }

  const items = _buildItems(ctx);
  let query = '';
  let activeIdx = 0;

  const overlay = document.createElement('div');
  overlay.className = 'cmdk-backdrop';
  const cmdk = document.createElement('div');
  cmdk.className = 'cmdk';

  // Input row
  const inputRow = document.createElement('div');
  inputRow.className = 'cmdk-input';
  inputRow.innerHTML = iconSvg('search', 14);
  const input = document.createElement('input');
  input.type = 'text';
  input.placeholder = 'Search commands, routes, entities…';
  inputRow.appendChild(input);
  const hintKbd = document.createElement('span');
  hintKbd.className = 'hint-kbd';
  hintKbd.textContent = 'ESC';
  inputRow.appendChild(hintKbd);
  cmdk.appendChild(inputRow);

  // List
  const list = document.createElement('div');
  list.className = 'cmdk-list';
  cmdk.appendChild(list);

  overlay.appendChild(cmdk);
  document.body.appendChild(overlay);
  _openOverlay = overlay;

  let filtered = items;

  function _renderList() {
    filtered = items.filter(it => _matches(it, query));
    activeIdx = Math.min(activeIdx, Math.max(0, filtered.length - 1));
    list.innerHTML = '';
    if (filtered.length === 0) {
      const empty = document.createElement('div');
      empty.className = 'cmdk-section';
      empty.textContent = 'No matches';
      list.appendChild(empty);
      return;
    }
    let lastSection = null;
    filtered.forEach((it, i) => {
      if (it.section !== lastSection) {
        lastSection = it.section;
        const sec = document.createElement('div');
        sec.className = 'cmdk-section';
        sec.textContent = it.section;
        list.appendChild(sec);
      }
      const el = document.createElement('div');
      el.className = 'cmdk-item' + (i === activeIdx ? ' active' : '');
      el.dataset.idx = String(i);
      el.innerHTML = `
        <span class="ci-icon">${iconSvg(it.icon, 14)}</span>
        <span class="ci-label">${_escape(it.label)}</span>
        ${it.sub ? `<span class="ci-sub">${_escape(it.sub)}</span>` : ''}
        ${it.kbd ? `<span class="ci-kbd">${_escape(it.kbd)}</span>` : ''}
      `;
      el.addEventListener('click', () => _runItem(it));
      el.addEventListener('mouseenter', () => { activeIdx = i; _refreshActive(); });
      list.appendChild(el);
    });
  }

  function _refreshActive() {
    list.querySelectorAll('.cmdk-item').forEach((el, i) => {
      el.classList.toggle('active', Number(el.dataset.idx) === activeIdx);
    });
  }

  function _runItem(it) {
    close();
    try { it.action(); } catch (e) { console.error('Command palette action failed:', e); }
  }

  function _keyHandler(e) {
    if (e.key === 'Escape') {
      e.preventDefault();
      close();
      return;
    }
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      if (filtered.length === 0) return;
      activeIdx = (activeIdx + 1) % filtered.length;
      _refreshActive();
      return;
    }
    if (e.key === 'ArrowUp') {
      e.preventDefault();
      if (filtered.length === 0) return;
      activeIdx = (activeIdx - 1 + filtered.length) % filtered.length;
      _refreshActive();
      return;
    }
    if (e.key === 'Enter') {
      e.preventDefault();
      const it = filtered[activeIdx];
      if (it) _runItem(it);
    }
  }

  input.addEventListener('input', () => { query = input.value; _renderList(); });
  input.addEventListener('keydown', _keyHandler);

  overlay.addEventListener('click', (e) => {
    if (e.target === overlay) close();
  });

  function close() {
    if (!_openOverlay) return;
    overlay.remove();
    _openOverlay = null;
    if (_cleanupHandlers) _cleanupHandlers();
    _cleanupHandlers = null;
  }

  _cleanupHandlers = () => {};

  _renderList();
  input.focus();
}

function _escape(s) {
  return String(s).replace(/[&<>"']/g, c =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}
