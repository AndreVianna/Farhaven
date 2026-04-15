// ============================================================
// CommandHistory (task-004)
// ============================================================

import { createTileData, computeWaterLevel } from './hex-grid.js';
import { HexMath } from './hex-math.js';

/**
 * Update shoreline walls for ALL edges of a water tile.
 * @param {import('./hex-grid.js').HexGrid} grid
 * @param {number} wq - water tile q
 * @param {number} wr - water tile r
 */
function _updateShorelineWalls(grid, wq, wr) {
  const waterTile = grid.getTile(wq, wr);
  if (!waterTile || waterTile.biome !== 'B00005') return;
  const wl = waterTile.waterLevel != null ? waterTile.waterLevel : 0;

  for (let d = 0; d < HexMath.DIRECTIONS.length; d++) {
    const dir = HexMath.DIRECTIONS[d];
    const nq = wq + dir.q, nr = wr + dir.r;
    const neighbor = grid.getTile(nq, nr);
    if (!neighbor) continue;
    if (neighbor.biome === 'B00005') continue; // water↔water, skip
    const shouldWall = wl !== neighbor.elevation;
    waterTile.walls[d] = shouldWall;
    const opposite = (d + 3) % 6;
    neighbor.walls[opposite] = shouldWall;
  }
}

function _updateWaterNeighbors(grid, q, r) {
  const tile = grid.getTile(q, r);
  if (!tile) return;
  const tileIsWater = tile.biome === 'B00005';

  // Collect water tiles that need full shoreline wall update
  const waterTilesToUpdate = new Set();

  for (let d = 0; d < HexMath.DIRECTIONS.length; d++) {
    const dir = HexMath.DIRECTIONS[d];
    const nq = q + dir.q, nr = r + dir.r;
    const neighbor = grid.getTile(nq, nr);
    if (!neighbor) continue;
    const neighborIsWater = neighbor.biome === 'B00005';

    if (neighborIsWater && !tileIsWater) {
      neighbor.waterLevel = computeWaterLevel(grid, nq, nr);
      waterTilesToUpdate.add(`${nq},${nr}`);
    }
    if (tileIsWater && !neighborIsWater) {
      tile.waterLevel = computeWaterLevel(grid, q, r);
      waterTilesToUpdate.add(`${q},${r}`);
    }
  }

  // Update ALL shoreline walls for each affected water tile
  for (const key of waterTilesToUpdate) {
    const [wq, wr] = key.split(',').map(Number);
    _updateShorelineWalls(grid, wq, wr);
  }
}

export class CommandHistory {
  constructor() {
    /** @type {Array<Object>} Most recent at end */
    this.undoStack = [];
    /** @type {Array<Object>} Most recent at end */
    this.redoStack = [];
    /** @type {number} */
    this.maxSize = 50;
    /** @type {function(string, Object):void|null} callback: (action, command) => void */
    this.onChange = null;
  }

  /**
   * Execute a new command and push to undo stack.
   * @param {Object} command - Command object with execute(), undo(), type, tab
   * @returns {void}
   */
  execute(command) {
    command.execute();
    this.undoStack.push(command);
    this.redoStack.length = 0;
    if (this.undoStack.length > this.maxSize) {
      this.undoStack.shift();
    }
    if (this.onChange) {
      this.onChange('execute', command);
    }
  }

  /**
   * Undo the most recent command.
   * @returns {void}
   */
  undo() {
    if (this.undoStack.length === 0) return;
    const command = this.undoStack.pop();
    command.undo();
    this.redoStack.push(command);
    if (this.onChange) {
      this.onChange('undo', command);
    }
  }

  /**
   * Redo the most recently undone command.
   * @returns {void}
   */
  redo() {
    if (this.redoStack.length === 0) return;
    const command = this.redoStack.pop();
    command.execute();
    this.undoStack.push(command);
    if (this.onChange) {
      this.onChange('redo', command);
    }
  }

  /**
   * @returns {boolean}
   */
  canUndo() {
    return this.undoStack.length > 0;
  }

  /**
   * @returns {boolean}
   */
  canRedo() {
    return this.redoStack.length > 0;
  }

  /**
   * Replace individual commands on the undo stack with a single BatchCommand.
   * Used by drag tools to collapse per-hex commands into one undo step.
   * @param {Array<Object>} commands - Commands to remove and batch
   * @returns {void}
   */
  batchReplace(commands) {
    if (commands.length <= 1) return;
    for (const cmd of commands) {
      const idx = this.undoStack.indexOf(cmd);
      if (idx !== -1) this.undoStack.splice(idx, 1);
    }
    const batch = new BatchCommand(commands);
    this.undoStack.push(batch);
    if (this.onChange) {
      this.onChange('execute', batch);
    }
  }

  /**
   * Clear both stacks.
   * @returns {void}
   */
  clear() {
    this.undoStack.length = 0;
    this.redoStack.length = 0;
    if (this.onChange) {
      this.onChange('clear', null);
    }
  }
}

// ============================================================
// Command Classes (task-009 + task-010)
// ============================================================

export class SetBiomeCommand {
  /**
   * @param {import('./hex-grid.js').HexGrid} grid
   * @param {number} q
   * @param {number} r
   * @param {string} oldBiome
   * @param {string} newBiome
   */
  constructor(grid, q, r, oldBiome, newBiome, waterType = null) {
    this.grid = grid;
    this.q = q;
    this.r = r;
    this.oldBiome = oldBiome;
    this.newBiome = newBiome;
    this.waterType = waterType;
    this.tab = 'map';
    this.type = 'SetBiome';
    this._tileExistedBefore = grid.hasTile(q, r);
    // Save old state for undo
    const existingTile = grid.getTile(q, r);
    this._oldWaterType = existingTile ? existingTile.waterType : null;
    this._oldElevation = existingTile ? existingTile.elevation : 0;
    this._oldWaterLevel = existingTile ? existingTile.waterLevel : null;
  }
  execute() {
    let tile = this.grid.getTile(this.q, this.r);
    if (!tile) {
      tile = createTileData(this.newBiome);
      this.grid.setTile(this.q, this.r, tile);
    } else {
      tile.biome = this.newBiome;
      this.grid.setTile(this.q, this.r, tile);
    }
    tile.waterType = this.waterType;
    if (this.newBiome === 'B00005') {
      // Convert to water: compute waterLevel, set depth below surface
      tile.waterLevel = computeWaterLevel(this.grid, this.q, this.r);
      // Depth should be at or below waterLevel (default: waterLevel for shallow)
      if (tile.waterLevel != null && tile.elevation > tile.waterLevel) {
        tile.elevation = tile.waterLevel;
      }
      // Remove walls between this water tile and adjacent water tiles
      for (let d = 0; d < HexMath.DIRECTIONS.length; d++) {
        const dir = HexMath.DIRECTIONS[d];
        const neighbor = this.grid.getTile(this.q + dir.q, this.r + dir.r);
        if (neighbor && neighbor.biome === 'B00005') {
          tile.walls[d] = false;
          const opposite = (d + 3) % 6;
          neighbor.walls[opposite] = false;
        }
      }
    } else {
      tile.waterLevel = null;
      tile.waterType = null;
    }
    _updateWaterNeighbors(this.grid, this.q, this.r);
  }
  undo() {
    if (!this._tileExistedBefore) {
      this.grid.deleteTile(this.q, this.r);
      _updateWaterNeighbors(this.grid, this.q, this.r);
      return;
    }
    const tile = this.grid.getTile(this.q, this.r);
    if (tile) {
      tile.biome = this.oldBiome;
      tile.elevation = this._oldElevation;
      tile.waterType = this._oldWaterType;
      tile.waterLevel = this._oldWaterLevel;
      this.grid.setTile(this.q, this.r, tile);
    }
    _updateWaterNeighbors(this.grid, this.q, this.r);
  }
}

export class SetElevationCommand {
  /**
   * @param {import('./hex-grid.js').HexGrid} grid
   * @param {number} q
   * @param {number} r
   * @param {number} oldElevation
   * @param {number} newElevation
   */
  constructor(grid, q, r, oldElevation, newElevation) {
    this.grid = grid;
    this.q = q;
    this.r = r;
    this.oldElevation = oldElevation;
    this.newElevation = newElevation;
    this._created = false;
    this.tab = 'map';
    this.type = 'SetElevation';
  }
  execute() {
    let tile = this.grid.getTile(this.q, this.r);
    if (!tile) {
      tile = createTileData('');
      this._created = true;
    }
    tile.elevation = this.newElevation;
    this.grid.setTile(this.q, this.r, tile);
    _updateWaterNeighbors(this.grid, this.q, this.r);
  }
  undo() {
    if (this._created) {
      this.grid.deleteTile(this.q, this.r);
    } else {
      const tile = this.grid.getTile(this.q, this.r);
      if (tile) {
        tile.elevation = this.oldElevation;
        this.grid.setTile(this.q, this.r, tile);
      }
    }
    _updateWaterNeighbors(this.grid, this.q, this.r);
  }
}

/**
 * Toggle a wall on a hex edge (and the opposite edge on the neighbor).
 */
export class ToggleWallCommand {
  /**
   * @param {import('./hex-grid.js').HexGrid} grid
   * @param {number} q - Hex q coordinate
   * @param {number} r - Hex r coordinate
   * @param {number} edgeIdx - Edge index (0-5)
   */
  constructor(grid, q, r, edgeIdx) {
    this.grid = grid;
    this.q = q;
    this.r = r;
    this.edgeIdx = edgeIdx;
    this.tab = 'map';
    this.type = 'ToggleWall';
  }
  execute() {
    this._toggle();
  }
  undo() {
    this._toggle(); // toggle is its own inverse
  }
  _toggle() {
    const tile = this.grid.getTile(this.q, this.r);
    if (!tile || !tile.walls) return;
    tile.walls[this.edgeIdx] = !tile.walls[this.edgeIdx];
    // Also toggle the opposite edge on the neighbor
    const dir = HexMath.DIRECTIONS[this.edgeIdx];
    const nq = this.q + dir.q, nr = this.r + dir.r;
    const neighbor = this.grid.getTile(nq, nr);
    if (neighbor && neighbor.walls) {
      const oppositeIdx = (this.edgeIdx + 3) % 6;
      neighbor.walls[oppositeIdx] = tile.walls[this.edgeIdx];
    }
    // Trigger render
    this.grid.setTile(this.q, this.r, tile);
  }
}

export class AddPropCommand {
  /**
   * @param {import('./hex-grid.js').HexGrid} grid
   * @param {number} q
   * @param {number} r
   * @param {Object} propInstance
   */
  constructor(grid, q, r, propInstance) {
    this.grid = grid;
    this.q = q;
    this.r = r;
    this.prop = propInstance;
    this._index = -1;
    this.tab = 'map';
    this.type = 'AddProp';
  }
  execute() {
    const tile = this.grid.getTile(this.q, this.r);
    if (tile) {
      tile.props.push(this.prop);
      this._index = tile.props.length - 1;
      this.grid.setTile(this.q, this.r, tile);
    }
  }
  undo() {
    const tile = this.grid.getTile(this.q, this.r);
    if (tile) {
      const idx = tile.props.indexOf(this.prop);
      if (idx !== -1) {
        tile.props.splice(idx, 1);
        this.grid.setTile(this.q, this.r, tile);
      }
    }
  }
}

export class EditPropCommand {
  /**
   * @param {import('./hex-grid.js').HexGrid} grid
   * @param {number} q
   * @param {number} r
   * @param {number} propIndex
   * @param {Object} oldValues
   * @param {Object} newValues
   */
  constructor(grid, q, r, propIndex, oldValues, newValues) {
    this.grid = grid;
    this.q = q;
    this.r = r;
    this.propIndex = propIndex;
    this.oldValues = oldValues;
    this.newValues = newValues;
    this.tab = 'map';
    this.type = 'EditProp';
  }
  execute() {
    const tile = this.grid.getTile(this.q, this.r);
    if (tile && tile.props[this.propIndex]) {
      Object.assign(tile.props[this.propIndex], this.newValues);
      this.grid.setTile(this.q, this.r, tile);
    }
  }
  undo() {
    const tile = this.grid.getTile(this.q, this.r);
    if (tile && tile.props[this.propIndex]) {
      Object.assign(tile.props[this.propIndex], this.oldValues);
      this.grid.setTile(this.q, this.r, tile);
    }
  }
}

export class DeletePropCommand {
  /**
   * @param {import('./hex-grid.js').HexGrid} grid
   * @param {number} q
   * @param {number} r
   * @param {number} propIndex
   * @param {Object} removedProp
   */
  constructor(grid, q, r, propIndex, removedProp) {
    this.grid = grid;
    this.q = q;
    this.r = r;
    this.propIndex = propIndex;
    this.removedProp = JSON.parse(JSON.stringify(removedProp));
    this.tab = 'map';
    this.type = 'DeleteProp';
  }
  execute() {
    const tile = this.grid.getTile(this.q, this.r);
    if (tile) {
      tile.props.splice(this.propIndex, 1);
      this.grid.setTile(this.q, this.r, tile);
    }
  }
  undo() {
    const tile = this.grid.getTile(this.q, this.r);
    if (tile) {
      tile.props.splice(this.propIndex, 0, JSON.parse(JSON.stringify(this.removedProp)));
      this.grid.setTile(this.q, this.r, tile);
    }
  }
}

export class SetSpawnCommand {
  /**
   * @param {import('./hex-grid.js').HexGrid} grid
   * @param {number[]} oldSpawn
   * @param {number[]} newSpawn
   */
  constructor(grid, oldSpawn, newSpawn) {
    this.grid = grid;
    this.oldSpawn = [...oldSpawn];
    this.newSpawn = [...newSpawn];
    this.tab = 'map';
    this.type = 'SetSpawn';
  }
  execute() {
    this.grid.meta.spawn = [...this.newSpawn];
    if (this.grid.onChange) this.grid.onChange();
  }
  undo() {
    this.grid.meta.spawn = [...this.oldSpawn];
    if (this.grid.onChange) this.grid.onChange();
  }
}

export class EraseContentCommand {
  /**
   * @param {import('./hex-grid.js').HexGrid} grid
   * @param {number} q
   * @param {number} r
   * @param {Object} oldTile - snapshot of tile with props
   */
  constructor(grid, q, r, oldTile) {
    this.grid = grid;
    this.q = q;
    this.r = r;
    this.oldProps = oldTile.props ? JSON.parse(JSON.stringify(oldTile.props)) : [];
    this.tab = 'map';
    this.type = 'EraseContent';
  }
  execute() {
    const tile = this.grid.getTile(this.q, this.r);
    if (tile) {
      tile.props = [];
      this.grid.setTile(this.q, this.r, tile);
    }
  }
  undo() {
    const tile = this.grid.getTile(this.q, this.r);
    if (tile) {
      tile.props = JSON.parse(JSON.stringify(this.oldProps));
      this.grid.setTile(this.q, this.r, tile);
    }
  }
}

export class DeleteHexCommand {
  /**
   * @param {import('./hex-grid.js').HexGrid} grid
   * @param {number} q
   * @param {number} r
   * @param {Object} oldTileData
   */
  constructor(grid, q, r, oldTileData) {
    this.grid = grid;
    this.q = q;
    this.r = r;
    this.oldTileData = JSON.parse(JSON.stringify(oldTileData));
    this.tab = 'map';
    this.type = 'DeleteHex';
  }
  execute() {
    this.grid.deleteTile(this.q, this.r);
  }
  undo() {
    this.grid.setTile(this.q, this.r, JSON.parse(JSON.stringify(this.oldTileData)));
  }
}

export class BatchCommand {
  /**
   * @param {Array<Object>} commands
   */
  constructor(commands) {
    this.commands = commands;
    this.tab = commands.length > 0 ? commands[0].tab : 'map';
    this.type = 'Batch';
  }
  execute() {
    for (const cmd of this.commands) {
      cmd.execute();
    }
  }
  undo() {
    for (let i = this.commands.length - 1; i >= 0; i--) {
      this.commands[i].undo();
    }
  }
}
