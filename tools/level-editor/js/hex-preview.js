/* ============================================================
 * Farhaven Editor — Hex Preview widget (NH3)
 *
 * 7-hex SVG cluster that shows a biome's color at several simulated
 * brightness steps. Used inside the biome-editor detail-preview
 * column ("how does this color look tiled next to itself").
 * ============================================================ */

/**
 * Return a SVG string of a 7-hex rosette centered on the biome color.
 * Surrounding cells shift brightness ±15% to hint at the render-time
 * variation the game applies.
 *
 * @param {string} hexColor - '#rrggbb' or CSS color
 * @param {number} [size=120] - outer px size
 * @param {string[]} [textureUrls] - optional list of texture URLs;
 *   when provided, each hex is filled with a rotating texture pattern
 *   instead of a flat color. Indexed by `[centerTex, n1, n2, n3, n4, n5, n6]`
 *   up to the length of the array (wraps).
 * @returns {string}
 */
export function hexClusterSvg(hexColor, size = 120, textureUrls = null) {
  const r = size * 0.18;
  const cx = size / 2;
  const cy = size / 2;
  // For flat-top hexes (vertices at 0/60/120°...), neighbors sit
  // perpendicular to each edge — i.e. offset by 30°. Distance between
  // centers of edge-sharing flat-top hexes is r * sqrt(3).
  const deltas = [];
  const centerDist = r * Math.sqrt(3);
  for (let i = 0; i < 6; i++) {
    const a = (Math.PI / 3) * i + Math.PI / 6;
    deltas.push([Math.cos(a) * centerDist, Math.sin(a) * centerDist]);
  }
  const shades = [-0.1, 0.05, -0.05, 0.1, -0.08, 0.08];
  let defs = '';
  let body = '';
  const useTex = Array.isArray(textureUrls) && textureUrls.length > 0;

  if (useTex) {
    // One pattern per hex (7 total) so each cell can rotate / tile
    // its own texture; visually mirrors what the runtime does.
    const patternSize = r * 2;
    textureUrls.slice(0, 7).forEach((url, i) => {
      defs += `<pattern id="tex${i}" patternUnits="userSpaceOnUse" width="${patternSize}" height="${patternSize}"><image href="${_escAttr(url)}" x="0" y="0" width="${patternSize}" height="${patternSize}" preserveAspectRatio="xMidYMid slice"/></pattern>`;
    });
  }

  const centerFill = useTex ? 'url(#tex0)' : hexColor;
  body += _hex(cx, cy, r, centerFill);
  deltas.forEach(([dx, dy], i) => {
    let fill;
    if (useTex) {
      const idx = (i + 1) % Math.min(7, textureUrls.length);
      fill = `url(#tex${idx})`;
    } else {
      fill = _shift(hexColor, shades[i % shades.length]);
    }
    body += _hex(cx + dx, cy + dy, r, fill);
  });
  return `<svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">${defs ? `<defs>${defs}</defs>` : ''}${body}</svg>`;
}

function _hex(cx, cy, r, fill) {
  const pts = [];
  for (let i = 0; i < 6; i++) {
    const a = (Math.PI / 3) * i;
    pts.push(`${(cx + r * Math.cos(a)).toFixed(2)},${(cy + r * Math.sin(a)).toFixed(2)}`);
  }
  return `<polygon points="${pts.join(' ')}" fill="${fill}" stroke="rgba(0,0,0,0.25)" stroke-width="0.5"/>`;
}

function _escAttr(s) {
  return String(s).replace(/[&<>"']/g, c =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function _shift(hex, pct) {
  // Parse #rrggbb or rgb(r,g,b) into [r,g,b]
  let r = 0, g = 0, b = 0;
  const m = /^#?([0-9a-f]{6})$/i.exec(hex);
  if (m) {
    r = parseInt(m[1].slice(0, 2), 16);
    g = parseInt(m[1].slice(2, 4), 16);
    b = parseInt(m[1].slice(4, 6), 16);
  } else {
    const m2 = /rgb\((\d+),\s*(\d+),\s*(\d+)\)/.exec(hex);
    if (m2) { r = +m2[1]; g = +m2[2]; b = +m2[3]; }
  }
  const clamp = v => Math.max(0, Math.min(255, Math.round(v)));
  const factor = 1 + pct;
  return `rgb(${clamp(r * factor)},${clamp(g * factor)},${clamp(b * factor)})`;
}
