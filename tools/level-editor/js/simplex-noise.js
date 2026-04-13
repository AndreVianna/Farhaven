// ============================================================
// simplex-noise.js — 2D Simplex noise for procedural generation
// ============================================================
//
// Seeded 2D Simplex noise with fractal (fBm) support.
// Based on the algorithm by Ken Perlin / Stefan Gustavson.

'use strict';

// Gradients for 2D Simplex noise (12 directions)
const GRAD2 = [
  [1, 1], [-1, 1], [1, -1], [-1, -1],
  [1, 0], [-1, 0], [0, 1], [0, -1],
  [1, 1], [-1, 1], [1, -1], [-1, -1],
];

/**
 * Create a seeded 2D Simplex noise function.
 * @param {number} seed - Integer seed for reproducibility
 * @returns {{ noise2D: (x: number, y: number) => number, fractal2D: (x: number, y: number, octaves: number, lacunarity: number, gain: number) => number }}
 */
export function createNoise2D(seed) {
  // Build a seeded permutation table
  const perm = new Uint8Array(512);
  const base = new Uint8Array(256);
  for (let i = 0; i < 256; i++) base[i] = i;

  // Fisher-Yates shuffle with a simple seeded PRNG
  let s = seed >>> 0;
  for (let i = 255; i > 0; i--) {
    // xorshift32
    s ^= s << 13;
    s ^= s >>> 17;
    s ^= s << 5;
    const j = (s >>> 0) % (i + 1);
    const tmp = base[i];
    base[i] = base[j];
    base[j] = tmp;
  }
  for (let i = 0; i < 512; i++) perm[i] = base[i & 255];

  const F2 = 0.5 * (Math.sqrt(3) - 1);
  const G2 = (3 - Math.sqrt(3)) / 6;

  function noise2D(x, y) {
    const s = (x + y) * F2;
    const i = Math.floor(x + s);
    const j = Math.floor(y + s);
    const t = (i + j) * G2;

    const X0 = i - t;
    const Y0 = j - t;
    const x0 = x - X0;
    const y0 = y - Y0;

    let i1, j1;
    if (x0 > y0) { i1 = 1; j1 = 0; }
    else { i1 = 0; j1 = 1; }

    const x1 = x0 - i1 + G2;
    const y1 = y0 - j1 + G2;
    const x2 = x0 - 1.0 + 2.0 * G2;
    const y2 = y0 - 1.0 + 2.0 * G2;

    const ii = i & 255;
    const jj = j & 255;

    let n0 = 0, n1 = 0, n2 = 0;

    let t0 = 0.5 - x0 * x0 - y0 * y0;
    if (t0 >= 0) {
      t0 *= t0;
      const g = GRAD2[perm[ii + perm[jj]] % 12];
      n0 = t0 * t0 * (g[0] * x0 + g[1] * y0);
    }

    let t1 = 0.5 - x1 * x1 - y1 * y1;
    if (t1 >= 0) {
      t1 *= t1;
      const g = GRAD2[perm[ii + i1 + perm[jj + j1]] % 12];
      n1 = t1 * t1 * (g[0] * x1 + g[1] * y1);
    }

    let t2 = 0.5 - x2 * x2 - y2 * y2;
    if (t2 >= 0) {
      t2 *= t2;
      const g = GRAD2[perm[ii + 1 + perm[jj + 1]] % 12];
      n2 = t2 * t2 * (g[0] * x2 + g[1] * y2);
    }

    // Scale to [-1, 1]
    return 70.0 * (n0 + n1 + n2);
  }

  /**
   * Fractal Brownian Motion — layered noise for natural terrain.
   * @param {number} x
   * @param {number} y
   * @param {number} octaves - Number of noise layers (1-8)
   * @param {number} lacunarity - Frequency multiplier per octave (typically 2.0)
   * @param {number} gain - Amplitude multiplier per octave (typically 0.5)
   * @returns {number} Value roughly in [-1, 1]
   */
  function fractal2D(x, y, octaves = 4, lacunarity = 2.0, gain = 0.5) {
    let sum = 0;
    let amp = 1.0;
    let freq = 1.0;
    let maxAmp = 0;
    for (let o = 0; o < octaves; o++) {
      sum += amp * noise2D(x * freq, y * freq);
      maxAmp += amp;
      amp *= gain;
      freq *= lacunarity;
    }
    return sum / maxAmp;
  }

  return { noise2D, fractal2D };
}
