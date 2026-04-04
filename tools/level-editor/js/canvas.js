// ============================================================
// HexCanvas — Rendering and Interaction (task-008)
// ============================================================

import { HEX_SIZE, HexMath } from './hex-math.js';

/** @type {string} Fallback color for unknown biomes */
export const BIOME_FALLBACK_COLOR = '#888888';

export class HexCanvas {
  /**
   * @param {HTMLCanvasElement} canvasElement
   * @param {import('./hex-grid.js').HexGrid} grid
   * @param {{ offsetX: number, offsetY: number, zoom: number }} camera
   * @param {Map<string, string>} biomeColorMap
   */
  constructor(canvasElement, grid, camera, biomeColorMap) {
    this.canvas = canvasElement;
    this.ctx = canvasElement && typeof canvasElement.getContext === 'function'
      ? canvasElement.getContext('2d') : null;
    this.grid = grid;
    this.camera = camera;
    this.biomeColorMap = biomeColorMap;
    this.selectedHex = null;
    this.hoveredHex = null;
    /** @type {Set<string>} Ghost hex positions (recomputed each render) */
    this._ghostSet = new Set();
    this.showCoordinates = false;
    this.isPanning = false;
    this.panStart = null;
    this.spaceHeld = false;
    this.toolManager = null;
    this._renderRequested = false;
    this._mouseDown = false;

    this._onMouseDown = this._onMouseDown.bind(this);
    this._onMouseMove = this._onMouseMove.bind(this);
    this._onMouseUp = this._onMouseUp.bind(this);
    this._onWheel = this._onWheel.bind(this);
    this._onResize = this._onResize.bind(this);
    this._onKeyDown = this._onKeyDown.bind(this);
    this._onKeyUp = this._onKeyUp.bind(this);
    this._onMouseLeave = this._onMouseLeave.bind(this);
    this._onContextMenu = this._onContextMenu.bind(this);
  }

  /**
   * Attach event listeners and subscribe to grid changes.
   * @returns {void}
   */
  init() {
    if (!this.ctx) return;
    this.canvas.addEventListener('mousedown', this._onMouseDown);
    this.canvas.addEventListener('mousemove', this._onMouseMove);
    this.canvas.addEventListener('mouseup', this._onMouseUp);
    this.canvas.addEventListener('mouseleave', this._onMouseLeave);
    this.canvas.addEventListener('wheel', this._onWheel, { passive: false });
    this.canvas.addEventListener('contextmenu', this._onContextMenu);
    window.addEventListener('resize', this._onResize);
    document.addEventListener('keydown', this._onKeyDown);
    document.addEventListener('keyup', this._onKeyUp);

    this.grid.onChange = () => this.requestRender();

    this._onResize();
    this.requestRender();
  }

  /**
   * Detach event listeners.
   * @returns {void}
   */
  destroy() {
    this.canvas.removeEventListener('mousedown', this._onMouseDown);
    this.canvas.removeEventListener('mousemove', this._onMouseMove);
    this.canvas.removeEventListener('mouseup', this._onMouseUp);
    this.canvas.removeEventListener('mouseleave', this._onMouseLeave);
    this.canvas.removeEventListener('wheel', this._onWheel);
    this.canvas.removeEventListener('contextmenu', this._onContextMenu);
    window.removeEventListener('resize', this._onResize);
    document.removeEventListener('keydown', this._onKeyDown);
    document.removeEventListener('keyup', this._onKeyUp);
  }

  /**
   * Schedule a render on the next animation frame.
   * @returns {void}
   */
  requestRender() {
    if (!this.ctx || this._renderRequested) return;
    this._renderRequested = true;
    requestAnimationFrame(() => {
      this._renderRequested = false;
      this.render();
    });
  }

  /**
   * Full redraw of the canvas.
   * @returns {void}
   */
  render() {
    const ctx = this.ctx;
    const w = this.canvas.width;
    const h = this.canvas.height;

    // Clear with background
    ctx.fillStyle = '#1a1a2e';
    ctx.fillRect(0, 0, w, h);

    if (this.grid.tiles.size === 0) return;

    // Compute ghost set — empty positions adjacent to existing tiles
    this._ghostSet = this._computeGhostSet();

    // Draw ghost hexes (behind real tiles)
    for (const key of this._ghostSet) {
      const parts = key.split(',');
      const q = parseInt(parts[0], 10);
      const r = parseInt(parts[1], 10);
      this._drawGhostHex(q, r);
    }

    // Draw all real hexes
    for (const [key, tile] of this.grid.getAllTiles()) {
      const parts = key.split(',');
      const q = parseInt(parts[0], 10);
      const r = parseInt(parts[1], 10);
      this._drawHex(q, r, tile);
      this._drawElevationOverlay(q, r, tile);
      this._drawCliffEdges(q, r, tile);
      if (tile.resources && tile.resources.length > 0) {
        this._drawResourceIndicator(q, r, tile.resources.length);
      }
      if (tile.structure) {
        this._drawStructureIcon(q, r, tile.structure);
      }
      if (this.showCoordinates) {
        this._drawCoordinateLabel(q, r);
      }
    }

    // Draw spawn marker
    const spawn = this.grid.meta.spawn;
    if (spawn && this.grid.hasTile(spawn[0], spawn[1])) {
      this._drawSpawnMarker(spawn[0], spawn[1]);
    }

    // Draw hover highlight (works on both real tiles and ghost cells)
    if (this.hoveredHex) {
      const hKey = `${this.hoveredHex.q},${this.hoveredHex.r}`;
      if (this.grid.hasTile(this.hoveredHex.q, this.hoveredHex.r) || (this._ghostSet && this._ghostSet.has(hKey))) {
        this._drawHoverHighlight(this.hoveredHex.q, this.hoveredHex.r);
      }
    }

    // Draw selection
    if (this.selectedHex && this.grid.hasTile(this.selectedHex.q, this.selectedHex.r)) {
      this._drawSelection(this.selectedHex.q, this.selectedHex.r);
    }
  }

  /**
   * Draw a hex polygon filled with biome color, adjusted for elevation.
   * @param {number} q
   * @param {number} r
   * @param {Object} tile
   * @returns {void}
   */
  _drawHex(q, r, tile) {
    const ctx = this.ctx;
    const world = HexMath.axialToPixel(q, r);
    const screen = this.worldToScreen(world.x, world.y);
    const size = HEX_SIZE * this.camera.zoom;
    const corners = HexMath.hexCorners(screen.x, screen.y, size);

    // Get biome color
    let color = this.biomeColorMap.get(tile.biome) || BIOME_FALLBACK_COLOR;

    // Apply elevation brightness
    if (tile.elevation > 0) {
      color = this._adjustBrightness(color, 1 + tile.elevation * 0.05);
    }

    ctx.beginPath();
    ctx.moveTo(corners[0].x, corners[0].y);
    for (let i = 1; i < 6; i++) {
      ctx.lineTo(corners[i].x, corners[i].y);
    }
    ctx.closePath();
    ctx.fillStyle = color;
    ctx.fill();

    // Thin border
    ctx.strokeStyle = 'rgba(0,0,0,0.3)';
    ctx.lineWidth = 1;
    ctx.stroke();
  }

  /**
   * Draw elevation number overlay.
   * @param {number} q
   * @param {number} r
   * @param {Object} tile
   * @returns {void}
   */
  _drawElevationOverlay(q, r, tile) {
    if (tile.elevation <= 0) return;
    const ctx = this.ctx;
    const world = HexMath.axialToPixel(q, r);
    const screen = this.worldToScreen(world.x, world.y);
    const fontSize = Math.max(8, 12 * this.camera.zoom);
    ctx.font = `bold ${fontSize}px sans-serif`;
    ctx.fillStyle = 'rgba(255,255,255,0.8)';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(String(tile.elevation), screen.x, screen.y);
  }

  /**
   * Draw cliff edges where elevation diff >= 2.
   * @param {number} q
   * @param {number} r
   * @param {Object} tile
   * @returns {void}
   */
  _drawCliffEdges(q, r, tile) {
    const ctx = this.ctx;
    const neighbors = HexMath.getNeighbors(q, r);
    const world = HexMath.axialToPixel(q, r);
    const screen = this.worldToScreen(world.x, world.y);
    const size = HEX_SIZE * this.camera.zoom;
    const corners = HexMath.hexCorners(screen.x, screen.y, size);

    // For flat-top hexes (corners at 0°,60°,…,300° clockwise in screen space):
    // Edge i→(i+1) midpoint points at angle (30+60*i)°, which aligns with
    // DIRECTIONS at index (6-i)%6. Lookup avoids modular arithmetic errors.
    const EDGE_TO_NEIGHBOR = [0, 5, 4, 3, 2, 1];
    for (let i = 0; i < 6; i++) {
      const n = neighbors[EDGE_TO_NEIGHBOR[i]];
      const neighbor = this.grid.getTile(n.q, n.r);
      if (!neighbor) continue;
      if (Math.abs(tile.elevation - neighbor.elevation) >= 2) {
        ctx.beginPath();
        ctx.moveTo(corners[i].x, corners[i].y);
        ctx.lineTo(corners[(i + 1) % 6].x, corners[(i + 1) % 6].y);
        ctx.strokeStyle = '#8B4513';
        ctx.lineWidth = 3 * this.camera.zoom;
        ctx.stroke();
      }
    }
  }

  /**
   * Draw selection highlight.
   * @param {number} q
   * @param {number} r
   * @returns {void}
   */
  _drawSelection(q, r) {
    const ctx = this.ctx;
    const world = HexMath.axialToPixel(q, r);
    const screen = this.worldToScreen(world.x, world.y);
    const size = HEX_SIZE * this.camera.zoom;
    const corners = HexMath.hexCorners(screen.x, screen.y, size);

    ctx.beginPath();
    ctx.moveTo(corners[0].x, corners[0].y);
    for (let i = 1; i < 6; i++) {
      ctx.lineTo(corners[i].x, corners[i].y);
    }
    ctx.closePath();
    ctx.strokeStyle = '#ffffff';
    ctx.lineWidth = 2.5 * this.camera.zoom;
    ctx.stroke();
  }

  /**
   * Draw hover highlight.
   * @param {number} q
   * @param {number} r
   * @returns {void}
   */
  _drawHoverHighlight(q, r) {
    const ctx = this.ctx;
    const world = HexMath.axialToPixel(q, r);
    const screen = this.worldToScreen(world.x, world.y);
    const size = HEX_SIZE * this.camera.zoom;
    const corners = HexMath.hexCorners(screen.x, screen.y, size);

    ctx.beginPath();
    ctx.moveTo(corners[0].x, corners[0].y);
    for (let i = 1; i < 6; i++) {
      ctx.lineTo(corners[i].x, corners[i].y);
    }
    ctx.closePath();
    ctx.fillStyle = 'rgba(255,255,255,0.15)';
    ctx.fill();
  }

  /**
   * Draw coordinate label at hex center.
   * @param {number} q
   * @param {number} r
   * @returns {void}
   */
  _drawCoordinateLabel(q, r) {
    const ctx = this.ctx;
    const world = HexMath.axialToPixel(q, r);
    const screen = this.worldToScreen(world.x, world.y);
    const fontSize = Math.max(7, 10 * this.camera.zoom);
    ctx.font = `${fontSize}px sans-serif`;
    ctx.fillStyle = 'rgba(180,180,180,0.7)';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'bottom';
    ctx.fillText(`${q},${r}`, screen.x, screen.y - 2 * this.camera.zoom);
  }

  /**
   * Draw spawn marker.
   * @param {number} q
   * @param {number} r
   * @returns {void}
   */
  _drawSpawnMarker(q, r) {
    const ctx = this.ctx;
    const world = HexMath.axialToPixel(q, r);
    const screen = this.worldToScreen(world.x, world.y);
    const size = 8 * this.camera.zoom;

    ctx.beginPath();
    ctx.arc(screen.x, screen.y - HEX_SIZE * this.camera.zoom * 0.3, size, 0, Math.PI * 2);
    ctx.fillStyle = '#ffcc00';
    ctx.fill();
    ctx.strokeStyle = '#000';
    ctx.lineWidth = 1.5;
    ctx.stroke();

    // "S" label
    const fontSize = Math.max(6, 10 * this.camera.zoom);
    ctx.font = `bold ${fontSize}px sans-serif`;
    ctx.fillStyle = '#000';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('S', screen.x, screen.y - HEX_SIZE * this.camera.zoom * 0.3);
  }

  /**
   * Draw resource count badge.
   * @param {number} q
   * @param {number} r
   * @param {number} count
   * @returns {void}
   */
  _drawResourceIndicator(q, r, count) {
    const ctx = this.ctx;
    const world = HexMath.axialToPixel(q, r);
    const screen = this.worldToScreen(world.x, world.y);
    const offsetY = HEX_SIZE * this.camera.zoom * 0.35;
    const badgeSize = Math.max(5, 7 * this.camera.zoom);

    ctx.beginPath();
    ctx.arc(screen.x + HEX_SIZE * this.camera.zoom * 0.3, screen.y + offsetY, badgeSize, 0, Math.PI * 2);
    ctx.fillStyle = '#4488ff';
    ctx.fill();

    const fontSize = Math.max(5, 8 * this.camera.zoom);
    ctx.font = `bold ${fontSize}px sans-serif`;
    ctx.fillStyle = '#fff';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(String(count), screen.x + HEX_SIZE * this.camera.zoom * 0.3, screen.y + offsetY);
  }

  /**
   * Draw structure indicator.
   * @param {number} q
   * @param {number} r
   * @param {string} type
   * @returns {void}
   */
  _drawStructureIcon(q, r, type) {
    const ctx = this.ctx;
    const world = HexMath.axialToPixel(q, r);
    const screen = this.worldToScreen(world.x, world.y);
    const offsetY = HEX_SIZE * this.camera.zoom * 0.35;

    const fontSize = Math.max(5, 8 * this.camera.zoom);
    ctx.font = `${fontSize}px sans-serif`;
    ctx.fillStyle = '#ffaa44';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';

    // Abbreviation
    const abbrev = type.substring(0, 3).toUpperCase();
    ctx.fillText(abbrev, screen.x - HEX_SIZE * this.camera.zoom * 0.25, screen.y + offsetY);
  }

  // --- Coordinate transforms ---

  /**
   * @param {number} wx
   * @param {number} wy
   * @returns {{ x: number, y: number }}
   */
  worldToScreen(wx, wy) {
    return {
      x: wx * this.camera.zoom + this.camera.offsetX,
      y: wy * this.camera.zoom + this.camera.offsetY,
    };
  }

  /**
   * @param {number} sx
   * @param {number} sy
   * @returns {{ x: number, y: number }}
   */
  screenToWorld(sx, sy) {
    return {
      x: (sx - this.camera.offsetX) / this.camera.zoom,
      y: (sy - this.camera.offsetY) / this.camera.zoom,
    };
  }

  /**
   * @param {number} sx
   * @param {number} sy
   * @returns {{ q: number, r: number }}
   */
  screenToHex(sx, sy) {
    const world = this.screenToWorld(sx, sy);
    return HexMath.pixelToAxial(world.x, world.y);
  }

  // --- Mouse event handlers ---

  /** @param {MouseEvent} event */
  _onMouseDown(event) {
    const rect = this.canvas.getBoundingClientRect();
    const mx = event.clientX - rect.left;
    const my = event.clientY - rect.top;

    // Middle-click or space+left-click: start pan
    if (event.button === 1 || (event.button === 0 && this.spaceHeld)) {
      this.isPanning = true;
      this.panStart = { x: event.clientX, y: event.clientY };
      event.preventDefault();
      return;
    }

    // Left click
    if (event.button === 0) {
      this._mouseDown = true;
      const hex = this.screenToHex(mx, my);
      this.selectedHex = { q: hex.q, r: hex.r };

      if (this.toolManager) {
        this.toolManager.onMouseDown(hex);
      }
      this.requestRender();
    }
  }

  /** @param {MouseEvent} event */
  _onMouseMove(event) {
    const rect = this.canvas.getBoundingClientRect();
    const mx = event.clientX - rect.left;
    const my = event.clientY - rect.top;

    // Handle pan drag
    if (this.isPanning && this.panStart) {
      const dx = event.clientX - this.panStart.x;
      const dy = event.clientY - this.panStart.y;
      this.camera.offsetX += dx;
      this.camera.offsetY += dy;
      this.panStart = { x: event.clientX, y: event.clientY };
      this.requestRender();
      return;
    }

    // Update hovered hex
    const hex = this.screenToHex(mx, my);
    const prevHover = this.hoveredHex;
    if (!prevHover || prevHover.q !== hex.q || prevHover.r !== hex.r) {
      this.hoveredHex = { q: hex.q, r: hex.r };
      this._updateTooltip(hex, event.clientX, event.clientY);
      this.requestRender();
    }

    // Forward to tool during drag
    if (this._mouseDown && this.toolManager) {
      this.toolManager.onMouseMove(hex);
    }
  }

  /** @param {MouseEvent} event */
  _onMouseUp(event) {
    if (this.isPanning) {
      this.isPanning = false;
      this.panStart = null;
      return;
    }

    if (this._mouseDown) {
      this._mouseDown = false;
      const rect = this.canvas.getBoundingClientRect();
      const mx = event.clientX - rect.left;
      const my = event.clientY - rect.top;
      const hex = this.screenToHex(mx, my);
      if (this.toolManager) {
        this.toolManager.onMouseUp(hex);
      }
    }
  }

  /** @param {MouseEvent} event */
  _onMouseLeave(event) {
    this.hoveredHex = null;
    this._hideTooltip();
    if (this._mouseDown) {
      this._mouseDown = false;
      if (this.toolManager) {
        this.toolManager.onMouseUp(null);
      }
    }
    this.requestRender();
  }

  /** @param {WheelEvent} event */
  _onWheel(event) {
    event.preventDefault();
    const rect = this.canvas.getBoundingClientRect();
    const mx = event.clientX - rect.left;
    const my = event.clientY - rect.top;

    // Record world point under cursor before zoom
    const worldBefore = this.screenToWorld(mx, my);

    // Adjust zoom
    const delta = event.deltaY * -0.001;
    this.camera.zoom = Math.max(0.2, Math.min(3.0, this.camera.zoom + delta));

    // Adjust offsets so world point stays under cursor
    this.camera.offsetX = mx - worldBefore.x * this.camera.zoom;
    this.camera.offsetY = my - worldBefore.y * this.camera.zoom;

    this.requestRender();
  }

  /** @param {KeyboardEvent} event */
  _onKeyDown(event) {
    if (event.key === ' ') {
      this.spaceHeld = true;
    }
  }

  /** @param {KeyboardEvent} event */
  _onKeyUp(event) {
    if (event.key === ' ') {
      this.spaceHeld = false;
    }
  }

  /** @param {Event} event */
  _onContextMenu(event) {
    event.preventDefault();
  }

  // --- Ghost Grid ---

  /**
   * Compute the set of empty hex positions adjacent to any existing tile.
   * @returns {Set<string>} Set of "q,r" keys for ghost positions
   */
  _computeGhostSet() {
    const ghosts = new Set();
    for (const key of this.grid.tiles.keys()) {
      const parts = key.split(',');
      const q = parseInt(parts[0], 10);
      const r = parseInt(parts[1], 10);
      const neighbors = HexMath.getNeighbors(q, r);
      for (const n of neighbors) {
        if (!this.grid.hasTile(n.q, n.r)) {
          ghosts.add(`${n.q},${n.r}`);
        }
      }
    }
    return ghosts;
  }

  /**
   * Draw a faint ghost hex outline at an empty position.
   * @param {number} q
   * @param {number} r
   * @returns {void}
   */
  _drawGhostHex(q, r) {
    const ctx = this.ctx;
    const world = HexMath.axialToPixel(q, r);
    const screen = this.worldToScreen(world.x, world.y);
    const size = HEX_SIZE * this.camera.zoom;
    const corners = HexMath.hexCorners(screen.x, screen.y, size);

    ctx.beginPath();
    ctx.moveTo(corners[0].x, corners[0].y);
    for (let i = 1; i < 6; i++) {
      ctx.lineTo(corners[i].x, corners[i].y);
    }
    ctx.closePath();
    ctx.fillStyle = 'rgba(255,255,255,0.04)';
    ctx.fill();
    ctx.strokeStyle = 'rgba(255,255,255,0.12)';
    ctx.lineWidth = 1;
    ctx.stroke();
  }

  /**
   * Update canvas dimensions to fill parent.
   * @returns {void}
   */
  _onResize() {
    const parent = this.canvas.parentElement;
    if (!parent) return;
    // Account for sidebar
    const sidebar = parent.querySelector('#sidebar');
    const sidebarWidth = sidebar ? sidebar.offsetWidth : 0;
    this.canvas.width = parent.clientWidth - sidebarWidth;
    this.canvas.height = parent.clientHeight;
    this.requestRender();
  }

  /**
   * Center the camera so all tiles fit in view with some padding.
   * @param {number} [padding=40] - Pixels of padding around the map
   * @returns {void}
   */
  fitToView(padding = 40) {
    if (this.grid.tiles.size === 0) return;

    // Compute world-space bounding box of all tile centers
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    for (const key of this.grid.tiles.keys()) {
      const parts = key.split(',');
      const q = parseInt(parts[0], 10);
      const r = parseInt(parts[1], 10);
      const world = HexMath.axialToPixel(q, r);
      if (world.x < minX) minX = world.x;
      if (world.y < minY) minY = world.y;
      if (world.x > maxX) maxX = world.x;
      if (world.y > maxY) maxY = world.y;
    }

    // Expand by hex size so edges aren't clipped
    minX -= HEX_SIZE;
    minY -= HEX_SIZE;
    maxX += HEX_SIZE;
    maxY += HEX_SIZE;

    const worldW = maxX - minX;
    const worldH = maxY - minY;
    const canvasW = this.canvas.width;
    const canvasH = this.canvas.height;

    if (canvasW === 0 || canvasH === 0) return;

    // Zoom to fit
    const scaleX = (canvasW - padding * 2) / worldW;
    const scaleY = (canvasH - padding * 2) / worldH;
    this.camera.zoom = Math.min(scaleX, scaleY, 3.0);
    this.camera.zoom = Math.max(this.camera.zoom, 0.2);

    // Center the map
    const worldCenterX = (minX + maxX) / 2;
    const worldCenterY = (minY + maxY) / 2;
    this.camera.offsetX = canvasW / 2 - worldCenterX * this.camera.zoom;
    this.camera.offsetY = canvasH / 2 - worldCenterY * this.camera.zoom;

    this.requestRender();
  }

  // --- Tooltip ---

  /**
   * @param {{ q: number, r: number }} hex
   * @param {number} clientX
   * @param {number} clientY
   * @returns {void}
   */
  _updateTooltip(hex, clientX, clientY) {
    const tile = this.grid.getTile(hex.q, hex.r);
    const tooltip = document.getElementById('hex-tooltip');
    if (!tooltip) return;

    if (!tile) {
      // Show minimal tooltip for ghost cells
      const ghostKey = `${hex.q},${hex.r}`;
      if (this._ghostSet && this._ghostSet.has(ghostKey)) {
        tooltip.textContent = `(${hex.q}, ${hex.r}) \u2014 empty`;
        tooltip.style.display = 'block';
        tooltip.style.whiteSpace = 'pre-line';
        tooltip.style.left = (clientX + 15) + 'px';
        tooltip.style.top = (clientY + 15) + 'px';
        return;
      }
      this._hideTooltip();
      return;
    }

    const lines = [`(${hex.q}, ${hex.r})`];
    lines.push(`Biome: ${tile.biome || 'none'}`);
    lines.push(`Elevation: ${tile.elevation}`);
    if (tile.structure) {
      lines.push(`Structure: ${tile.structure}`);
    }
    if (tile.resources && tile.resources.length > 0) {
      // Aggregate by type
      const counts = {};
      for (const res of tile.resources) {
        counts[res.type] = (counts[res.type] || 0) + 1;
      }
      const parts = Object.entries(counts).map(([t, c]) => `${t} x${c}`);
      if (parts.length > 5) {
        const extra = parts.length - 5;
        lines.push(`Resources: ${parts.slice(0, 5).join(', ')}... and ${extra} more`);
      } else {
        lines.push(`Resources: ${parts.join(', ')}`);
      }
    }
    if (tile.anomaly) {
      lines.push(`Anomaly: ${tile.anomaly}`);
    }

    tooltip.textContent = lines.join('\n');
    tooltip.style.display = 'block';
    tooltip.style.whiteSpace = 'pre-line';
    tooltip.style.left = (clientX + 15) + 'px';
    tooltip.style.top = (clientY + 15) + 'px';
  }

  /**
   * @returns {void}
   */
  _hideTooltip() {
    const tooltip = document.getElementById('hex-tooltip');
    if (tooltip) tooltip.style.display = 'none';
  }

  /**
   * Adjust brightness of a CSS color string.
   * @param {string} color - rgb(...) or hex color
   * @param {number} factor - multiplier
   * @returns {string}
   */
  _adjustBrightness(color, factor) {
    let r, g, b;
    if (color.startsWith('rgb(')) {
      const match = color.match(/rgb\((\d+),\s*(\d+),\s*(\d+)\)/);
      if (match) {
        r = parseInt(match[1], 10);
        g = parseInt(match[2], 10);
        b = parseInt(match[3], 10);
      } else {
        return color;
      }
    } else if (color.startsWith('#')) {
      const hex = color.slice(1);
      r = parseInt(hex.substring(0, 2), 16);
      g = parseInt(hex.substring(2, 4), 16);
      b = parseInt(hex.substring(4, 6), 16);
    } else {
      return color;
    }
    r = Math.min(255, Math.round(r * factor));
    g = Math.min(255, Math.round(g * factor));
    b = Math.min(255, Math.round(b * factor));
    return `rgb(${r},${g},${b})`;
  }
}
