// ============================================================
// Tool Types and Enums (task-009)
// ============================================================

import { HexMath } from './hex-math.js';
import { createTileData, createProp, defaultOrigin, CATEGORY_TO_INT, INT_TO_ORIGIN } from './hex-grid.js';
import {
  SetBiomeCommand,
  SetElevationCommand,
  AddPropCommand,
  DeletePropCommand,
  SetSpawnCommand,
  EraseContentCommand,
  DeleteHexCommand,
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
  FLOOD_FILL: 'flood_fill',
};

export const ElevationMode = {
  SET: 'set',
  INCREMENT: 'increment',
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
    const newBiome = this.toolManager.activeValue || '';
    if (oldBiome === newBiome) return;

    const cmd = new SetBiomeCommand(this.grid, hex.q, hex.r, oldBiome, newBiome);
    this.commandHistory.execute(cmd);
    this._dragCommands.push(cmd);
  }
}

export class ElevationBrush extends DragBrushTool {
  /** @param {{ q: number, r: number }} hex */
  _applyToHex(hex) {
    const tile = this.grid.getTile(hex.q, hex.r);
    const oldElevation = tile ? tile.elevation : 0;
    let newElevation;

    if (this.toolManager.elevationMode === ElevationMode.SET) {
      newElevation = this.toolManager.elevationValue;
    } else {
      newElevation = oldElevation + this.toolManager.elevationDelta;
    }
    newElevation = Math.max(-32000, Math.min(32000, newElevation));

    if (oldElevation === newElevation) return;

    const cmd = new SetElevationCommand(this.grid, hex.q, hex.r, oldElevation, newElevation);
    this.commandHistory.execute(cmd);
    this._dragCommands.push(cmd);
  }
}

export class FloodFillTool extends BaseTool {
  onMouseDown(hex) {
    if (!hex) return;
    const tile = this.grid.getTile(hex.q, hex.r);
    if (!tile) return;

    const startBiome = tile.biome;
    const targetBiome = this.toolManager.activeValue || '';
    if (startBiome === targetBiome) return;

    const visited = new Set();
    const queue = [{ q: hex.q, r: hex.r }];
    let head = 0;
    const commands = [];
    const SAFETY_LIMIT = 10000;

    while (head < queue.length && commands.length < SAFETY_LIMIT) {
      const current = queue[head++];
      const key = `${current.q},${current.r}`;
      if (visited.has(key)) continue;
      visited.add(key);

      const t = this.grid.getTile(current.q, current.r);
      if (!t || t.biome !== startBiome) continue;

      const cmd = new SetBiomeCommand(this.grid, current.q, current.r, startBiome, targetBiome);
      commands.push(cmd);

      const neighbors = HexMath.getNeighbors(current.q, current.r);
      for (const n of neighbors) {
        const nKey = `${n.q},${n.r}`;
        if (!visited.has(nKey)) {
          queue.push(n);
        }
      }
    }

    if (commands.length > 0) {
      const batch = new BatchCommand(commands);
      this.commandHistory.execute(batch);
    }

    if (commands.length >= SAFETY_LIMIT) {
      console.warn(`FloodFill: safety limit of ${SAFETY_LIMIT} tiles reached. Some tiles may not have been filled.`);
      this.toolManager.onStatus?.(`Warning: flood fill stopped at ${SAFETY_LIMIT} tile limit.`);
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
    this.elevationMode = ElevationMode.SET;
    this.elevationValue = 0;
    this.elevationDelta = 1;
    /** @type {string} Active prop category for the Prop tool */
    this.activeCategory = 'plant';
    /** @type {string} Active origin for the Prop tool */
    this.activeOrigin = 'natural';
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
      case ToolType.FLOOD_FILL:
        this.activeTool = new FloodFillTool(this.grid, this.commandHistory, this);
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
