/* ============================================================
 * Farhaven Editor — Titlebar (Phase 2)
 *
 * Top bar with logo, classical menubar (File / Edit / View /
 * Tools / Run / Help), breadcrumb middle section, and right
 * group (Command ⌘K hint, Undo, Redo, Save, Playtest).
 *
 * All map actions (New / Gen / Populate / Clear / Save / Save As /
 * Del) live inside menu dropdowns instead of scattered buttons.
 * ============================================================ */

import { iconSvg } from './icons.js';

/**
 * @typedef {Object} MenuItem
 * @property {string} [label]        - displayed text; if absent + separator:true, renders hr
 * @property {string} [kbd]          - optional shortcut hint
 * @property {boolean} [separator]   - renders as horizontal divider
 * @property {boolean} [danger]      - red-tint on hover
 * @property {() => void} [action]   - click handler (no-op if absent)
 * @property {() => boolean} [disabled] - returns true if item should be disabled
 */

/**
 * @typedef {Object} MenuDef
 * @property {string} label
 * @property {MenuItem[]} items
 */

/**
 * Mount the titlebar into `container` (should be the top `<header
 * class="titlebar">` element). Returns a handle with refresh() to
 * re-evaluate button state + setBreadcrumb() to update the middle.
 *
 * @param {HTMLElement} container
 * @param {Object} options
 * @param {MenuDef[]} options.menus   - menu definitions (File, Edit, …)
 * @param {() => void} [options.onCommandPalette] - ⌘K click handler
 * @param {() => void} [options.onUndo]
 * @param {() => void} [options.onRedo]
 * @param {() => void} [options.onSave]
 * @param {() => void} [options.onPlaytest]
 * @param {() => boolean} [options.isDirty] - returns true when Save should be primary
 */
export function mountTitlebar(container, options) {
  container.innerHTML = '';
  container.classList.add('titlebar');

  // Brand: amber logo + name + sep + mode
  const brand = document.createElement('div');
  brand.className = 'brand';
  brand.innerHTML = `
    <div class="logo"></div>
    <span>FARHAVEN</span>
    <span class="sep">·</span>
    <span class="mode">Editor</span>
  `;
  container.appendChild(brand);

  // Menubar
  const menubar = document.createElement('div');
  menubar.className = 'titlebar-menu';
  container.appendChild(menubar);

  /** @type {HTMLElement|null} */
  let openDropdown = null;
  /** @type {HTMLButtonElement|null} */
  let openButton = null;

  const closeDropdown = () => {
    if (openDropdown) openDropdown.remove();
    if (openButton) openButton.classList.remove('open');
    openDropdown = null;
    openButton = null;
    document.removeEventListener('click', _outsideClick, true);
  };

  const _outsideClick = (e) => {
    if (!openDropdown) return;
    if (menubar.contains(e.target)) return;
    closeDropdown();
  };

  for (const menu of options.menus) {
    const btn = document.createElement('button');
    btn.textContent = menu.label;
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      if (openButton === btn) {
        closeDropdown();
        return;
      }
      closeDropdown();
      _renderDropdown(btn, menu);
    });
    btn.addEventListener('mouseenter', () => {
      if (openDropdown && openButton !== btn) {
        closeDropdown();
        _renderDropdown(btn, menu);
      }
    });
    menubar.appendChild(btn);
  }

  function _renderDropdown(btn, menu) {
    btn.classList.add('open');
    openButton = btn;
    const dd = document.createElement('div');
    dd.className = 'titlebar-dropdown';
    dd.style.left = `${btn.offsetLeft}px`;
    for (const item of menu.items) {
      if (item.separator) {
        const sep = document.createElement('div');
        sep.className = 'separator';
        dd.appendChild(sep);
        continue;
      }
      const entry = document.createElement('button');
      if (item.danger) entry.classList.add('danger');
      const disabled = item.disabled ? !!item.disabled() : false;
      entry.disabled = disabled;

      const lbl = document.createElement('span');
      lbl.textContent = item.label || '';
      entry.appendChild(lbl);
      if (item.kbd) {
        const kbd = document.createElement('span');
        kbd.className = 'kbd';
        kbd.textContent = item.kbd;
        entry.appendChild(kbd);
      }
      entry.addEventListener('click', () => {
        closeDropdown();
        if (!disabled && item.action) item.action();
      });
      dd.appendChild(entry);
    }
    menubar.appendChild(dd);
    openDropdown = dd;
    document.addEventListener('click', _outsideClick, true);
  }

  // Spacer pushes right-group to the far right
  const spacer = document.createElement('div');
  spacer.className = 'titlebar-spacer';
  container.appendChild(spacer);

  // Breadcrumb (chapter · route · …) — lives between menubar and right group
  const breadcrumb = document.createElement('div');
  breadcrumb.className = 'titlebar-breadcrumb';
  breadcrumb.style.cssText = 'color:var(--text-2);font-family:var(--font-mono);font-size:10.5px;margin-right:auto;';
  container.appendChild(breadcrumb);

  const rightSpacer = document.createElement('div');
  rightSpacer.className = 'titlebar-spacer';
  container.appendChild(rightSpacer);

  // Right group
  const right = document.createElement('div');
  right.className = 'titlebar-right';

  // Command palette hint (⌘K)
  if (options.onCommandPalette) {
    const cmdk = document.createElement('div');
    cmdk.className = 'cmdk-hint';
    cmdk.innerHTML = `${iconSvg('search', 12)}<span>Command</span><kbd>⌘K</kbd>`;
    cmdk.addEventListener('click', options.onCommandPalette);
    right.appendChild(cmdk);
  }

  // Undo button
  const btnUndo = document.createElement('button');
  btnUndo.className = 'icon-btn';
  btnUndo.title = 'Undo (Ctrl+Z)';
  btnUndo.innerHTML = iconSvg('undo', 14);
  if (options.onUndo) btnUndo.addEventListener('click', options.onUndo);
  right.appendChild(btnUndo);

  // Redo button
  const btnRedo = document.createElement('button');
  btnRedo.className = 'icon-btn';
  btnRedo.title = 'Redo (Ctrl+Shift+Z)';
  btnRedo.innerHTML = iconSvg('redo', 14);
  if (options.onRedo) btnRedo.addEventListener('click', options.onRedo);
  right.appendChild(btnRedo);

  // Save button
  const btnSave = document.createElement('button');
  btnSave.className = 'btn';
  btnSave.innerHTML = `${iconSvg('save', 12)}<span>Save</span>`;
  btnSave.title = 'Save All (Ctrl+S)';
  if (options.onSave) btnSave.addEventListener('click', options.onSave);
  right.appendChild(btnSave);

  // Playtest button
  if (options.onPlaytest) {
    const btnPlay = document.createElement('button');
    btnPlay.className = 'btn primary';
    btnPlay.innerHTML = `${iconSvg('play', 12)}<span>Playtest</span>`;
    btnPlay.title = 'Launch Godot';
    btnPlay.addEventListener('click', options.onPlaytest);
    right.appendChild(btnPlay);
  }

  container.appendChild(right);

  function refresh() {
    if (options.isDirty) {
      btnSave.classList.toggle('dirty', options.isDirty());
    }
  }

  function setBreadcrumb(text) {
    breadcrumb.textContent = text || '';
  }

  refresh();

  return { refresh, setBreadcrumb, closeDropdown };
}
