// ============================================================
// Tool Types and Enums (task-009)
// ============================================================

import { HexMath } from './hex-math.js';
import { createTileData, createProp, defaultOrigin, CATEGORY_TO_INT, INT_TO_ORIGIN } from './hex-grid.js';
import {
  SetBiomeCommand,
  SetElevationCommand,
  SetWaterLevelCommand,
  AddPropCommand,
  DeletePropCommand,
  SetSpawnCommand,
  EraseContentCommand,
  DeleteHexCommand,
  ToggleWallCommand,
  BatchCommand,
} from './commands.js';
import { ProjectContext } from './file-discovery.js';

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
    this.commandHistory.batchReplace(this._dragCommands);
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
    this.commandHistory.execute(cmd);
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

  _applySingle(hex) {
    const tile = this.grid.getTile(hex.q, hex.r);
    if (!tile) return;

    if (tile.biome === 'B00005') {
      console.log('[_applySingle water]',
        'q,r=', hex.q, hex.r,
        'delta=', this.delta,
        'altHeld=', this.toolManager.altHeld,
        'elevation=', tile.elevation,
        'waterLevel=', tile.waterLevel);
    }

    // Alt+click on water tiles edits the SURFACE (waterLevel) instead
    // of the floor (elevation). Keeps both dimensions of a water cell
    // editable from the same tool without a separate mode.
    if (tile.biome === 'B00005' && this.toolManager.altHeld) {
      const oldLevel = typeof tile.waterLevel === 'number' ? tile.waterLevel : tile.elevation;
      const newLevel = Math.max(-32000, Math.min(32000, oldLevel + this.delta));
      if (oldLevel === newLevel) return;
      const cmd = new SetWaterLevelCommand(this.grid, hex.q, hex.r, oldLevel, newLevel);
      this.commandHistory.execute(cmd);
      this._dragCommands.push(cmd);
      return;
    }

    const oldElevation = tile.elevation;
    let target = oldElevation + this.delta;
    // Water invariant: floor depth capped at surface level. If the
    // user raises elevation above waterLevel, the SetElevationCommand
    // clamps it, but we pre-clamp here so the no-op check below can
    // catch edge cases (e.g. already-at-cap + positive delta).
    if (tile.biome === 'B00005' && typeof tile.waterLevel === 'number') {
      target = Math.min(target, tile.waterLevel);
    }
    const newElevation = Math.max(-32000, Math.min(32000, target));
    if (oldElevation === newElevation) return;

    const cmd = new SetElevationCommand(this.grid, hex.q, hex.r, oldElevation, newElevation);
    this.commandHistory.execute(cmd);
    this._dragCommands.push(cmd);
  }

  /**
   * Pinch mode: center hex gets full delta, each ring n gets delta / 2^n.
   * Fractional amounts accumulate between clicks.
   */
  _applyPinch(hex) {
    // Find max ring where effect >= 0.01
    const maxRing = Math.floor(Math.log2(Math.abs(this.delta) / 0.01));

    // Collect all affected hexes with their fractional deltas
    for (let ring = 0; ring <= maxRing; ring++) {
      const ringDelta = this.delta / Math.pow(2, ring);
      const hexes = ring === 0 ? [{ q: hex.q, r: hex.r }] : this._hexRing(hex.q, hex.r, ring);

      for (const rh of hexes) {
        if (!this.grid.hasTile(rh.q, rh.r)) continue;
        const key = `${rh.q},${rh.r}`;
        const accum = (this._pinchAccum.get(key) || 0) + ringDelta;
        const intDelta = Math.trunc(accum);
        this._pinchAccum.set(key, accum - intDelta);

        if (intDelta === 0) continue;

        const tile = this.grid.getTile(rh.q, rh.r);
        const oldElev = tile ? tile.elevation : 0;
        const newElev = Math.max(-32000, Math.min(32000, oldElev + intDelta));
        if (oldElev === newElev) continue;

        const cmd = new SetElevationCommand(this.grid, rh.q, rh.r, oldElev, newElev);
        this.commandHistory.execute(cmd);
        this._dragCommands.push(cmd);
      }
    }
  }

  /**
   * Get all hexes at exactly `ring` distance from (cq, cr).
   * @param {number} cq
   * @param {number} cr
   * @param {number} ring
   * @returns {Array<{q: number, r: number}>}
   */
  _hexRing(cq, cr, ring) {
    if (ring === 0) return [{ q: cq, r: cr }];
    const results = [];
    // Start at the hex ring-steps in the "SW" direction, then walk around
    let q = cq - ring;
    let r = cr + ring;
    for (let dir = 0; dir < 6; dir++) {
      for (let step = 0; step < ring; step++) {
        results.push({ q, r });
        q += HexMath.DIRECTIONS[dir].q;
        r += HexMath.DIRECTIONS[dir].r;
      }
    }
    return results;
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
        this.commandHistory.execute(cmd);
        this._dragCommands.push(cmd);
        return;
      }
    }

    // Fallback: erase all props
    const cmd = new EraseContentCommand(this.grid, hex.q, hex.r, tile);
    this.commandHistory.execute(cmd);
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

export class WallTool extends BaseTool {
  onMouseDown(hex) {
    if (!hex || typeof hex.edgeIdx !== 'number') return;
    if (!this.grid.hasTile(hex.q, hex.r)) return;
    const cmd = new ToggleWallCommand(this.grid, hex.q, hex.r, hex.edgeIdx);
    this.commandHistory.execute(cmd);
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
