// ============================================================
// CommandHistory (task-004)
// ============================================================

import { createTileData } from './hex-grid.js';

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
  constructor(grid, q, r, oldBiome, newBiome) {
    this.grid = grid;
    this.q = q;
    this.r = r;
    this.oldBiome = oldBiome;
    this.newBiome = newBiome;
    this.tab = 'map';
    this.type = 'SetBiome';
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
  }
  undo() {
    const tile = this.grid.getTile(this.q, this.r);
    if (tile) {
      tile.biome = this.oldBiome;
      this.grid.setTile(this.q, this.r, tile);
    }
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
  }
}

export class AddResourceCommand {
  /**
   * @param {import('./hex-grid.js').HexGrid} grid
   * @param {number} q
   * @param {number} r
   * @param {Object} resourceInstance
   */
  constructor(grid, q, r, resourceInstance) {
    this.grid = grid;
    this.q = q;
    this.r = r;
    this.resource = resourceInstance;
    this._index = -1;
    this.tab = 'map';
    this.type = 'AddResource';
  }
  execute() {
    const tile = this.grid.getTile(this.q, this.r);
    if (tile) {
      tile.resources.push(this.resource);
      this._index = tile.resources.length - 1;
      this.grid.setTile(this.q, this.r, tile);
    }
  }
  undo() {
    const tile = this.grid.getTile(this.q, this.r);
    if (tile && this._index >= 0) {
      tile.resources.splice(this._index, 1);
      this.grid.setTile(this.q, this.r, tile);
    }
  }
}

export class EditResourceCommand {
  /**
   * @param {import('./hex-grid.js').HexGrid} grid
   * @param {number} q
   * @param {number} r
   * @param {number} resourceIndex
   * @param {Object} oldValues
   * @param {Object} newValues
   */
  constructor(grid, q, r, resourceIndex, oldValues, newValues) {
    this.grid = grid;
    this.q = q;
    this.r = r;
    this.resourceIndex = resourceIndex;
    this.oldValues = oldValues;
    this.newValues = newValues;
    this.tab = 'map';
    this.type = 'EditResource';
  }
  execute() {
    const tile = this.grid.getTile(this.q, this.r);
    if (tile && tile.resources[this.resourceIndex]) {
      Object.assign(tile.resources[this.resourceIndex], this.newValues);
      this.grid.setTile(this.q, this.r, tile);
    }
  }
  undo() {
    const tile = this.grid.getTile(this.q, this.r);
    if (tile && tile.resources[this.resourceIndex]) {
      Object.assign(tile.resources[this.resourceIndex], this.oldValues);
      this.grid.setTile(this.q, this.r, tile);
    }
  }
}

export class DeleteResourceCommand {
  /**
   * @param {import('./hex-grid.js').HexGrid} grid
   * @param {number} q
   * @param {number} r
   * @param {number} resourceIndex
   * @param {Object} removedResource
   */
  constructor(grid, q, r, resourceIndex, removedResource) {
    this.grid = grid;
    this.q = q;
    this.r = r;
    this.resourceIndex = resourceIndex;
    this.removedResource = removedResource;
    this.tab = 'map';
    this.type = 'DeleteResource';
  }
  execute() {
    const tile = this.grid.getTile(this.q, this.r);
    if (tile) {
      tile.resources.splice(this.resourceIndex, 1);
      this.grid.setTile(this.q, this.r, tile);
    }
  }
  undo() {
    const tile = this.grid.getTile(this.q, this.r);
    if (tile) {
      tile.resources.splice(this.resourceIndex, 0, { ...this.removedResource });
      this.grid.setTile(this.q, this.r, tile);
    }
  }
}

export class SetStructureCommand {
  /**
   * @param {import('./hex-grid.js').HexGrid} grid
   * @param {number} q
   * @param {number} r
   * @param {string|null} oldStructure
   * @param {string|null} newStructure
   */
  constructor(grid, q, r, oldStructure, newStructure) {
    this.grid = grid;
    this.q = q;
    this.r = r;
    this.oldStructure = oldStructure;
    this.newStructure = newStructure;
    this.tab = 'map';
    this.type = 'SetStructure';
  }
  execute() {
    const tile = this.grid.getTile(this.q, this.r);
    if (tile) {
      tile.structure = this.newStructure;
      this.grid.setTile(this.q, this.r, tile);
    }
  }
  undo() {
    const tile = this.grid.getTile(this.q, this.r);
    if (tile) {
      tile.structure = this.oldStructure;
      this.grid.setTile(this.q, this.r, tile);
    }
  }
}

export class SetAnomalyCommand {
  /**
   * @param {import('./hex-grid.js').HexGrid} grid
   * @param {number} q
   * @param {number} r
   * @param {string|null} oldAnomaly
   * @param {string|null} newAnomaly
   */
  constructor(grid, q, r, oldAnomaly, newAnomaly) {
    this.grid = grid;
    this.q = q;
    this.r = r;
    this.oldAnomaly = oldAnomaly;
    this.newAnomaly = newAnomaly;
    this.tab = 'map';
    this.type = 'SetAnomaly';
  }
  execute() {
    const tile = this.grid.getTile(this.q, this.r);
    if (tile) {
      tile.anomaly = this.newAnomaly;
      this.grid.setTile(this.q, this.r, tile);
    }
  }
  undo() {
    const tile = this.grid.getTile(this.q, this.r);
    if (tile) {
      tile.anomaly = this.oldAnomaly;
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
   * @param {Object} oldTile - snapshot of resources, structure, anomaly
   */
  constructor(grid, q, r, oldTile) {
    this.grid = grid;
    this.q = q;
    this.r = r;
    this.oldResources = oldTile.resources ? oldTile.resources.map(r => ({ ...r })) : [];
    this.oldStructure = oldTile.structure;
    this.oldAnomaly = oldTile.anomaly;
    this.tab = 'map';
    this.type = 'EraseContent';
  }
  execute() {
    const tile = this.grid.getTile(this.q, this.r);
    if (tile) {
      tile.resources = [];
      tile.structure = null;
      tile.anomaly = null;
      this.grid.setTile(this.q, this.r, tile);
    }
  }
  undo() {
    const tile = this.grid.getTile(this.q, this.r);
    if (tile) {
      tile.resources = this.oldResources.map(r => ({ ...r }));
      tile.structure = this.oldStructure;
      tile.anomaly = this.oldAnomaly;
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
