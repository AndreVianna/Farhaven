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
 * @returns {string}
 */
export function hexClusterSvg(hexColor, size = 120) {
  const r = size * 0.16;
  const cx = size / 2;
  const cy = size / 2;
  // Flat-top hex neighbors, 60° increments.
  const deltas = [];
  for (let i = 0; i < 6; i++) {
    const a = (Math.PI / 3) * i;
    deltas.push([Math.cos(a) * r * Math.sqrt(3), Math.sin(a) * r * Math.sqrt(3)]);
  }
  const shades = [-0.1, 0.05, -0.05, 0.1, -0.08, 0.08];
  let body = '';
  body += _hex(cx, cy, r, hexColor);
  deltas.forEach(([dx, dy], i) => {
    body += _hex(cx + dx, cy + dy, r, _shift(hexColor, shades[i % shades.length]));
  });
  return `<svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">${body}</svg>`;
}

function _hex(cx, cy, r, fill) {
  const pts = [];
  for (let i = 0; i < 6; i++) {
    const a = (Math.PI / 3) * i;
    pts.push(`${(cx + r * Math.cos(a)).toFixed(2)},${(cy + r * Math.sin(a)).toFixed(2)}`);
  }
  return `<polygon points="${pts.join(' ')}" fill="${fill}" stroke="rgba(0,0,0,0.25)" stroke-width="0.5"/>`;
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
