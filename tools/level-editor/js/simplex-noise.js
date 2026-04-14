// ============================================================
// simplex-noise.js — 2D Simplex noise with domain warping
// ============================================================
//
// Seeded 2D Simplex noise with fractal (fBm) and domain warp support.
// Based on the algorithm by Ken Perlin / Stefan Gustavson.

'use strict';

const GRAD2 = [
  [1, 1], [-1, 1], [1, -1], [-1, -1],
  [1, 0], [-1, 0], [0, 1], [0, -1],
  [1, 1], [-1, 1], [1, -1], [-1, -1],
];

/**
 * Create a seeded 2D Simplex noise function.
 * @param {number} seed - Integer seed for reproducibility
 */
export function createNoise2D(seed) {
  const perm = new Uint8Array(512);
  const base = new Uint8Array(256);
  for (let i = 0; i < 256; i++) base[i] = i;

  let s = seed >>> 0;
  for (let i = 255; i > 0; i--) {
    s ^= s << 13; s ^= s >>> 17; s ^= s << 5;
    const j = (s >>> 0) % (i + 1);
    const tmp = base[i]; base[i] = base[j]; base[j] = tmp;
  }
  for (let i = 0; i < 512; i++) perm[i] = base[i & 255];

  const F2 = 0.5 * (Math.sqrt(3) - 1);
  const G2 = (3 - Math.sqrt(3)) / 6;

  function noise2D(x, y) {
    const s = (x + y) * F2;
    const i = Math.floor(x + s);
    const j = Math.floor(y + s);
    const t = (i + j) * G2;
    const x0 = x - (i - t);
    const y0 = y - (j - t);
    let i1, j1;
    if (x0 > y0) { i1 = 1; j1 = 0; } else { i1 = 0; j1 = 1; }
    const x1 = x0 - i1 + G2, y1 = y0 - j1 + G2;
    const x2 = x0 - 1 + 2 * G2, y2 = y0 - 1 + 2 * G2;
    const ii = i & 255, jj = j & 255;
    let n0 = 0, n1 = 0, n2 = 0;
    let t0 = 0.5 - x0 * x0 - y0 * y0;
    if (t0 >= 0) { t0 *= t0; const g = GRAD2[perm[ii + perm[jj]] % 12]; n0 = t0 * t0 * (g[0] * x0 + g[1] * y0); }
    let t1 = 0.5 - x1 * x1 - y1 * y1;
    if (t1 >= 0) { t1 *= t1; const g = GRAD2[perm[ii + i1 + perm[jj + j1]] % 12]; n1 = t1 * t1 * (g[0] * x1 + g[1] * y1); }
    let t2 = 0.5 - x2 * x2 - y2 * y2;
    if (t2 >= 0) { t2 *= t2; const g = GRAD2[perm[ii + 1 + perm[jj + 1]] % 12]; n2 = t2 * t2 * (g[0] * x2 + g[1] * y2); }
    return 70.0 * (n0 + n1 + n2);
  }

  /**
   * Fractal Brownian Motion — layered noise for natural terrain.
   * @param {number} x
   * @param {number} y
   * @param {number} [octaves=4]
   * @param {number} [lacunarity=2.0]
   * @param {number} [gain=0.5]
   * @returns {number} Value roughly in [-1, 1]
   */
  function fractal2D(x, y, octaves = 4, lacunarity = 2.0, gain = 0.5) {
    let sum = 0, amp = 1, freq = 1, maxAmp = 0;
    for (let o = 0; o < octaves; o++) {
      sum += amp * noise2D(x * freq, y * freq);
      maxAmp += amp;
      amp *= gain;
      freq *= lacunarity;
    }
    return sum / maxAmp;
  }

  /**
   * Domain-warped fBm (Inigo Quilez technique).
   * Evaluates fbm(p + warpStrength * fbm(p + offset)).
   * Produces organic, tectonic-looking terrain features.
   * @param {number} x
   * @param {number} y
   * @param {number} [octaves=4]
   * @param {number} [warpStrength=0.4]
   * @returns {number}
   */
  function warpedFbm(x, y, octaves = 4, warpStrength = 0.4) {
    const qx = fractal2D(x + 0.0, y + 0.0, octaves);
    const qy = fractal2D(x + 5.2, y + 1.3, octaves);
    return fractal2D(x + warpStrength * qx, y + warpStrength * qy, octaves);
  }

  return { noise2D, fractal2D, warpedFbm };
}
