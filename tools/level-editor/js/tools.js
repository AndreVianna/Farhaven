// ============================================================
// Tool Types and Enums (task-009)
// ============================================================

import { HexMath } from './hex-math.js';
import { createTileData, createResourceInstance } from './hex-grid.js';
import {
  SetBiomeCommand,
  SetElevationCommand,
  AddResourceCommand,
  SetStructureCommand,
  SetAnomalyCommand,
  SetSpawnCommand,
  EraseContentCommand,
  DeleteHexCommand,
  BatchCommand,
} from './commands.js';
import { showInlineModal } from './panels.js';

export const ToolType = {
  BIOME: 'biome',
  ELEVATION: 'elevation',
  RESOURCE: 'resource',
  STRUCTURE: 'structure',
  ANOMALY: 'anomaly',
  SPAWN: 'spawn',
  ERASER: 'eraser',
  DELETE_HEX: 'delete_hex',
  FLOOD_FILL: 'flood_fill',
};

export const ElevationMode = {
  SET: 'set',
  INCREMENT: 'increment',
};

/** @type {string[]} Known structure types matching game's WALKABLE_STRUCTURES */
export const STRUCTURE_TYPES = ['workbench', 'storage_chest', 'campfire', 'shelter', 'torch'];

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
    newElevation = Math.max(0, Math.min(9, newElevation));

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
    const commands = [];
    const SAFETY_LIMIT = 10000;

    while (queue.length > 0 && commands.length < SAFETY_LIMIT) {
      const current = queue.shift();
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
  /** @param {{ q: number, r: number }} hex */
  _applyToHex(hex) {
    const tile = this.grid.getTile(hex.q, hex.r);
    if (!tile) return;
    if ((!tile.resources || tile.resources.length === 0) && !tile.structure && !tile.anomaly) return;

    const cmd = new EraseContentCommand(this.grid, hex.q, hex.r, tile);
    this.commandHistory.execute(cmd);
    this._dragCommands.push(cmd);
  }
}

// ============================================================
// Placement Tools (task-010)
// ============================================================

export class ResourcePlacer extends BaseTool {
  onMouseDown(hex) {
    if (!hex) return;
    let tile = this.grid.getTile(hex.q, hex.r);
    if (!tile) {
      // Create tile with default biome
      tile = createTileData('');
      this.grid.setTile(hex.q, hex.r, tile);
    }

    const resource = createResourceInstance(
      this.toolManager.activeValue || '',
      Math.random() * 1.6 - 0.8,  // -0.8 to 0.8
      Math.random() * 1.6 - 0.8,
      Math.floor(Math.random() * 360)  // 0-359
    );

    const cmd = new AddResourceCommand(this.grid, hex.q, hex.r, resource);
    this.commandHistory.execute(cmd);

    // Show resource detail panel if available
    if (this.toolManager.resourceDetailPanel) {
      this.toolManager.resourceDetailPanel.show(hex.q, hex.r);
    }
  }
}

export class StructurePlacer extends BaseTool {
  onMouseDown(hex) {
    if (!hex) return;
    const tile = this.grid.getTile(hex.q, hex.r);
    if (!tile) return;

    const oldStructure = tile.structure;
    const newStructure = this.toolManager.activeValue || null;
    if (oldStructure === newStructure) return;

    const cmd = new SetStructureCommand(this.grid, hex.q, hex.r, oldStructure, newStructure);
    this.commandHistory.execute(cmd);
  }
}

class AnomalyMarker extends BaseTool {
  onMouseDown(hex) {
    if (!hex) return;
    const tile = this.grid.getTile(hex.q, hex.r);
    if (!tile) return;

    showInlineModal('Enter anomaly ID:', tile.anomaly || '', (value) => {
      if (value === null || value.trim() === '') return;
      const oldAnomaly = tile.anomaly;
      const cmd = new SetAnomalyCommand(this.grid, hex.q, hex.r, oldAnomaly, value.trim());
      this.commandHistory.execute(cmd);
    });
  }
}

export class SpawnMarker extends BaseTool {
  onMouseDown(hex) {
    if (!hex) return;
    if (!this.grid.hasTile(hex.q, hex.r)) return;
    const oldSpawn = [...this.grid.meta.spawn];
    const newSpawn = [hex.q, hex.r];
    if (oldSpawn[0] === newSpawn[0] && oldSpawn[1] === newSpawn[1]) return;

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
    /** @type {function(string):void|null} */
    this.onStatus = null;
    /** @type {import('./panels.js').ResourceDetailPanel|null} */
    this.resourceDetailPanel = null;
  }

  /**
   * Set the active tool.
   * @param {string|null} toolType
   * @param {string|null} [value=null]
   * @returns {void}
   */
  setTool(toolType, value = null) {
    this.activeToolType = toolType;
    this.activeValue = value;

    if (!toolType) {
      this.activeTool = null;
      return;
    }

    switch (toolType) {
      case ToolType.BIOME:
        this.activeTool = new BiomeBrush(this.grid, this.commandHistory, this);
        break;
      case ToolType.ELEVATION:
        this.activeTool = new ElevationBrush(this.grid, this.commandHistory, this);
        break;
      case ToolType.RESOURCE:
        this.activeTool = new ResourcePlacer(this.grid, this.commandHistory, this);
        break;
      case ToolType.STRUCTURE:
        this.activeTool = new StructurePlacer(this.grid, this.commandHistory, this);
        break;
      case ToolType.ANOMALY:
        this.activeTool = new AnomalyMarker(this.grid, this.commandHistory, this);
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
