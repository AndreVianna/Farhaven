// ============================================================
// Inline Modal Dialog (task-010)
// ============================================================

import { EditResourceCommand, DeleteResourceCommand } from './commands.js';
import { HexMath } from './hex-math.js';

/**
 * Show an inline modal dialog with a text input.
 * @param {string} label
 * @param {string} defaultValue
 * @param {function(string|null):void} callback
 * @returns {void}
 */
export function showInlineModal(label, defaultValue, callback) {
  // Remove existing modal if any
  const existing = document.getElementById('inline-modal');
  if (existing) existing.remove();

  const overlay = document.createElement('div');
  overlay.id = 'inline-modal';
  overlay.style.cssText = 'position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.5);z-index:500;display:flex;align-items:center;justify-content:center;';

  const dialog = document.createElement('div');
  dialog.style.cssText = 'background:var(--bg-secondary);border:1px solid var(--border);border-radius:8px;padding:20px;min-width:320px;color:var(--text-primary);';

  const labelEl = document.createElement('div');
  labelEl.textContent = label;
  labelEl.style.cssText = 'margin-bottom:8px;font-size:14px;';

  const input = document.createElement('input');
  input.type = 'text';
  input.value = defaultValue;
  input.style.cssText = 'width:100%;padding:6px 8px;border:1px solid var(--border);border-radius:4px;background:var(--bg-tertiary);color:var(--text-primary);font-size:14px;margin-bottom:12px;box-sizing:border-box;';

  const btnRow = document.createElement('div');
  btnRow.style.cssText = 'display:flex;justify-content:flex-end;gap:8px;';

  const btnCancel = document.createElement('button');
  btnCancel.textContent = 'Cancel';
  btnCancel.style.cssText = 'padding:6px 16px;border:1px solid var(--border);border-radius:4px;background:var(--bg-tertiary);color:var(--text-primary);cursor:pointer;';

  const btnOk = document.createElement('button');
  btnOk.textContent = 'OK';
  btnOk.style.cssText = 'padding:6px 16px;border:none;border-radius:4px;background:var(--accent);color:var(--bg-primary);cursor:pointer;font-weight:600;';

  const cleanup = () => overlay.remove();

  btnCancel.addEventListener('click', () => { cleanup(); callback(null); });
  btnOk.addEventListener('click', () => { cleanup(); callback(input.value); });
  input.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') { cleanup(); callback(input.value); }
    if (e.key === 'Escape') { cleanup(); callback(null); }
  });

  btnRow.appendChild(btnCancel);
  btnRow.appendChild(btnOk);
  dialog.appendChild(labelEl);
  dialog.appendChild(input);
  dialog.appendChild(btnRow);
  overlay.appendChild(dialog);
  document.body.appendChild(overlay);
  input.focus();
  input.select();
}

// ============================================================
// ResourceDetailPanel (task-010)
// ============================================================

export class ResourceDetailPanel {
  /**
   * @param {HTMLElement} container
   * @param {import('./hex-grid.js').HexGrid} grid
   * @param {import('./commands.js').CommandHistory} cmdHistory
   */
  constructor(container, grid, cmdHistory) {
    this.container = container;
    this.grid = grid;
    this.commandHistory = cmdHistory;
    this.currentHex = null;
  }

  /**
   * Show panel for a hex.
   * @param {number} q
   * @param {number} r
   * @returns {void}
   */
  show(q, r) {
    this.currentHex = { q, r };
    this.container.style.display = 'block';
    this._renderContent();
  }

  /**
   * Hide the panel.
   * @returns {void}
   */
  hide() {
    this.currentHex = null;
    this.container.style.display = 'none';
    this.container.innerHTML = '';
  }

  /**
   * Re-render panel content.
   * @returns {void}
   */
  _renderContent() {
    if (!this.currentHex) return;
    const { q, r } = this.currentHex;
    const tile = this.grid.getTile(q, r);
    this.container.innerHTML = '';

    // Header
    const header = document.createElement('div');
    header.style.cssText = 'display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;';
    const title = document.createElement('strong');
    title.textContent = `Resources on (${q}, ${r})`;
    title.style.fontSize = '13px';
    const closeBtn = document.createElement('button');
    closeBtn.textContent = 'X';
    closeBtn.style.cssText = 'background:none;border:none;color:var(--text-secondary);cursor:pointer;font-size:14px;padding:2px 6px;';
    closeBtn.addEventListener('click', () => this.hide());
    header.appendChild(title);
    header.appendChild(closeBtn);
    this.container.appendChild(header);

    if (!tile || !tile.resources || tile.resources.length === 0) {
      const empty = document.createElement('div');
      empty.textContent = 'No resources on this hex.';
      empty.style.cssText = 'color:var(--text-secondary);font-size:12px;';
      this.container.appendChild(empty);
      return;
    }

    tile.resources.forEach((res, index) => {
      const row = document.createElement('div');
      row.style.cssText = 'border:1px solid var(--border);border-radius:4px;padding:8px;margin-bottom:6px;background:var(--bg-tertiary);';

      // Type label
      const typeLabel = document.createElement('div');
      typeLabel.textContent = res.type;
      typeLabel.style.cssText = 'font-weight:600;font-size:12px;margin-bottom:4px;color:var(--accent);';
      row.appendChild(typeLabel);

      // Input fields — sub-hex coordinates (sq, sr) and rotation
      const fields = [
        { name: 'sq', value: res.sq, min: -2, max: 2, step: 1 },
        { name: 'sr', value: res.sr, min: -2, max: 2, step: 1 },
        { name: 'rotation', value: res.rotation, min: 0, max: 359, step: 1 },
      ];

      const fieldsRow = document.createElement('div');
      fieldsRow.style.cssText = 'display:flex;gap:6px;align-items:center;flex-wrap:wrap;';

      for (const field of fields) {
        const label = document.createElement('label');
        label.style.cssText = 'font-size:11px;color:var(--text-secondary);display:flex;align-items:center;gap:2px;';
        label.textContent = field.name + ':';
        const input = document.createElement('input');
        input.type = 'number';
        input.value = String(Math.round(field.value));
        input.min = String(field.min);
        input.max = String(field.max);
        input.step = String(field.step);
        input.style.cssText = 'width:60px;padding:2px 4px;border:1px solid var(--border);border-radius:3px;background:var(--bg-secondary);color:var(--text-primary);font-size:12px;';
        input.dataset.resourceIndex = String(index);
        input.dataset.field = field.name;

        const origValue = field.value;
        const handleChange = () => {
          const newVal = parseInt(input.value, 10);
          if (isNaN(newVal)) return;
          const clamped = Math.max(field.min, Math.min(field.max, newVal));

          // Validate sub-hex position when sq or sr changes
          if (field.name === 'sq' || field.name === 'sr') {
            const testSq = field.name === 'sq' ? clamped : res.sq;
            const testSr = field.name === 'sr' ? clamped : res.sr;
            if (!HexMath.isValidSubHex(testSq, testSr)) return;
          }

          if (clamped === origValue) return;
          const oldValues = { [field.name]: origValue };
          const newValues = { [field.name]: clamped };
          const cmd = new EditResourceCommand(this.grid, q, r, index, oldValues, newValues);
          this.commandHistory.execute(cmd);
          this._renderContent(); // refresh
        };

        input.addEventListener('blur', handleChange);
        input.addEventListener('keydown', (e) => { if (e.key === 'Enter') handleChange(); });
        label.appendChild(input);
        fieldsRow.appendChild(label);
      }

      // Delete button
      const delBtn = document.createElement('button');
      delBtn.textContent = 'X';
      delBtn.title = 'Delete resource';
      delBtn.style.cssText = 'background:var(--danger);color:white;border:none;border-radius:3px;padding:2px 6px;cursor:pointer;font-size:11px;font-weight:bold;margin-left:auto;';
      delBtn.addEventListener('click', () => {
        const removed = { ...tile.resources[index] };
        const cmd = new DeleteResourceCommand(this.grid, q, r, index, removed);
        this.commandHistory.execute(cmd);
        this._renderContent(); // refresh
      });
      fieldsRow.appendChild(delBtn);

      row.appendChild(fieldsRow);
      this.container.appendChild(row);
    });
  }
}
