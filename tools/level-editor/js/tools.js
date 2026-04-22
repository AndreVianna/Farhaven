// ============================================================
// Tool Types and Enums (task-009)
// ============================================================

import { HexMath } from './hex-math.js';
import { createTileData, createProp, defaultOrigin, CATEGORY_TO_INT, INT_TO_ORIGIN } from './hex-grid.js';
import {
  SetBiomeCommand,
  SetElevationCommand,
  SetWaterLevelCommand,
  SetTemperatureCommand,
  AddPropCommand,
  DeletePropCommand,
  SetSpawnCommand,
  EraseContentCommand,
  DeleteHexCommand,
  ToggleWallCommand,
  ClearHexWallsCommand,
  BatchCommand,
} from './commands.js';
import { ProjectContext } from './file-discovery.js';
import { createNoise2D } from './simplex-noise.js';

/**
 * Check if a sub-hex position is occupied by any prop on the tile.
 * @param {Object} tile
 * @param {number} sq
 * @param {number} sr
 * @returns {boolean}
 */
function isSubHexOccupied(tile, sq, sr) {
  if (!tile.props) return false;
  return tile.props.some(p => {
    if (p.sq === sq && p.sr === sr) return true;
    // Check structure footprints
    if (p.footprint) {
      return p.footprint.some(f => f.q === sq && f.r === sr);
    }
    return false;
  });
}

export const ToolType = {
  SELECT: 'select',
  BIOME: 'biome',
  ELEVATION: 'elevation',
  PROP: 'prop',
  SPAWN: 'spawn',
  ERASER: 'eraser',
  DELETE_HEX: 'delete_hex',
  WALL: 'wall',
  REGION: 'region',
};

/**
 * Built-in Region Brush presets. Each entry is a partial config —
 * the brush merges it with whatever custom overrides the sidebar
 * sliders produced at click time. `biome: null` or `elevation: null`
 * means "don't touch this dimension on painted tiles".
 */
export const RegionBrushPresets = {
  MOUNTAIN_WALL: { label: 'Mountain Wall',  biome: 'B00004', elevation: 10, hazard_level: 0, radius: 8,  edge_roughness: 0.6 },
  SHORELINE:     { label: 'Shoreline',      biome: 'B00008', elevation: 0,  hazard_level: 0, radius: 4,  edge_roughness: 0.7 },
  ALPINE_PEAK:   { label: 'Alpine Peak',    biome: 'B00007', elevation: 12, hazard_level: 2, radius: 10, edge_roughness: 0.5 },
  VOLCANIC_FLOW: { label: 'Volcanic Flow',  biome: 'B00006', elevation: 3,  hazard_level: 3, radius: 12, edge_roughness: 0.7 },
  CUSTOM:        { label: 'Custom',         biome: null,     elevation: null, hazard_level: 0, radius: 6, edge_roughness: 0.5 },
};


/**
 * Look up footprint offsets for a prop type from ProjectContext.
 * Returns an array of {q, r} offsets, or null if no footprint is defined.
 * @param {string} type - Prop type name (e.g. 'workbench')
 * @returns {Array<{q: number, r: number}>|null}
 */
export function getFootprintForType(type) {
  const entry = ProjectContext.files.props.get(type + '.tres');
  if (!entry || !entry.data) return null;
  const fp = entry.data.footprint;
  if (!fp || !Array.isArray(fp) || fp.length === 0) return null;
  return _parseFootprint(fp);
}

/**
 * Parse a footprint array from ProjectContext data into {q, r} offsets.
 * Handles TresValue objects ({type:'vector2i', value:{x,y}}) and plain {x,y} objects.
 * @param {Array<*>} fp
 * @returns {Array<{q: number, r: number}>}
 */
function _parseFootprint(fp) {
  return fp.map(item => {
    // TresValue: { type: 'vector2i', value: { x, y } }
    if (item && typeof item === 'object' && item.type === 'vector2i' && item.value) {
      return { q: item.value.x, r: item.value.y };
    }
    // Plain { x, y } (if data layer already extracted .value)
    if (item && typeof item === 'object' && 'x' in item) {
      return { q: item.x, r: item.y };
    }
    // Already { q, r }
    if (item && typeof item === 'object' && 'q' in item) {
      return { q: item.q, r: item.r };
    }
    return { q: 0, r: 0 };
  });
}

// ============================================================
// Tool Classes (task-009)
// ============================================================

/**
 * Base tool interface.
 */
export class BaseTool {
  /**
   * @param {import('./hex-grid.js').HexGrid} grid
   * @param {import('./commands.js').CommandHistory} cmdHistory
   * @param {Object} toolManager
   */
  constructor(grid, cmdHistory, toolManager) {
    this.grid = grid;
    this.commandHistory = cmdHistory;
    this.toolManager = toolManager;
  }
  /** @param {{ q: number, r: number }} hex */
  onMouseDown(hex) {}
  /** @param {{ q: number, r: number }} hex */
  onMouseMove(hex) {}
  /** @param {{ q: number, r: number }|null} hex */
  onMouseUp(hex) {}
}

/**
 * Base class for drag-based brush tools. Handles drag state,
 * dedup via visited set, and batching individual commands into
 * a single undo step on mouse-up.
 */
export class DragBrushTool extends BaseTool {
  constructor(grid, cmdHistory, toolManager) {
    super(grid, cmdHistory, toolManager);
    /** @type {Set<string>} */
    this._visited = new Set();
    /** @type {Array<Object>} */
    this._dragCommands = [];
    /** @type {boolean} */
    this._isDragging = false;
  }

  onMouseDown(hex) {
    if (!hex) return;
    this._isDragging = true;
    this._visited.clear();
    this._dragCommands = [];
    this._applyAt(hex);
  }

  onMouseMove(hex) {
    if (!this._isDragging || !hex) return;
    this._applyAt(hex);
  }

  onMouseUp(hex) {
    if (!this._isDragging) return;
    this._isDragging = false;
    // Sub-commands were executed directly (side effects already applied).
    // Push a single entry to history so a big stroke doesn't push hundreds
    // of individual commands that evict older batches via maxSize trim.
    this.commandHistory.commitDrag(this._dragCommands);
    this._visited.clear();
    this._dragCommands = [];
  }

  /**
   * Try to apply the tool at the given hex. Deduplicates by coordinate.
   * @param {{ q: number, r: number }} hex
   * @returns {void}
   */
  _applyAt(hex) {
    const key = `${hex.q},${hex.r}`;
    if (this._visited.has(key)) return;
    this._visited.add(key);
    this._applyToHex(hex);
  }

  /**
   * Subclass hook: create and execute the command for this hex.
   * Push to this._dragCommands if a command was executed.
   * @param {{ q: number, r: number }} hex
   * @returns {void}
   */
  _applyToHex(hex) {}
}

export class BiomeBrush extends DragBrushTool {
  /** @param {{ q: number, r: number }} hex */
  _applyToHex(hex) {
    const tile = this.grid.getTile(hex.q, hex.r);
    const oldBiome = tile ? tile.biome : '';
    // Parse compound value: 'B00005:flowing' → biome='B00005', waterType='flowing'
    const rawValue = this.toolManager.activeValue || '';
    const [newBiome, waterType] = rawValue.includes(':') ? rawValue.split(':') : [rawValue, null];
    if (oldBiome === newBiome && (!waterType || (tile && tile.waterType === waterType))) return;

    const cmd = new SetBiomeCommand(this.grid, hex.q, hex.r, oldBiome, newBiome, waterType);
    cmd.execute();
    this._dragCommands.push(cmd);
  }
}

export class ElevationBrush extends DragBrushTool {
  constructor(grid, cmdHistory, toolManager) {
    super(grid, cmdHistory, toolManager);
    // Signed delta applied per painted hex. Left-click sets +1, right-
    // click sets -1; the canvas event handler flips this before calling
    // onMouseDown so both gestures share the same drag pipeline.
    this.delta = 1;
    // Per-hex fractional accumulators for pinch mode (ring falloff).
    // Key = "q,r", value = fractional elevation accumulated.
    /** @type {Map<string, number>} */
    this._pinchAccum = new Map();
  }

  /** @param {{ q: number, r: number }} hex */
  _applyToHex(hex) {
    if (this.toolManager.ctrlHeld) {
      this._applyPinch(hex);
    } else {
      this._applySingle(hex);
    }
  }

  /**
   * Pinch is a click-only gesture — dragging the mouse with Ctrl held
   * would otherwise fire _applyPinch at every hex along the path, and
   * overlapping radii would stack smoothstep contributions on the same
   * tiles (causing the centre to jump well past the nominal delta).
   * Non-pinch drags (regular elevation brush) keep the normal behavior.
   * @param {{ q: number, r: number }} hex
   */
  onMouseMove(hex) {
    if (this.toolManager.ctrlHeld) return;
    super.onMouseMove(hex);
  }

  _applySingle(hex) {
    const tile = this.grid.getTile(hex.q, hex.r);

    // Alt+click on an existing water tile edits the SURFACE (waterLevel)
    // instead of the floor (elevation). Only runs for tiles that already
    // exist and are water — empty hexes fall through to the elevation
    // path so the brush can still paint ground level on unset cells.
    if (tile && tile.biome === 'B00005' && this.toolManager.altHeld) {
      const oldLevel = typeof tile.waterLevel === 'number' ? tile.waterLevel : tile.elevation;
      const newLevel = Math.max(-32000, Math.min(32000, oldLevel + this.delta));
      if (oldLevel === newLevel) return;
      const cmd = new SetWaterLevelCommand(this.grid, hex.q, hex.r, oldLevel, newLevel);
      cmd.execute();
      this._dragCommands.push(cmd);
      return;
    }

    const oldElevation = tile ? tile.elevation : 0;
    let target = oldElevation + this.delta;
    // Water invariant: floor depth capped at surface level. Pre-clamp so
    // the no-op check below catches edge cases (e.g. already-at-cap).
    if (tile && tile.biome === 'B00005' && typeof tile.waterLevel === 'number') {
      target = Math.min(target, tile.waterLevel);
    }
    const newElevation = Math.max(-32000, Math.min(32000, target));
    if (oldElevation === newElevation) return;

    const cmd = new SetElevationCommand(this.grid, hex.q, hex.r, oldElevation, newElevation);
    cmd.execute();
    this._dragCommands.push(cmd);
  }

  /**
   * Pinch mode: apply delta scaled by a smoothstep falloff within
   * PINCH_RADIUS, then run a local thermal-erosion pass so repeated
   * clicks at the same spot spread the peak outward instead of piling
   * a cylinder of fixed base.
   *
   * Ctrl = pinch (delta=±1). Ctrl+Alt = pinch with 10× delta.
   * Fractional amounts accumulate between clicks via `_pinchAccum`.
   */
  _applyPinch(center) {
    const PINCH_RADIUS = 4;
    const effectiveDelta = this.toolManager.altHeld ? this.delta * 10 : this.delta;

    // Phase 1 — smoothstep-weighted elevation change inside the radius.
    // strength(d) = 1 - (3t² - 2t³)  with t = d/radius ∈ [0,1]
    // At d=0 strength=1; at d=radius strength=0 (no change).
    /** @type {Set<string>} hexes actually moved in phase 1 (seed for erosion) */
    const phase1Touched = new Set();
    for (const hex of HexMath.hexesInRadius(PINCH_RADIUS, center)) {
      if (!this.grid.hasTile(hex.q, hex.r)) continue;
      const d = HexMath.distance(hex.q, hex.r, center.q, center.r);
      const t = Math.min(1, d / PINCH_RADIUS);
      const strength = 1 - (3 * t * t - 2 * t * t * t);
      if (strength <= 0) continue;
      const fracDelta = effectiveDelta * strength;
      const key = `${hex.q},${hex.r}`;
      const accum = (this._pinchAccum.get(key) || 0) + fracDelta;
      const intDelta = Math.trunc(accum);
      this._pinchAccum.set(key, accum - intDelta);
      if (intDelta !== 0) {
        this._applyElevationChange(hex.q, hex.r, intDelta);
        phase1Touched.add(key);
      }
    }

    // Phase 2 — thermal erosion: slope outside stable angle spills
    // from peaks to valleys so the base naturally spreads.
    this._redistributeSlope(center, phase1Touched);
  }

  /**
   * Apply a signed elevation change at (q,r) via SetElevationCommand,
   * respecting water-surface clamp. No-op when the tile is absent or
   * the clamped target matches current elevation.
   * @param {number} q
   * @param {number} r
   * @param {number} delta
   */
  _applyElevationChange(q, r, delta) {
    const tile = this.grid.getTile(q, r);
    if (!tile) return;
    const oldElev = tile.elevation;
    let target = oldElev + delta;
    if (tile.biome === 'B00005' && typeof tile.waterLevel === 'number') {
      target = Math.min(target, tile.waterLevel);
    }
    const newElev = Math.max(-32000, Math.min(32000, target));
    if (oldElev === newElev) return;
    const cmd = new SetElevationCommand(this.grid, q, r, oldElev, newElev);
    cmd.execute();
    this._dragCommands.push(cmd);
  }

  /**
   * Thermal-erosion wave that propagates **outward** from the phase-1
   * footprint. Each pass, every hex in the current frontier donates at
   * most once to its single steepest-downhill neighbour (if the drop
   * exceeds TALUS). The receiver joins the frontier so next pass it
   * can pass the mass further out. The clicked centre is locked — it
   * never donates and stays at its intended peak.
   *
   * Compared to the earlier "parallel transfer to every lower neighbour"
   * scheme this prevents mass-splitting artefacts: a tall hex with
   * three low neighbours used to lose 3× as much per pass as the
   * receivers could reasonably absorb, which caused oscillation and
   * negative spikes across the map.
   *
   * @param {{q:number,r:number}} center
   * @param {Set<string>} phase1Touched - hexes moved by phase 1, seed of the wave
   */
  _redistributeSlope(center, phase1Touched) {
    const TALUS = 2;
    const TRANSFER = 0.5;
    const MAX_PASSES = 12;
    const centerKey = `${center.q},${center.r}`;

    /** @type {Set<string>} */
    let frontier = new Set(phase1Touched);

    for (let pass = 0; pass < MAX_PASSES; pass++) {
      let anyChange = false;
      /** @type {Set<string>} hexes receivers join for the next pass */
      const nextAdditions = new Set();

      for (const key of frontier) {
        if (key === centerKey) continue;                     // lock anchor
        const [q, r] = key.split(',').map(Number);
        const tile = this.grid.getTile(q, r);
        if (!tile) continue;
        // Don't erode from sea level or below — there's no mass to
        // redistribute out of a hole. Rechecked every pass so a hex
        // that sheds down to 0 stops donating on the next iteration.
        if (tile.elevation <= 0) continue;

        // Steepest-descent neighbour (not a parallel split).
        let bestDiff = 0;
        /** @type {{q:number,r:number}|null} */
        let bestNeighbor = null;
        for (const dir of HexMath.DIRECTIONS) {
          const nq = q + dir.q;
          const nr = r + dir.r;
          const neighbor = this.grid.getTile(nq, nr);
          if (!neighbor) continue;
          const diff = tile.elevation - neighbor.elevation;
          if (diff > bestDiff) {
            bestDiff = diff;
            bestNeighbor = { q: nq, r: nr };
          }
        }
        if (!bestNeighbor || bestDiff <= TALUS) continue;
        let amount = Math.trunc((bestDiff - TALUS) * TRANSFER);
        // Never pull the donor below sea level. If that would happen,
        // clamp the transfer to whatever's left above 0.
        if (amount > tile.elevation) amount = tile.elevation;
        if (amount <= 0) continue;

        // Apply immediately — serial updates avoid the oscillation of
        // simultaneous "everyone transfers based on start-of-pass state".
        this._applyElevationChange(q, r, -amount);
        this._applyElevationChange(bestNeighbor.q, bestNeighbor.r, amount);
        nextAdditions.add(`${bestNeighbor.q},${bestNeighbor.r}`);
        anyChange = true;
      }

      if (!anyChange) break;
      for (const k of nextAdditions) frontier.add(k);
    }
  }

}


/**
 * Region Brush — paints a radial splash of tiles with organic edge
 * noise. Each click/drag applies:
 *   - biome change to a chosen biome (optional; null skips)
 *   - elevation set to a chosen value (optional; null skips)
 *   - hazard-level (tile.temperature) set to a chosen value
 * Per-tile decision: a simplex-noise lookup at the tile's axial
 * coordinates combined with the tile's distance from the brush
 * center determines whether the tile falls inside the ragged
 * boundary. The entire stroke is one undo step.
 */
export class RegionBrush extends DragBrushTool {
  constructor(grid, cmdHistory, toolManager) {
    super(grid, cmdHistory, toolManager);
    /** @type {((x:number,y:number)=>number)|null} Noise sampler,
     *  created per stroke so repeated strokes don't look identical. */
    this._noise = null;
  }

  onMouseDown(hex) {
    // Re-seed the noise for every stroke so successive strokes look
    // different. Math.random() seed is fine — region painting is not
    // meant to be reproducible across sessions.
    //
    // createNoise2D returns the object {noise2D, fractal2D, warpedFbm}.
    // We want the basic sampler, so pull the noise2D function out —
    // calling the bare object threw "noise is not a function" in
    // _applyToHex and swallowed every stroke.
    const sampler = createNoise2D(Math.random() * 2147483647);
    this._noise = sampler.noise2D;
    super.onMouseDown(hex);
  }

  // Override DragBrushTool._applyAt — the default pre-inserts the
  // hex key into _visited BEFORE calling _applyToHex, which caused
  // our radial loop to skip the brush centre on click. We manage
  // the per-tile dedup inside _applyToHex so the entire splash
  // (including centre) gets a chance to paint.
  _applyAt(hex) {
    this._applyToHex(hex);
  }

  _cfg() {
    const sidebar = (this.toolManager && this.toolManager.regionConfig) || {};
    return {
      biome: (typeof sidebar.biome === 'string' && sidebar.biome !== '') ? sidebar.biome : null,
      elevation: Number.isFinite(sidebar.elevation) ? (sidebar.elevation | 0) : null,
      hazard_level: Number.isFinite(sidebar.hazard_level) ? (sidebar.hazard_level | 0) : 0,
      radius: Math.max(1, Math.min(30, sidebar.radius | 0 || 6)),
      edge_roughness: Math.max(0, Math.min(1, typeof sidebar.edge_roughness === 'number' ? sidebar.edge_roughness : 0.5)),
    };
  }

  /** Apply at the brush centre hex, splashing outward through the
   *  configured radius with organic-edge noise. Dedup keeps nearby
   *  strokes from re-painting the same tile with a different noise
   *  sample. */
  _applyToHex(center) {
    const cfg = this._cfg();
    const noise = this._noise || createNoise2D(Math.random() * 2147483647).noise2D;
    const candidates = HexMath.hexesInRadius(cfg.radius, center);
    for (const hex of candidates) {
      const key = `${hex.q},${hex.r}`;
      if (this._visited.has(key)) continue;
      const d = HexMath.distance(hex.q, hex.r, center.q, center.r);
      // Perturb the effective distance by coherent 2D noise. At
      // edge_roughness=0 the perturbation is zero → perfect circle
      // of `cfg.radius` (no hex skipped, since hexesInRadius already
      // bounds d ≤ radius). At edge_roughness=1 the boundary wobbles
      // by up to ±radius*0.5 along the noise field, giving a soft
      // blobby edge. Interior hexes stay solid at any roughness.
      const noiseVal = noise(hex.q * 0.18, hex.r * 0.18);              // [-1,1]
      const perturbation = noiseVal * cfg.edge_roughness * cfg.radius * 0.5;
      if (d + perturbation > cfg.radius) continue;
      this._visited.add(key);
      this._paintTile(hex, cfg);
    }
  }

  _paintTile(hex, cfg) {
    const tile = this.grid.getTile(hex.q, hex.r);
    // Respect map boundaries: empty hexes stay empty. Runs AFTER the
    // noise decision so the organic-edge pattern is unchanged — we
    // just skip the paint on hexes the author never placed.
    if (!tile) return;
    if (cfg.biome && tile.biome !== cfg.biome) {
      const cmd = new SetBiomeCommand(this.grid, hex.q, hex.r, tile.biome, cfg.biome, null);
      cmd.execute();
      this._dragCommands.push(cmd);
    }
    if (cfg.elevation !== null && tile.elevation !== cfg.elevation) {
      const cmd = new SetElevationCommand(this.grid, hex.q, hex.r, tile.elevation, cfg.elevation);
      cmd.execute();
      this._dragCommands.push(cmd);
    }
    if ((tile.temperature | 0) !== cfg.hazard_level) {
      const cmd = new SetTemperatureCommand(this.grid, hex.q, hex.r, tile.temperature | 0, cfg.hazard_level);
      cmd.execute();
      this._dragCommands.push(cmd);
    }
  }
}


export class EraserTool extends DragBrushTool {
  /** @param {{ q: number, r: number, sq?: number, sr?: number }} hex */
  _applyToHex(hex) {
    const tile = this.grid.getTile(hex.q, hex.r);
    if (!tile || !tile.props || tile.props.length === 0) return;

    // If sub-hex specified, try to delete the specific prop at that position
    if (typeof hex.sq === 'number' && typeof hex.sr === 'number') {
      const idx = tile.props.findIndex(p => {
        if (p.sq === hex.sq && p.sr === hex.sr) return true;
        if (p.footprint) return p.footprint.some(f => f.q === hex.sq && f.r === hex.sr);
        return false;
      });
      if (idx !== -1) {
        const cmd = new DeletePropCommand(this.grid, hex.q, hex.r, idx, tile.props[idx]);
        cmd.execute();
        this._dragCommands.push(cmd);
        return;
      }
    }

    // Fallback: erase all props
    const cmd = new EraseContentCommand(this.grid, hex.q, hex.r, tile);
    cmd.execute();
    this._dragCommands.push(cmd);
  }
}

// ============================================================
// Placement Tools (task-010)
// ============================================================

export class PropPlacer extends BaseTool {
  onMouseDown(hex) {
    if (!hex) return;
    if (!this.toolManager.activeValue) return;
    let tile = this.grid.getTile(hex.q, hex.r);
    if (!tile) {
      tile = createTileData('');
      this.grid.setTile(hex.q, hex.r, tile);
    }

    const sq = typeof hex.sq === 'number' ? hex.sq : 0;
    const sr = typeof hex.sr === 'number' ? hex.sr : 0;
    const category = this.toolManager.activeCategory || 'plant';
    const type = this.toolManager.activeValue;

    // For resources with known footprints, use footprint logic
    const offsets = getFootprintForType(type);
    if (offsets && offsets.length > 0) {
      const absoluteFootprint = offsets.map(o => ({ q: sq + o.q, r: sr + o.r }));

      // Check ALL footprint cells for validity and occupancy
      for (const cell of absoluteFootprint) {
        if (!HexMath.isValidSubHex(cell.q, cell.r)) return;
        if (isSubHexOccupied(tile, cell.q, cell.r)) return;
      }

      const catInt = CATEGORY_TO_INT[category] != null ? CATEGORY_TO_INT[category] : 0;
      const origin = this.toolManager.activeOrigin || INT_TO_ORIGIN[defaultOrigin(catInt)];
      const prop = createProp(type, sq, sr, category, {
        footprint: absoluteFootprint,
        origin,
      });
      const cmd = new AddPropCommand(this.grid, hex.q, hex.r, prop);
      this.commandHistory.execute(cmd);
      return;
    }

    // Check sub-hex occupancy for non-footprint props
    if (isSubHexOccupied(tile, sq, sr)) return;

    const catInt = CATEGORY_TO_INT[category] != null ? CATEGORY_TO_INT[category] : 0;
    const origin = this.toolManager.activeOrigin || INT_TO_ORIGIN[defaultOrigin(catInt)];
    const prop = createProp(type, sq, sr, category, {
      rotation: 0,
      origin,
    });

    const cmd = new AddPropCommand(this.grid, hex.q, hex.r, prop);
    this.commandHistory.execute(cmd);
  }
}

export class SpawnMarker extends BaseTool {
  onMouseDown(hex) {
    if (!hex) return;
    if (!this.grid.hasTile(hex.q, hex.r)) return;
    const sq = typeof hex.sq === 'number' ? hex.sq : 0;
    const sr = typeof hex.sr === 'number' ? hex.sr : 0;
    const oldSpawn = [...this.grid.meta.spawn];
    const facing = oldSpawn.length >= 5 ? oldSpawn[4] : 0;
    const newSpawn = [hex.q, hex.r, sq, sr, facing];
    if (oldSpawn[0] === newSpawn[0] && oldSpawn[1] === newSpawn[1]
      && oldSpawn[2] === newSpawn[2] && oldSpawn[3] === newSpawn[3]
      && oldSpawn[4] === newSpawn[4]) return;

    const cmd = new SetSpawnCommand(this.grid, oldSpawn, newSpawn);
    this.commandHistory.execute(cmd);
  }
}

export class DeleteHexTool extends BaseTool {
  onMouseDown(hex) {
    if (!hex) return;
    const tile = this.grid.getTile(hex.q, hex.r);
    if (!tile) return;

    const cmd = new DeleteHexCommand(this.grid, hex.q, hex.r, tile);
    this.commandHistory.execute(cmd);
  }
}

/**
 * Wall editing:
 *   - Click: toggle the nearest-edge wall (and its mirror on the neighbour)
 *   - Alt+click / Alt+drag: clear every wall on the hex. Runs through the
 *     drag pipeline so a sweep across many hexes collapses into one undo.
 */
export class WallTool extends DragBrushTool {
  onMouseDown(hex) {
    if (!hex) return;
    // Alt mode — bulk clear via the drag pipeline.
    if (this.toolManager && this.toolManager.altHeld) {
      super.onMouseDown(hex);
      return;
    }
    // Normal mode — per-edge toggle, single command, no drag.
    if (typeof hex.edgeIdx !== 'number') return;
    if (!this.grid.hasTile(hex.q, hex.r)) return;
    const cmd = new ToggleWallCommand(this.grid, hex.q, hex.r, hex.edgeIdx);
    this.commandHistory.execute(cmd);
  }

  onMouseMove(hex) {
    // Drag-clear only while Alt remains pressed. Releasing Alt mid-drag
    // stops new hexes from being cleared but keeps the current batch
    // intact so mouseUp still commits it as one undo entry.
    if (!this.toolManager || !this.toolManager.altHeld) return;
    super.onMouseMove(hex);
  }

  _applyToHex(hex) {
    const tile = this.grid.getTile(hex.q, hex.r);
    if (!tile || !tile.walls) return;
    if (!tile.walls.some(Boolean)) return;   // nothing to clear — skip
    const cmd = new ClearHexWallsCommand(this.grid, hex.q, hex.r);
    cmd.execute();
    this._dragCommands.push(cmd);
  }
}

// ============================================================
// ToolManager (task-009)
// ============================================================

export class ToolManager {
  /**
   * @param {import('./hex-grid.js').HexGrid} grid
   * @param {import('./commands.js').CommandHistory} cmdHistory
   */
  constructor(grid, cmdHistory) {
    this.grid = grid;
    this.commandHistory = cmdHistory;
    /** @type {BaseTool|null} */
    this.activeTool = null;
    /** @type {string|null} */
    this.activeToolType = null;
    /** @type {string|null} */
    this.activeValue = null;
    /** @type {string} Active prop category for the Prop tool */
    this.activeCategory = 'plant';
    /** @type {string} Active origin for the Prop tool */
    this.activeOrigin = 'natural';
    /** @type {boolean} Modifier-key state propagated from HexCanvas. */
    this.ctrlHeld = false;
    this.altHeld = false;
    /** @type {function(string):void|null} */
    this.onStatus = null;
    /** @type {import('./canvas.js').HexCanvas|null} Back-reference to the canvas for selection clearing */
    this.canvas = null;
    /** @type {{biome: string|null, elevation: number|null, hazard_level: number, radius: number, edge_roughness: number}}
     *  Region Brush config — populated by the sidebar panel. */
    this.regionConfig = {
      biome: null,
      elevation: null,
      hazard_level: 0,
      radius: 6,
      edge_roughness: 0.5,
    };
  }

  /**
   * Set the active tool.
   * @param {string|null} toolType
   * @param {string|null} [value=null]
   * @returns {void}
   */
  setTool(toolType, value = null) {
    // Clear prop/spawn selection when switching away from Select
    if (this.activeToolType === ToolType.SELECT && toolType !== ToolType.SELECT) {
      if (this.canvas) {
        this.canvas.clearPropSelection();
      }
    }

    this.activeToolType = toolType;
    this.activeValue = value;

    if (!toolType) {
      this.activeTool = null;
      return;
    }

    switch (toolType) {
      case ToolType.SELECT:
        this.activeTool = null;
        break;
      case ToolType.BIOME:
        this.activeTool = new BiomeBrush(this.grid, this.commandHistory, this);
        break;
      case ToolType.ELEVATION:
        this.activeTool = new ElevationBrush(this.grid, this.commandHistory, this);
        break;
      case ToolType.PROP:
        this.activeTool = new PropPlacer(this.grid, this.commandHistory, this);
        break;
      case ToolType.SPAWN:
        this.activeTool = new SpawnMarker(this.grid, this.commandHistory, this);
        break;
      case ToolType.ERASER:
        this.activeTool = new EraserTool(this.grid, this.commandHistory, this);
        break;
      case ToolType.DELETE_HEX:
        this.activeTool = new DeleteHexTool(this.grid, this.commandHistory, this);
        break;
      case ToolType.WALL:
        this.activeTool = new WallTool(this.grid, this.commandHistory, this);
        break;
      case ToolType.REGION:
        this.activeTool = new RegionBrush(this.grid, this.commandHistory, this);
        break;
      default:
        this.activeTool = null;
    }
  }

  /** @param {{ q: number, r: number }} hex */
  onMouseDown(hex) {
    if (this.activeTool) this.activeTool.onMouseDown(hex);
  }

  /** @param {{ q: number, r: number }} hex */
  onMouseMove(hex) {
    if (this.activeTool) this.activeTool.onMouseMove(hex);
  }

  /** @param {{ q: number, r: number }|null} hex */
  onMouseUp(hex) {
    if (this.activeTool) this.activeTool.onMouseUp(hex);
  }
}
