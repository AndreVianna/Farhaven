/* ============================================================
 * Farhaven Editor — Inline SVG icons
 * Ported from temp/Farhaven Editor/src/icons.jsx (Phase 2).
 * ============================================================ */

const PATHS = {
  cursor:   '<path d="M3 2l10 5.5-4.5 1.5L7 14 3 2z"/>',
  hand:     '<path d="M5 7V3.5a1 1 0 1 1 2 0V7"/><path d="M7 7V2.5a1 1 0 1 1 2 0V7"/><path d="M9 7V3.5a1 1 0 1 1 2 0V8"/><path d="M11 7.5V5.5a1 1 0 1 1 2 0v5c0 2.5-1.5 4-4 4s-4.5-1.5-5-3.5L2.5 8a1 1 0 0 1 1.6-1.1L5 8"/>',
  brush:    '<path d="M3 13c0-1.5 1.5-2 2.5-2s2 .5 2 2c0 1-1 1.5-2.5 1.5S3 14 3 13z"/><path d="M7.5 11l6-6a1.4 1.4 0 0 1 2 2l-6 6"/>',
  bucket:   '<path d="M3 6l5-3 5 3-5 3-5-3z"/><path d="M3 6v3l5 3 5-3V6"/><circle cx="12.5" cy="12" r="1.5"/>',
  mountain: '<path d="M2 13l4-7 3 4 2-2 3 5z"/>',
  tree:     '<path d="M8 2l4 5H9v3h4l-5 4-5-4h4V7H4z"/>',
  pin:      '<path d="M8 1.5c3 0 5 2 5 4.5 0 3.5-5 8.5-5 8.5S3 9.5 3 6c0-2.5 2-4.5 5-4.5z"/><circle cx="8" cy="6" r="1.5"/>',
  eraser:   '<path d="M3 11l5-5 4 4-5 5H5l-2-2v-2z"/><path d="M8 6l4 4"/><path d="M2 14h12"/>',
  trash:    '<path d="M3 4h10"/><path d="M5 4V2.5h6V4"/><path d="M4 4l1 10h6l1-10"/><path d="M7 7v5M9 7v5"/>',
  spark:    '<path d="M8 2v3M8 11v3M2 8h3M11 8h3M4.5 4.5l2 2M9.5 9.5l2 2M4.5 11.5l2-2M9.5 6.5l2-2"/>',
  map:      '<path d="M2 4l4-2 4 2 4-2v10l-4 2-4-2-4 2V4z"/><path d="M6 2v10M10 4v10"/>',
  layers:   '<path d="M8 2l6 3-6 3-6-3 6-3z"/><path d="M2 8l6 3 6-3"/><path d="M2 11l6 3 6-3"/>',
  grid:     '<rect x="2" y="2" width="5" height="5"/><rect x="9" y="2" width="5" height="5"/><rect x="2" y="9" width="5" height="5"/><rect x="9" y="9" width="5" height="5"/>',
  hex:      '<path d="M8 1.5l5.5 3v7L8 14.5 2.5 11.5v-7L8 1.5z"/>',
  eye:      '<path d="M1.5 8s2.5-4.5 6.5-4.5 6.5 4.5 6.5 4.5-2.5 4.5-6.5 4.5S1.5 8 1.5 8z"/><circle cx="8" cy="8" r="2"/>',
  'eye-off':'<path d="M2 8s2.5-4.5 6-4.5c1 0 2 .3 3 .7"/><path d="M14 8s-2.5 4.5-6 4.5c-1 0-2-.2-3-.7"/><path d="M2 2l12 12"/>',
  search:   '<circle cx="7" cy="7" r="4.5"/><path d="M10.5 10.5l3 3"/>',
  plus:     '<path d="M8 3v10M3 8h10"/>',
  minus:    '<path d="M3 8h10"/>',
  x:        '<path d="M4 4l8 8M12 4l-8 8"/>',
  chevron:  '<path d="M4 6l4 4 4-4"/>',
  'chev-r': '<path d="M6 4l4 4-4 4"/>',
  undo:     '<path d="M5 4L2 7l3 3"/><path d="M2 7h8a4 4 0 0 1 0 8H7"/>',
  redo:     '<path d="M11 4l3 3-3 3"/><path d="M14 7H6a4 4 0 0 0 0 8h3"/>',
  save:     '<path d="M2 3h9l3 3v8H2z"/><path d="M4 3v4h7V3"/><rect x="5" y="9" width="6" height="5"/>',
  'zoom-in':'<circle cx="7" cy="7" r="4.5"/><path d="M10.5 10.5l3 3M5 7h4M7 5v4"/>',
  'zoom-out':'<circle cx="7" cy="7" r="4.5"/><path d="M10.5 10.5l3 3M5 7h4"/>',
  target:   '<circle cx="8" cy="8" r="5"/><circle cx="8" cy="8" r="1.5"/><path d="M8 1v2M8 13v2M1 8h2M13 8h2"/>',
  book:     '<path d="M3 3h4a2 2 0 0 1 2 2v8a2 2 0 0 0-2-2H3V3z"/><path d="M13 3H9a2 2 0 0 0-2 2v8a2 2 0 0 1 2-2h4V3z"/>',
  flask:    '<path d="M6 2h4M6.5 2v4.5L3 13a1 1 0 0 0 .9 1.5h8.2a1 1 0 0 0 .9-1.5L9.5 6.5V2"/><path d="M5 10h6"/>',
  cube:     '<path d="M8 1.5l6 3v7L8 14.5l-6-3v-7l6-3z"/><path d="M2 4.5l6 3 6-3M8 7.5v7"/>',
  leaf:     '<path d="M3 13c0-6 4-10 11-10-1 8-4 11-11 11-.5-.5-1-1-1-1z"/><path d="M3 13l5-5"/>',
  rocks:    '<path d="M3 12l3-5 3 4-2 2H3z"/><path d="M7 13l3-5 4 5H7z"/>',
  drop:     '<path d="M8 2s4 5 4 8a4 4 0 0 1-8 0c0-3 4-8 4-8z"/>',
  house:    '<path d="M2 8l6-5 6 5v6H2V8z"/><path d="M6 14V9h4v5"/>',
  bug:      '<ellipse cx="8" cy="9" rx="3" ry="4"/><path d="M5 9H2M11 9h3M5 6l-2-2M11 6l2-2M8 5V2"/>',
  film:     '<rect x="2" y="3" width="12" height="10"/><path d="M2 5h12M2 11h12M5 3v10M11 3v10"/>',
  bolt:     '<path d="M8 1l-4 8h3l-1 6 5-8H8l1-6z" fill="currentColor" stroke="none"/>',
  gear:     '<circle cx="8" cy="8" r="2"/><path d="M8 1v2M8 13v2M1 8h2M13 8h2M3.5 3.5l1.5 1.5M11 11l1.5 1.5M3.5 12.5L5 11M11 5l1.5-1.5"/>',
  menu:     '<path d="M2 4h12M2 8h12M2 12h12"/>',
  download: '<path d="M8 2v8M4.5 6.5L8 10l3.5-3.5M2 13h12"/>',
  upload:   '<path d="M8 10V2M4.5 5.5L8 2l3.5 3.5M2 13h12"/>',
  dot:      '<circle cx="8" cy="8" r="2" fill="currentColor" stroke="none"/>',
  paw:      '<circle cx="4.5" cy="6" r="1.5"/><circle cx="8" cy="4" r="1.5"/><circle cx="11.5" cy="6" r="1.5"/><path d="M4 11c0-2 2-3 4-3s4 1 4 3c0 1.5-1.5 2.5-4 2.5S4 12.5 4 11z"/>',
  tool:     '<path d="M11 2a3 3 0 0 0-3 3c0 .4.1.7.2 1L3 11l2 2 5-5c.3.1.6.2 1 .2a3 3 0 0 0 3-3c0-.4-.1-.7-.2-1L12 6l-2-2 2-2c-.3-.1-.6 0-1 0z"/>',
  box:      '<path d="M2 5l6-3 6 3v8l-6 3-6-3V5z"/><path d="M2 5l6 3 6-3M8 8v7"/>',
  play:     '<path d="M4 3l9 5-9 5V3z" fill="currentColor" stroke="none"/>',
  git:      '<circle cx="5" cy="4" r="1.5"/><circle cx="5" cy="12" r="1.5"/><circle cx="12" cy="8" r="1.5"/><path d="M5 5.5v5M5 8h3a3 3 0 0 0 3-3"/>',
  'default':'<circle cx="8" cy="8" r="4"/>',
};

/**
 * Return an SVG string for the named icon.
 * @param {string} name - icon key (e.g. "map", "brush", "plus")
 * @param {number} [size=16] - pixel dimension
 * @param {string} [className=''] - optional CSS class(es)
 * @returns {string} SVG markup ready for innerHTML
 */
export function iconSvg(name, size = 16, className = '') {
  const body = PATHS[name] || PATHS['default'];
  const cls = className ? ` class="${className}"` : '';
  return `<svg${cls} width="${size}" height="${size}" viewBox="0 0 16 16" `
    + `fill="none" stroke="currentColor" stroke-width="1.35" `
    + `stroke-linecap="round" stroke-linejoin="round">${body}</svg>`;
}

/**
 * Set an element's innerHTML to the named icon's SVG.
 * Useful when you already have a container and want the icon inside.
 * @param {HTMLElement} el
 * @param {string} name
 * @param {number} [size=16]
 * @returns {HTMLElement} the same element
 */
export function mountIcon(el, name, size = 16) {
  el.innerHTML = iconSvg(name, size);
  return el;
}

export const ICONS_AVAILABLE = Object.keys(PATHS).filter(k => k !== 'default');
