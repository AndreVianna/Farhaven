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
    if (tile && this._index >= 0) {
      tile.props.splice(this._index, 1);
      this.grid.setTile(this.q, this.r, tile);
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
