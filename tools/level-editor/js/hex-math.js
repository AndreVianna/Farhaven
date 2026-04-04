// ============================================================
// HexMath Module (task-007)
// ============================================================

export const HEX_SIZE = 40; // default visual scale in pixels

/**
 * Pure static hex math utilities. Flat-top axial coordinate system
 * matching Farhaven's hex_math.gd (same formulas, JS camelCase names).
 */
export const HexMath = {
  /** Flat-top axial neighbor directions: E, NE, NW, W, SW, SE */
  DIRECTIONS: [
    { q: 1, r: 0 },
    { q: 1, r: -1 },
    { q: 0, r: -1 },
    { q: -1, r: 0 },
    { q: -1, r: 1 },
    { q: 0, r: 1 },
  ],

  /**
   * Axial to pixel (flat-top hex).
   * @param {number} q
   * @param {number} r
   * @returns {{ x: number, y: number }}
   */
  axialToPixel(q, r) {
    const x = HEX_SIZE * (3 / 2 * q);
    const y = HEX_SIZE * (Math.sqrt(3) / 2 * q + Math.sqrt(3) * r);
    return { x, y };
  },

  /**
   * Pixel to axial (flat-top hex). Uses fractional axial -> cube round.
   * @param {number} x
   * @param {number} y
   * @returns {{ q: number, r: number }}
   */
  pixelToAxial(x, y) {
    const fq = (2 / 3 * x) / HEX_SIZE;
    const fr = (-1 / 3 * x + Math.sqrt(3) / 3 * y) / HEX_SIZE;
    return HexMath.cubeRound(fq, fr);
  },

  /**
   * Cube rounding for pixel-to-hex snapping.
   * @param {number} fq - fractional q
   * @param {number} fr - fractional r
   * @returns {{ q: number, r: number }}
   */
  cubeRound(fq, fr) {
    const fs = -fq - fr;
    let q = Math.round(fq);
    let r = Math.round(fr);
    let s = Math.round(fs);
    const qDiff = Math.abs(q - fq);
    const rDiff = Math.abs(r - fr);
    const sDiff = Math.abs(s - fs);
    if (qDiff > rDiff && qDiff > sDiff) {
      q = -r - s;
    } else if (rDiff > sDiff) {
      r = -q - s;
    }
    return { q, r };
  },

  /**
   * Returns the 6 neighbor coordinates of a hex.
   * @param {number} q
   * @param {number} r
   * @returns {Array<{ q: number, r: number }>}
   */
  getNeighbors(q, r) {
    return HexMath.DIRECTIONS.map(d => ({ q: q + d.q, r: r + d.r }));
  },

  /**
   * Hex distance (axial).
   * @param {number} q1
   * @param {number} r1
   * @param {number} q2
   * @param {number} r2
   * @returns {number}
   */
  distance(q1, r1, q2, r2) {
    const dq = q1 - q2;
    const dr = r1 - r2;
    const ds = (-q1 - r1) - (-q2 - r2);
    return (Math.abs(dq) + Math.abs(dr) + Math.abs(ds)) / 2;
  },

  /**
   * Returns the 6 corner points of a flat-top hex at pixel position (cx, cy).
   * @param {number} cx
   * @param {number} cy
   * @param {number} size
   * @returns {Array<{ x: number, y: number }>}
   */
  hexCorners(cx, cy, size) {
    const corners = [];
    for (let i = 0; i < 6; i++) {
      const angleDeg = 60 * i;
      const angleRad = angleDeg * Math.PI / 180;
      corners.push({
        x: cx + size * Math.cos(angleRad),
        y: cy + size * Math.sin(angleRad),
      });
    }
    return corners;
  },

  /**
   * Returns the edge index (0-5) between two adjacent hexes.
   * @param {number} q1
   * @param {number} r1
   * @param {number} q2
   * @param {number} r2
   * @returns {number} 0-5 or -1 if not adjacent
   */
  getEdgeIndex(q1, r1, q2, r2) {
    const dq = q2 - q1;
    const dr = r2 - r1;
    for (let i = 0; i < HexMath.DIRECTIONS.length; i++) {
      if (HexMath.DIRECTIONS[i].q === dq && HexMath.DIRECTIONS[i].r === dr) {
        return i;
      }
    }
    return -1;
  },
};
