// ============================================================
// HexCanvas — Rendering and Interaction (task-008)
// ============================================================

import { HEX_SIZE, HexMath } from './hex-math.js';
import { HexGrid, CATEGORY_COLORS } from './hex-grid.js';

/** @type {string} Fallback color for unknown biomes */
export const BIOME_FALLBACK_COLOR = '#888888';

// ============================================================
// Named color constants (M1)
// ============================================================

const CANVAS_BG = '#1a1a2e';
const CLIFF_COLOR = '#8B4513';
const SELECTION_COLOR = '#ffffff';
const SPAWN_COLOR = '#ffcc00';
const GHOST_FILL = 'rgba(255,255,255,0.04)';
const GHOST_STROKE = 'rgba(255,255,255,0.12)';
const HOVER_FILL = 'rgba(255,255,255,0.15)';
const SUB_HEX_STROKE = 'rgba(255,255,255,0.2)';
const SUB_HEX_HOVER_FILL = 'rgba(255,255,255,0.25)';
const SUB_HEX_HOVER_STROKE = 'rgba(255,255,255,0.5)';

// ============================================================
// Rendering constants (M3)
// ============================================================
// Font sizes: scaled by camera.zoom, with a minimum floor for readability.
//   - Elevation label: bold, min 8px, base 12px
//   - Coordinate label: regular, min 7px, base 10px
//   - Spawn "S" label: bold, min 6px, base 10px
//   - Prop badges: bold, min 5px, base 8px (resource count), min 4px base 6px (anomaly "!")
// Position offsets (fractions of HEX_SIZE * zoom):
//   - Spawn marker: 0.3 above center
//   - Prop indicators: 0.35 below center
//   - Resource badge: 0.3 right of center
//   - Structure text: 0.25 left of center
//   - Coordinate label: 2px above center
// Cliff edge line width: 3 * zoom
// Selection line width: 2.5 * zoom

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
    /** @type {{ q: number, r: number }|null} Sub-hex within hovered hex */
    this.hoveredSubHex = null;
    this.isPanning = false;
    this.panStart = null;
    this.spaceHeld = false;
    this.toolManager = null;
    /** @type {function({q: number, r: number}|null, {q: number, r: number}|null):void|null} */
    this.onHexHover = null;
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

  // --- Hex path and screen helpers (D1, D4) ---

  /**
   * Trace a hex polygon path from pre-computed corners.
   * @param {Array<{x: number, y: number}>} corners
   * @returns {void}
   */
  _traceHexPath(corners) {
    this.ctx.beginPath();
    this.ctx.moveTo(corners[0].x, corners[0].y);
    for (let i = 1; i < 6; i++) {
      this.ctx.lineTo(corners[i].x, corners[i].y);
    }
    this.ctx.closePath();
  }

  /**
   * Convert axial (q, r) to screen coords and compute hex corners.
   * @param {number} q
   * @param {number} r
   * @returns {{ screen: { x: number, y: number }, size: number, corners: Array<{x: number, y: number}> }}
   */
  _getHexScreen(q, r) {
    const world = HexMath.axialToPixel(q, r);
    const screen = this.worldToScreen(world.x, world.y);
    const size = HEX_SIZE * this.camera.zoom;
    return { screen, size, corners: HexMath.hexCorners(screen.x, screen.y, size) };
  }

  /**
   * Full redraw of the canvas.
   * @returns {void}
   */
  render() {
    const ctx = this.ctx;
    const w = this.canvas.width;
    const h = this.canvas.height;

    // --- Phase 1: Clear background ---
    ctx.fillStyle = CANVAS_BG;
    ctx.fillRect(0, 0, w, h);

    if (this.grid.tiles.size === 0) return;

    // --- Phase 2: Ghost grid (behind real tiles) ---
    this._ghostSet = this._computeGhostSet();
    for (const key of this._ghostSet) {
      const { q, r } = HexGrid.parseKey(key);
      this._drawGhostHex(q, r);
    }

    // --- Phase 3: Real hexes with overlays ---
    for (const [key, tile] of this.grid.getAllTiles()) {
      const { q, r } = HexGrid.parseKey(key);
      this._drawHex(q, r, tile);
      this._drawElevationOverlay(q, r, tile);
      this._drawCliffEdges(q, r, tile);
      // Draw occupied sub-hexes on ALL tiles that have props
      if (tile.props && tile.props.length > 0) {
        this._drawSubHexOccupancy(q, r, tile);
      }
      if (this.showCoordinates) {
        this._drawCoordinateLabel(q, r);
      }
    }

    // --- Phase 4: Spawn marker ---
    const spawn = this.grid.meta.spawn;
    if (spawn && this.grid.hasTile(spawn[0], spawn[1])) {
      this._drawSpawnMarker(spawn[0], spawn[1]);
    }

    // --- Phase 5: Hover highlight (real tiles and ghost cells) ---
    if (this.hoveredHex) {
      const hKey = `${this.hoveredHex.q},${this.hoveredHex.r}`;
      if (this.grid.hasTile(this.hoveredHex.q, this.hoveredHex.r) || (this._ghostSet && this._ghostSet.has(hKey))) {
        this._drawHoverHighlight(this.hoveredHex.q, this.hoveredHex.r);
      }
    }

    // --- Phase 6: Sub-hex grid overlay on hovered hex (placement tools only) ---
    if (this.hoveredHex && this.toolManager && this._isPlacementTool()) {
      const hq = this.hoveredHex.q;
      const hr = this.hoveredHex.r;
      if (this.grid.hasTile(hq, hr) || (this._ghostSet && this._ghostSet.has(`${hq},${hr}`))) {
        this._drawSubHexGrid(hq, hr);
        if (this.hoveredSubHex) {
          this._drawSubHexHover(hq, hr, this.hoveredSubHex.q, this.hoveredSubHex.r);
        }
      }
    }

    // --- Phase 7: Selection highlight ---
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
    const { corners } = this._getHexScreen(q, r);

    // Get biome color
    let color = this.biomeColorMap.get(tile.biome) || BIOME_FALLBACK_COLOR;

    // Apply elevation brightness
    if (tile.elevation > 0) {
      color = this._adjustBrightness(color, 1 + tile.elevation * 0.05);
    }

    this._traceHexPath(corners);
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
    const { screen } = this._getHexScreen(q, r);
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
    const { corners } = this._getHexScreen(q, r);

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
        ctx.strokeStyle = CLIFF_COLOR;
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
    const { corners } = this._getHexScreen(q, r);

    this._traceHexPath(corners);
    ctx.strokeStyle = SELECTION_COLOR;
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
    const { corners } = this._getHexScreen(q, r);

    this._traceHexPath(corners);
    ctx.fillStyle = HOVER_FILL;
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
    const { screen } = this._getHexScreen(q, r);
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
    const { screen } = this._getHexScreen(q, r);
    const size = 8 * this.camera.zoom;

    ctx.beginPath();
    ctx.arc(screen.x, screen.y - HEX_SIZE * this.camera.zoom * 0.3, size, 0, Math.PI * 2);
    ctx.fillStyle = SPAWN_COLOR;
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

  // --- Sub-hex rendering ---

  /**
   * Check if the active tool needs sub-hex resolution (placement or eraser).
   * @returns {boolean}
   */
  _isPlacementTool() {
    if (!this.toolManager) return false;
    const t = this.toolManager.activeToolType;
    return t === 'resource' || t === 'structure' || t === 'anomaly' || t === 'eraser';
  }

  /**
   * Draw sub-hex grid outlines inside a hex (shown when placement tool is active).
   * @param {number} q
   * @param {number} r
   * @returns {void}
   */
  _drawSubHexGrid(q, r) {
    const ctx = this.ctx;
    const { screen } = this._getHexScreen(q, r);
    const subSize = HEX_SIZE * HexMath.SUB_HEX_SCALE * this.camera.zoom;

    for (const sh of HexMath.VALID_SUB_HEXES) {
      const offset = HexMath.subHexToPixel(sh.q, sh.r);
      const cx = screen.x + offset.x * this.camera.zoom;
      const cy = screen.y + offset.y * this.camera.zoom;
      const corners = HexMath.subHexCorners(cx, cy, subSize);

      this._traceHexPath(corners);
      ctx.strokeStyle = SUB_HEX_STROKE;
      ctx.lineWidth = 0.5;
      ctx.stroke();
    }
  }

  /**
   * Draw occupancy highlights for sub-hexes that contain props.
   * @param {number} q
   * @param {number} r
   * @param {Object} tile
   * @returns {void}
   */
  _drawSubHexOccupancy(q, r, tile) {
    const ctx = this.ctx;
    const { screen } = this._getHexScreen(q, r);
    const subSize = HEX_SIZE * HexMath.SUB_HEX_SCALE * this.camera.zoom;

    if (!tile.props) return;

    for (const prop of tile.props) {
      const color = CATEGORY_COLORS[prop.category]
        ? CATEGORY_COLORS[prop.category].fill
        : CATEGORY_COLORS.resource.fill;

      // For structures with footprint, draw all footprint hexes
      if (prop.footprint) {
        for (const f of prop.footprint) {
          const offset = HexMath.subHexToPixel(f.q, f.r);
          const cx = screen.x + offset.x * this.camera.zoom;
          const cy = screen.y + offset.y * this.camera.zoom;
          const corners = HexMath.subHexCorners(cx, cy, subSize);
          this._traceHexPath(corners);
          ctx.fillStyle = color;
          ctx.fill();
        }
      } else {
        const offset = HexMath.subHexToPixel(prop.sq, prop.sr);
        const cx = screen.x + offset.x * this.camera.zoom;
        const cy = screen.y + offset.y * this.camera.zoom;
        const corners = HexMath.subHexCorners(cx, cy, subSize);
        this._traceHexPath(corners);
        ctx.fillStyle = color;
        ctx.fill();
      }
    }
  }

  /**
   * Draw highlight on the hovered sub-hex.
   * @param {number} q
   * @param {number} r
   * @param {number} sq
   * @param {number} sr
   * @returns {void}
   */
  _drawSubHexHover(q, r, sq, sr) {
    const ctx = this.ctx;
    const { screen } = this._getHexScreen(q, r);
    const subSize = HEX_SIZE * HexMath.SUB_HEX_SCALE * this.camera.zoom;
    const offset = HexMath.subHexToPixel(sq, sr);
    const cx = screen.x + offset.x * this.camera.zoom;
    const cy = screen.y + offset.y * this.camera.zoom;
    const corners = HexMath.subHexCorners(cx, cy, subSize);

    this._traceHexPath(corners);
    ctx.fillStyle = SUB_HEX_HOVER_FILL;
    ctx.fill();
    ctx.strokeStyle = SUB_HEX_HOVER_STROKE;
    ctx.lineWidth = 1.5;
    ctx.stroke();
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
        // Pass sub-hex info for placement tools
        const hexWithSub = { q: hex.q, r: hex.r };
        if (this.hoveredSubHex && this._isPlacementTool()) {
          hexWithSub.sq = this.hoveredSubHex.q;
          hexWithSub.sr = this.hoveredSubHex.r;
        }
        this.toolManager.onMouseDown(hexWithSub);
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
      this.requestRender();
    }

    // Compute sub-hex when placement tool active
    if (this._isPlacementTool() && this.grid.hasTile(hex.q, hex.r)) {
      const world = HexMath.axialToPixel(hex.q, hex.r);
      const mouseWorld = this.screenToWorld(mx, my);
      const offsetX = mouseWorld.x - world.x;
      const offsetY = mouseWorld.y - world.y;
      const newSubHex = HexMath.pixelToSubHex(offsetX, offsetY);
      if (!this.hoveredSubHex || this.hoveredSubHex.q !== newSubHex.q || this.hoveredSubHex.r !== newSubHex.r) {
        this.hoveredSubHex = newSubHex;
        this.requestRender();
      }
    } else {
      if (this.hoveredSubHex !== null) {
        this.hoveredSubHex = null;
        this.requestRender();
      }
    }

    // Notify hex inspector of hovered hex/sub-hex
    if (this.onHexHover) {
      this.onHexHover(this.hoveredHex, this.hoveredSubHex);
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
    this.hoveredSubHex = null;
    if (this.onHexHover) {
      this.onHexHover(null, null);
    }
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
      const { q, r } = HexGrid.parseKey(key);
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
    const { corners } = this._getHexScreen(q, r);

    this._traceHexPath(corners);
    ctx.fillStyle = GHOST_FILL;
    ctx.fill();
    ctx.strokeStyle = GHOST_STROKE;
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
    // Account for sidebars. Subtract both left (#map-sidebar) and right (#sidebar) widths.
    const rightSidebar = parent.querySelector('#sidebar');
    const leftSidebar = parent.querySelector('#map-sidebar');
    const rightWidth = rightSidebar ? rightSidebar.offsetWidth : 0;
    const leftWidth = leftSidebar ? leftSidebar.offsetWidth : 0;
    this.canvas.width = parent.clientWidth - rightWidth - leftWidth;
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
      const { q, r } = HexGrid.parseKey(key);
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
