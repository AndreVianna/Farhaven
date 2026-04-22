// ============================================================
// HexCanvas — Rendering and Interaction (task-008)
// ============================================================

import { HEX_SIZE, HexMath } from './hex-math.js';
import { HexGrid, CATEGORY_COLORS, NATURAL_CATEGORIES, CATEGORY_TO_INT } from './hex-grid.js';
import { EditPropCommand, MovePropCommand, SetSpawnCommand } from './commands.js';
import { loadBiomeTextures, pickVariationIdx, pickRotationRadians } from './biome-textures.js';
import { ProjectContext } from './file-discovery.js';

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
//   - Prop badges: bold, min 5px, base 8px (prop count), min 4px base 6px (anomaly "!")
// Position offsets (fractions of HEX_SIZE * zoom):
//   - Spawn marker: 0.3 above center
//   - Prop indicators: 0.35 below center
//   - Prop badge: 0.3 right of center
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
  constructor(canvasElement, grid, camera, biomeColorMap, propColorMap) {
    this.canvas = canvasElement;
    this.ctx = canvasElement && typeof canvasElement.getContext === 'function'
      ? canvasElement.getContext('2d') : null;
    this.grid = grid;
    this.camera = camera;
    this.biomeColorMap = biomeColorMap;
    /** @type {Map<string, string>} Prop type -> CSS color string */
    this.propColorMap = propColorMap || new Map();
    this.selectedHex = null;
    this.hoveredHex = null;
    /** @type {Set<string>} Ghost hex positions (recomputed each render) */
    this._ghostSet = new Set();
    this.showCoordinates = false;
    /** Toggles for map display. When false, the corresponding overlay
     * is skipped during render. Persisted by the map-sidebar UI via
     * setter-style assignments; requestRender() picks up changes. */
    this.showElevationNumbers = true;
    /** Tint Heat/Cold/Oxygen hazard tiles red/cyan/green proportional
     *  to their temperature level. Off by default — the inspector
     *  spinner is enough for most editing, and the tint can clash
     *  with biome color when designers are matching palette. */
    this.showTemperatureOverlay = false;
    this.showPlacedProps = true;
    /** @type {Set<string>|null} If null (default) all props render. If a
     * Set, only props whose `type` (prop_id) is in the set render. Set by
     * the map-sidebar prop filter UI. */
    this.propTypeFilter = null;
    /** @type {{ q: number, r: number }|null} Sub-hex within hovered hex */
    this.hoveredSubHex = null;
    this.isPanning = false;
    this.panStart = null;
    this.spaceHeld = false;
    this.ctrlHeld = false;
    this.altHeld = false;
    this.toolManager = null;
    /** @type {function({q: number, r: number}|null, {q: number, r: number}|null):void|null} */
    this.onHexHover = null;
    this._renderRequested = false;
    this._mouseDown = false;
    /** @type {'color'|'texture'} How to fill biome hexes. 'texture' uses
     *  the same hash-picked variation + rotation the runtime renderer
     *  applies, so the editor preview matches in-game. */
    this.biomeRenderMode = 'color';
    /** @type {Map<string, HTMLImageElement[]>} biome stem -> loaded
     *  textures. Populated lazily as hexes are drawn in texture mode. */
    this._biomeTextures = new Map();
    /** @type {Set<string>} biome stems we've already requested. */
    this._biomeTexturesRequested = new Set();
    /** @type {Set<string>|null} Hex keys unreachable from spawn. Null = not computed. */
    this._unreachableSet = null;
    /** @type {{ q: number, r: number, edgeIdx: number }|null} Hovered edge for wall tool */
    this.hoveredEdge = null;

    /**
     * Drop every cached biome texture so the next render in Texture
     * mode re-fetches from the loader. Called after biome edits that
     * may have changed the terrain_textures list.
     */
    this.clearBiomeTextureCache = () => {
      this._biomeTextures.clear();
      this._biomeTexturesRequested.clear();
    };

    /** Invalidate the reachability cache (call after map load or tile edits). */
    this.invalidateReachability = () => { this._unreachableSet = null; };

    // --- Prop/spawn selection state ---
    /** @type {{ hexQ: number, hexR: number, propIndex: number }|null} */
    this.selectedProp = null;
    /** @type {boolean} */
    this.selectedSpawn = false;
    /** @type {'none'|'moving'|'rotating'} */
    this._dragMode = 'none';
    /** @type {{ sq: number, sr: number }|null} Preview position during move drag */
    this._movePreview = null;
    /** @type {number|null} Preview angle during rotation drag */
    this._previewRotation = null;
    /** @type {{ sq: number, sr: number }|null} Original position at drag start */
    this._dragStartPos = null;

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

    this.grid.onChange = () => {
      this._unreachableSet = null; // invalidate on tile change
      this.requestRender();
    };

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

  // --- Viewport culling ---

  /**
   * Compute the world-space bounding box of the visible viewport,
   * padded by 2 hex sizes so edge hexes and labels aren't clipped.
   * @returns {{ minX: number, maxX: number, minY: number, maxY: number }}
   */
  _getVisibleWorldBounds() {
    const pad = HEX_SIZE * 2;
    const topLeft = this.screenToWorld(-pad, -pad);
    const bottomRight = this.screenToWorld(
      this.canvas.width + pad,
      this.canvas.height + pad,
    );
    return {
      minX: topLeft.x,
      maxX: bottomRight.x,
      minY: topLeft.y,
      maxY: bottomRight.y,
    };
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

    // Viewport culling: only draw hexes whose world position falls
    // inside the visible screen area (padded by 2 hex sizes).
    const vb = this._getVisibleWorldBounds();

    // --- Phase 2: Ghost grid (behind real tiles) ---
    this._ghostSet = this._computeGhostSet(vb);
    for (const key of this._ghostSet) {
      const { q, r } = HexGrid.parseKey(key);
      this._drawGhostHex(q, r);
    }

    // --- Phase 3: Real hex backgrounds + overlays ---
    // Compute reachability (cached, invalidated on map load/edit)
    if (this._unreachableSet === null) {
      this._unreachableSet = this._computeUnreachable();
    }
    for (const [key, tile] of this.grid.getAllTiles()) {
      const { q, r } = HexGrid.parseKey(key);
      const wp = HexMath.axialToPixel(q, r);
      if (wp.x < vb.minX || wp.x > vb.maxX || wp.y < vb.minY || wp.y > vb.maxY) continue;
      this._drawHex(q, r, tile);
      if (this.showTemperatureOverlay && typeof tile.temperature === 'number' && tile.temperature > 0) {
        this._drawTemperatureOverlay(q, r, tile);
      }
      if (this.showElevationNumbers) this._drawElevationOverlay(q, r, tile);
      this._drawCliffEdges(q, r, tile);
      // Badges in the top of the hex — left=unreachable, right=hazard.
      // Badges are always on when the status applies (they're small,
      // unobtrusive, and don't overlap the central elevation number).
      // The `showTemperatureOverlay` toggle only controls the full-hex
      // tint, not the hazard badge.
      const isUnreachable = this._unreachableSet.has(key);
      const hazardLevel = (typeof tile.temperature === 'number' && tile.temperature > 0)
        ? tile.temperature | 0 : 0;
      if (isUnreachable || hazardLevel > 0) {
        this._drawHexBadges(q, r, tile, isUnreachable, hazardLevel);
      }
      if (this.showCoordinates) {
        this._drawCoordinateLabel(q, r);
      }
    }

    // --- Phase 3b: Props on top of all hex backgrounds (prevents clipping) ---
    if (this.showPlacedProps) {
      for (const [key, tile] of this.grid.getAllTiles()) {
        if (tile.props && tile.props.length > 0) {
          const { q, r } = HexGrid.parseKey(key);
          const wp = HexMath.axialToPixel(q, r);
          if (wp.x < vb.minX || wp.x > vb.maxX || wp.y < vb.minY || wp.y > vb.maxY) continue;
          this._drawSubHexOccupancy(q, r, tile);
        }
      }
    }

    // --- Phase 3c: Selected prop highlight ---
    this._drawSelectedPropHighlight();

    // --- Phase 4: Spawn marker ---
    const spawn = this.grid.meta.spawn;
    if (spawn && this.grid.hasTile(spawn[0], spawn[1])) {
      this._drawSpawnMarker(spawn[0], spawn[1]);
    }

    // --- Phase 4b: Selected spawn highlight ---
    this._drawSelectedSpawnHighlight();

    // --- Phase 5: Hover highlight (real tiles and ghost cells) ---
    if (this.hoveredHex) {
      const hKey = `${this.hoveredHex.q},${this.hoveredHex.r}`;
      if (this.grid.hasTile(this.hoveredHex.q, this.hoveredHex.r) || (this._ghostSet && this._ghostSet.has(hKey))) {
        this._drawHoverHighlight(this.hoveredHex.q, this.hoveredHex.r);
      }
    }

    // --- Phase 6: Sub-hex grid overlay on hovered hex (placement tools only) ---
    if (this.hoveredHex && this.toolManager && this._isSubHexTool()) {
      const hq = this.hoveredHex.q;
      const hr = this.hoveredHex.r;
      if (this.grid.hasTile(hq, hr) || (this._ghostSet && this._ghostSet.has(`${hq},${hr}`))) {
        this._drawSubHexGrid(hq, hr);
        if (this.hoveredSubHex) {
          this._drawSubHexHover(hq, hr, this.hoveredSubHex.q, this.hoveredSubHex.r);
        }
      }
    }

    // --- Phase 6b: Wall tool edge highlight ---
    if (this.hoveredEdge && this.toolManager && this.toolManager.activeToolType === 'wall') {
      const { q, r, edgeIdx } = this.hoveredEdge;
      const tile = this.grid.getTile(q, r);
      if (tile && tile.walls) {
        this._drawWallHighlight(q, r, edgeIdx, tile.walls[edgeIdx]);
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
    const { screen, size, corners } = this._getHexScreen(q, r);

    // Color path is the default and the fallback used while a tile's
    // textures haven't loaded yet. Elevation no longer tints the colour —
    // with the range now ±32000 there's no sensible brightness curve and
    // the old `*(1 + elev*0.05)` washed high-elevation tiles to white.
    // Water tiles use compound key for color lookup (B00005:leveled or B00005:flowing)
    const colorKey = tile.biome === 'B00005' && tile.waterType
      ? `${tile.biome}:${tile.waterType}` : tile.biome;
    const color = this.biomeColorMap.get(colorKey) || BIOME_FALLBACK_COLOR;

    this._traceHexPath(corners);
    ctx.fillStyle = color;
    ctx.fill();

    if (this.biomeRenderMode === 'texture' && tile.biome) {
      this._drawHexTexture(q, r, tile, screen, size, corners);
    }

    // Thin border
    ctx.strokeStyle = 'rgba(0,0,0,0.3)';
    ctx.lineWidth = 1;
    ctx.stroke();
  }

  /**
   * Sample the biome's textures (lazy-loaded) and paint one onto the
   * hex with the same hash-picked variation + rotation the runtime
   * uses. Falls back silently to the color underlay (already drawn)
   * while textures load.
   */
  _drawHexTexture(q, r, tile, screen, size, corners) {
    const stem = String(tile.biome);
    let textures = this._biomeTextures.get(stem);
    if (!textures) {
      // Kick off a one-shot load. When ready, ask for a re-render so
      // the new textures appear without the user needing to interact.
      if (!this._biomeTexturesRequested.has(stem)) {
        this._biomeTexturesRequested.add(stem);
        loadBiomeTextures(stem).then((imgs) => {
          if (imgs && imgs.length > 0) {
            this._biomeTextures.set(stem, imgs);
            this.requestRender();
          } else {
            // Mark with empty array so we don't re-attempt on every draw.
            this._biomeTextures.set(stem, []);
          }
        });
      }
      return;
    }
    if (textures.length === 0) return;

    const idx = pickVariationIdx(q, r, textures.length);
    const img = textures[idx];
    if (!img) return;
    const rot = pickRotationRadians(q, r);

    const ctx = this.ctx;
    ctx.save();
    // Clip to the hex polygon so the square texture only shows inside.
    this._traceHexPath(corners);
    ctx.clip();
    // Translate to centre, rotate, then draw a square covering the
    // full hex bbox (each axis -size .. +size). The texture's UV space
    // is hex-local [0,1] just like the runtime shader.
    ctx.translate(screen.x, screen.y);
    ctx.rotate(rot);
    ctx.drawImage(img, -size, -size, size * 2, size * 2);
    ctx.restore();
  }

  /**
   * Draw elevation number overlay.
   * @param {number} q
   * @param {number} r
   * @param {Object} tile
   * @returns {void}
   */
  _drawElevationOverlay(q, r, tile) {
    const ctx = this.ctx;
    const { screen } = this._getHexScreen(q, r);
    const fontSize = Math.max(8, 12 * this.camera.zoom);
    ctx.font = `bold ${fontSize}px sans-serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';

    if (tile.biome === 'B00005') {
      // Water tiles show "level/elevation" — both the surface height
      // (waterLevel) and the floor depth (elevation). Skip when both
      // are zero to avoid cluttering open ocean at sea level.
      const level = typeof tile.waterLevel === 'number' ? tile.waterLevel : tile.elevation;
      if (level !== 0 || tile.elevation !== 0) {
        ctx.fillStyle = 'rgba(160,200,255,0.85)';
        ctx.fillText(`${level}/${tile.elevation}`, screen.x, screen.y);
      }
    } else if (tile.elevation !== 0) {
      ctx.fillStyle = tile.elevation > 0 ? 'rgba(255,255,255,0.85)' : 'rgba(160,200,255,0.85)';
      ctx.fillText(String(tile.elevation), screen.x, screen.y);
    }
  }

  /**
   * Tint a hex a hazard-kind color (red for heat, cyan for cold,
   * green for oxygen_drain; other kinds fall back to magenta) with
   * intensity scaling with the tile's temperature level. Temperature
   * 4 is solidly visible but still semi-transparent so the biome
   * texture underneath stays readable.
   *
   * @param {number} q
   * @param {number} r
   * @param {{biome: string, temperature: number}} tile
   */
  _drawTemperatureOverlay(q, r, tile) {
    const biomeId = tile.biome || '';
    const entry = (typeof ProjectContext !== 'undefined' && ProjectContext.files && ProjectContext.files.biomes)
      ? ProjectContext.files.biomes.get(biomeId + '.tres')
      : null;
    const hazard = entry && entry.data && entry.data.hazard;
    const dtype = hazard && hazard.damage_type ? String(hazard.damage_type) : '';
    // damage_type → tint. Oxygen is a stat (drained by hypoxia
    // etc), not its own damage_type, so no entry for it here.
    const colors = {
      heat:    '255,60,40',
      cold:    '120,200,255',
      hypoxia: '100,220,120',
      poison:  '140,220,80',
      acid:    '230,220,60',
    };
    const rgb = colors[dtype] || '220,120,220';
    // Alpha ramps with temperature — cap table length is the
    // authoritative "max severity" for this cap; default to 4 if we
    // can't read it.
    const capLen = hazard && Array.isArray(hazard.health_damage) ? hazard.health_damage.length
                  : hazard && hazard.health_damage && hazard.health_damage.value
                    ? hazard.health_damage.value.length : 4;
    const n = Math.max(1, capLen);
    const t = Math.max(0, Math.min(1, tile.temperature / n));
    const alpha = 0.15 + 0.45 * t;

    const { screen, size, corners } = this._getHexScreen(q, r);
    this.ctx.beginPath();
    this.ctx.moveTo(corners[0].x, corners[0].y);
    for (let i = 1; i < 6; i++) this.ctx.lineTo(corners[i].x, corners[i].y);
    this.ctx.closePath();
    this.ctx.fillStyle = `rgba(${rgb},${alpha.toFixed(3)})`;
    this.ctx.fill();
  }

  /**
   * Compute reachability from spawn via BFS. Matches engine rules
   * (HexGrid.get_traversal):
   *   - Submersion: waterLevel - elevation > 3 blocks entry. Shallow
   *     water walks normally — old "water biome always blocks" rule
   *     is gone.
   *   - Slope: abs(elevation diff) > 4 blocks (symmetric, drops and
   *     climbs share the cap).
   * Lethal hazard tiles (temperature at cap level) are NOT treated
   * as unreachable — the player can enter, they just take heavy
   * damage while they stay. Movement is still possible, so the BFS
   * crosses through them.
   *
   * @returns {Set<string>} Set of unreachable hex keys
   */
  _computeUnreachable() {
    const spawn = this.grid.meta.spawn;
    if (!spawn || !this.grid.hasTile(spawn[0], spawn[1])) return new Set();

    const SUBMERSION_MAX = 3;
    const JUMP_MAX = 4;

    // Reusable submersion test — uses waterLevel when present,
    // otherwise falls back to elevation (=> diff 0, never blocks).
    const isSubmerged = (t) => {
      if (!t || typeof t.elevation !== 'number') return false;
      const lvl = typeof t.waterLevel === 'number' ? t.waterLevel : t.elevation;
      return (lvl - t.elevation) > SUBMERSION_MAX;
    };

    const spawnKey = `${spawn[0]},${spawn[1]}`;
    const reachable = new Set([spawnKey]);
    const queue = [{ q: spawn[0], r: spawn[1] }];
    let head = 0;

    while (head < queue.length) {
      const { q, r } = queue[head++];
      const tile = this.grid.getTile(q, r);
      if (!tile) continue;
      for (const dir of HexMath.DIRECTIONS) {
        const nq = q + dir.q, nr = r + dir.r;
        const nk = `${nq},${nr}`;
        if (reachable.has(nk)) continue;
        const neighbor = this.grid.getTile(nq, nr);
        if (!neighbor) continue;
        if (isSubmerged(neighbor)) continue;
        if (Math.abs(tile.elevation - neighbor.elevation) > JUMP_MAX) continue;
        reachable.add(nk);
        queue.push({ q: nq, r: nr });
      }
    }

    // Unreachable = all tiles not in reachable set, excluding tiles
    // that are themselves fully submerged (they're not reachable,
    // but we don't flag them with the red X overlay — they're
    // legitimately impassable water rather than a generation bug).
    const unreachable = new Set();
    for (const [key, tile] of this.grid.getAllTiles()) {
      if (isSubmerged(tile)) continue;
      if (!reachable.has(key)) unreachable.add(key);
    }
    return unreachable;
  }

  /**
   * Draw small status badges in the top portion of the hex.
   *   - Top-left: unreachable (red circle with ⊘)
   *   - Top-right: hazard (circle tinted by damage_type, showing level)
   * Badges never overlap the centred elevation/coordinate text and
   * scale with zoom.
   * @param {number} q
   * @param {number} r
   * @param {Object} tile
   * @param {boolean} isUnreachable
   * @param {number} hazardLevel - 0 = no hazard badge
   */
  _drawHexBadges(q, r, tile, isUnreachable, hazardLevel) {
    const { screen, size } = this._getHexScreen(q, r);
    const badgeR = Math.max(4, size * 0.18);
    const yOff = -size * 0.55;
    const xSpread = size * 0.4;
    if (isUnreachable) {
      this._drawUnreachableBadge(screen.x - xSpread, screen.y + yOff, badgeR);
    }
    if (hazardLevel > 0) {
      this._drawHazardBadge(screen.x + xSpread, screen.y + yOff, badgeR, tile, hazardLevel);
    }
  }

  /**
   * Small red badge with a white ⊘ glyph — marks a hex the player
   * can't reach from spawn under current traversal rules.
   */
  _drawUnreachableBadge(cx, cy, radius) {
    const ctx = this.ctx;
    ctx.beginPath();
    ctx.arc(cx, cy, radius, 0, Math.PI * 2);
    ctx.fillStyle = 'rgba(210,40,40,0.9)';
    ctx.fill();
    ctx.strokeStyle = 'rgba(255,255,255,0.85)';
    ctx.lineWidth = Math.max(1, radius * 0.2);
    ctx.stroke();
    // Diagonal slash for the ⊘ glyph.
    const d = radius * 0.65;
    ctx.beginPath();
    ctx.moveTo(cx - d, cy + d);
    ctx.lineTo(cx + d, cy - d);
    ctx.stroke();
  }

  /**
   * Small hazard badge — circle filled by the biome's damage_type
   * colour, with the current level number in the middle.
   */
  _drawHazardBadge(cx, cy, radius, tile, level) {
    const biomeId = tile.biome || '';
    const entry = (typeof ProjectContext !== 'undefined' && ProjectContext.files && ProjectContext.files.biomes)
      ? ProjectContext.files.biomes.get(biomeId + '.tres')
      : null;
    const hazard = entry && entry.data && entry.data.hazard;
    const dtype = hazard && hazard.damage_type ? String(hazard.damage_type) : '';
    const colors = {
      heat:    '255,60,40',
      cold:    '120,200,255',
      hypoxia: '100,220,120',
      poison:  '140,220,80',
      acid:    '230,220,60',
    };
    const rgb = colors[dtype] || '220,120,220';
    const ctx = this.ctx;

    ctx.beginPath();
    ctx.arc(cx, cy, radius, 0, Math.PI * 2);
    ctx.fillStyle = `rgba(${rgb},0.95)`;
    ctx.fill();
    ctx.strokeStyle = 'rgba(0,0,0,0.6)';
    ctx.lineWidth = Math.max(1, radius * 0.15);
    ctx.stroke();
    const fontSize = Math.max(8, radius * 1.2);
    ctx.font = `bold ${fontSize}px sans-serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = 'rgba(0,0,0,0.85)';
    ctx.fillText(String(level), cx, cy + radius * 0.05);
  }

  /**
   * Draw cliff edges based on the tile's walls array.
   * @param {number} q
   * @param {number} r
   * @param {Object} tile
   * @returns {void}
   */
  _drawCliffEdges(q, r, tile) {
    if (!tile.walls) return;
    const ctx = this.ctx;
    const { corners } = this._getHexScreen(q, r);

    // Map direction index (0-5 from DIRECTIONS) to corner edge index.
    // DIRECTIONS: E(0), NE(1), NW(2), W(3), SW(4), SE(5)
    // Corner edges (flat-top): edge i→(i+1) aligns with DIRECTIONS at (6-i)%6.
    const DIR_TO_EDGE = [0, 5, 4, 3, 2, 1];
    for (let dirIdx = 0; dirIdx < 6; dirIdx++) {
      if (!tile.walls[dirIdx]) continue;
      const edgeCorner = DIR_TO_EDGE[dirIdx];
      ctx.beginPath();
      ctx.moveTo(corners[edgeCorner].x, corners[edgeCorner].y);
      ctx.lineTo(corners[(edgeCorner + 1) % 6].x, corners[(edgeCorner + 1) % 6].y);
      ctx.strokeStyle = CLIFF_COLOR;
      ctx.lineWidth = 3 * this.camera.zoom;
      ctx.stroke();
    }
  }

  /**
   * Find the closest hex edge (direction index 0-5) to a world-space point.
   * Computes distance from the mouse to each of the 6 edge midpoints and
   * returns the direction index of the nearest one.
   * @param {number} q
   * @param {number} r
   * @param {number} worldX
   * @param {number} worldY
   * @returns {number} Direction index (0-5)
   */
  _closestEdge(q, r, worldX, worldY) {
    const center = HexMath.axialToPixel(q, r);
    // Edge midpoints are at the apothem distance in each direction.
    // For flat-top hex: edge d midpoint angle = 30° + 60° * edgeCornerIdx
    // DIRECTIONS → corner edge mapping: dir 0→edge(0,1), 1→edge(5,0), etc.
    const DIR_TO_EDGE = [0, 5, 4, 3, 2, 1];
    const apothem = HEX_SIZE * Math.cos(Math.PI / 6);
    let bestDir = 0;
    let bestDist = Infinity;
    for (let dirIdx = 0; dirIdx < 6; dirIdx++) {
      const edgeCorner = DIR_TO_EDGE[dirIdx];
      const midAngle = (edgeCorner * 60 + 30) * Math.PI / 180;
      const mx = center.x + Math.cos(midAngle) * apothem;
      const my = center.y + Math.sin(midAngle) * apothem;
      const dist = Math.hypot(worldX - mx, worldY - my);
      if (dist < bestDist) {
        bestDist = dist;
        bestDir = dirIdx;
      }
    }
    return bestDir;
  }

  /**
   * Draw a highlighted edge for the wall tool hover.
   * @param {number} q
   * @param {number} r
   * @param {number} edgeIdx - Direction index (0-5)
   * @param {boolean} hasWall - Whether this edge currently has a wall
   */
  _drawWallHighlight(q, r, edgeIdx, hasWall) {
    const ctx = this.ctx;
    const { corners } = this._getHexScreen(q, r);
    const DIR_TO_EDGE = [0, 5, 4, 3, 2, 1];
    const edgeCorner = DIR_TO_EDGE[edgeIdx];
    ctx.beginPath();
    ctx.moveTo(corners[edgeCorner].x, corners[edgeCorner].y);
    ctx.lineTo(corners[(edgeCorner + 1) % 6].x, corners[(edgeCorner + 1) % 6].y);
    // Green = will add wall, Red = will remove wall
    ctx.strokeStyle = hasWall ? 'rgba(255,100,100,0.9)' : 'rgba(100,255,100,0.9)';
    ctx.lineWidth = Math.max(3, 5 * this.camera.zoom);
    ctx.stroke();
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
    const spawn = this.grid.meta.spawn;
    const sq = spawn.length > 2 ? spawn[2] : 0;
    const sr = spawn.length > 3 ? spawn[3] : 0;
    const subOffset = HexMath.subHexToPixel(sq, sr);
    const cx = screen.x + subOffset.x * this.camera.zoom;
    const cy = screen.y + subOffset.y * this.camera.zoom;
    const size = 8 * this.camera.zoom;

    ctx.beginPath();
    ctx.arc(cx, cy, size, 0, Math.PI * 2);
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
    ctx.fillText('S', cx, cy);

    // Facing indicator line
    const facing = spawn.length >= 5 ? spawn[4] : 0;
    if (typeof facing === 'number') {
      const angleRad = (facing - 90) * Math.PI / 180;
      const lineLen = size * 1;
      ctx.beginPath();
      ctx.moveTo(cx, cy);
      ctx.lineTo(cx + Math.cos(angleRad) * lineLen, cy + Math.sin(angleRad) * lineLen);
      ctx.strokeStyle = 'rgba(255,255,255,0.7)';
      ctx.lineWidth = 1.5;
      ctx.stroke();
    }
  }

  // --- Sub-hex rendering ---

  /**
   * Check if the active tool operates at sub-hex resolution.
   * @returns {boolean}
   */
  _isSubHexTool() {
    if (!this.toolManager) return false;
    const t = this.toolManager.activeToolType;
    return t === 'select' || t === 'prop' || t === 'spawn' || t === 'eraser';
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
      // Type filter: when the sidebar restricts the visible prop set,
      // skip anything not in it. Matches against prop_id (prop.type).
      if (this.propTypeFilter && !this.propTypeFilter.has(prop.type)) continue;
      // Use per-prop color from propColorMap when available, else fall back to category color
      let color;
      const catInt = CATEGORY_TO_INT[prop.category];
      if (catInt != null && NATURAL_CATEGORIES.has(catInt) && this.propColorMap.has(prop.type)) {
        color = this.propColorMap.get(prop.type);
      } else {
        color = CATEGORY_COLORS[prop.category]
          ? CATEGORY_COLORS[prop.category].fill
          : CATEGORY_COLORS.plant.fill;
      }

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
        // Draw facing indicator on anchor sub-hex for structures
        if (typeof prop.rotation === 'number') {
          const anchorOffset = HexMath.subHexToPixel(prop.sq, prop.sr);
          const acx = screen.x + anchorOffset.x * this.camera.zoom;
          const acy = screen.y + anchorOffset.y * this.camera.zoom;
          const angleRad = (prop.rotation - 90) * Math.PI / 180;
          const lineLen = subSize * 1;
          ctx.beginPath();
          ctx.moveTo(acx, acy);
          ctx.lineTo(acx + Math.cos(angleRad) * lineLen, acy + Math.sin(angleRad) * lineLen);
          ctx.strokeStyle = 'rgba(255,255,255,0.7)';
          ctx.lineWidth = 1.5;
          ctx.stroke();
        }
      } else {
        const offset = HexMath.subHexToPixel(prop.sq, prop.sr);
        const cx = screen.x + offset.x * this.camera.zoom;
        const cy = screen.y + offset.y * this.camera.zoom;
        const corners = HexMath.subHexCorners(cx, cy, subSize);
        this._traceHexPath(corners);
        ctx.fillStyle = color;
        ctx.fill();

        // Draw facing indicator line
        if (typeof prop.rotation === 'number') {
          const angleRad = (prop.rotation - 90) * Math.PI / 180;
          const lineLen = subSize * 1;
          ctx.beginPath();
          ctx.moveTo(cx, cy);
          ctx.lineTo(cx + Math.cos(angleRad) * lineLen, cy + Math.sin(angleRad) * lineLen);
          ctx.strokeStyle = 'rgba(255,255,255,0.7)';
          ctx.lineWidth = 1.5;
          ctx.stroke();
        }
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

  // --- Selection highlight rendering ---

  /**
   * Draw highlight ring and rotation handle around the selected prop.
   * Also draws move preview ghost if dragging.
   * @returns {void}
   */
  _drawSelectedPropHighlight() {
    if (!this.selectedProp) return;
    const sp = this.selectedProp;
    const tile = this.grid.getTile(sp.hexQ, sp.hexR);
    if (!tile || !tile.props || !tile.props[sp.propIndex]) return;

    const ctx = this.ctx;
    const prop = tile.props[sp.propIndex];
    const subSize = HEX_SIZE * HexMath.SUB_HEX_SCALE * this.camera.zoom;

    // Draw selection ring around prop's sub-hex(es)
    const positions = prop.footprint
      ? prop.footprint.map(f => ({ sq: f.q, sr: f.r }))
      : [{ sq: prop.sq, sr: prop.sr }];

    for (const pos of positions) {
      const screenPos = this._subHexScreenPos(sp.hexQ, sp.hexR, pos.sq, pos.sr);
      const corners = HexMath.subHexCorners(screenPos.x, screenPos.y, subSize);
      this._traceHexPath(corners);
      ctx.strokeStyle = SELECTION_COLOR;
      ctx.lineWidth = 1.5;
      ctx.stroke();
    }

    // Draw rotation handle at facing line endpoint
    const anchorScreen = this._subHexScreenPos(sp.hexQ, sp.hexR, prop.sq, prop.sr);
    const rotation = this._dragMode === 'rotating' && this._previewRotation != null
      ? this._previewRotation
      : (typeof prop.rotation === 'number' ? prop.rotation : 0);
    const angleRad = (rotation - 90) * Math.PI / 180;
    const lineLen = 8 * this.camera.zoom * 2;
    const handleX = anchorScreen.x + Math.cos(angleRad) * lineLen;
    const handleY = anchorScreen.y + Math.sin(angleRad) * lineLen;

    // Draw facing line override during rotation preview
    if (this._dragMode === 'rotating' && this._previewRotation != null) {
      ctx.beginPath();
      ctx.moveTo(anchorScreen.x, anchorScreen.y);
      ctx.lineTo(handleX, handleY);
      ctx.strokeStyle = SELECTION_COLOR;
      ctx.lineWidth = 1.5;
      ctx.stroke();
    }

    // Handle circle
    ctx.beginPath();
    ctx.arc(handleX, handleY, 4 * this.camera.zoom, 0, Math.PI * 2);
    ctx.fillStyle = 'rgba(255,255,255,0.8)';
    ctx.fill();
    ctx.strokeStyle = SELECTION_COLOR;
    ctx.lineWidth = 1;
    ctx.stroke();

    // Move preview ghost — preview can now land on a different hex
    // (cross-hex drag). Fall back to the source hex for legacy previews
    // that only stored sub-hex coords.
    if (this._dragMode === 'moving' && this._movePreview) {
      const pq = typeof this._movePreview.q === 'number' ? this._movePreview.q : sp.hexQ;
      const pr = typeof this._movePreview.r === 'number' ? this._movePreview.r : sp.hexR;
      const previewScreen = this._subHexScreenPos(pq, pr, this._movePreview.sq, this._movePreview.sr);
      const previewCorners = HexMath.subHexCorners(previewScreen.x, previewScreen.y, subSize);
      this._traceHexPath(previewCorners);
      // Red tint when target tile doesn't exist or sub-hex is occupied,
      // so the user sees up front that releasing here will cancel.
      const targetTile = this.grid.getTile(pq, pr);
      const blocked = !targetTile
        || this._isSubHexOccupiedExcluding(targetTile, this._movePreview.sq, this._movePreview.sr, (pq === sp.hexQ && pr === sp.hexR) ? sp.propIndex : -1);
      ctx.fillStyle = blocked ? 'rgba(255,64,64,0.25)' : 'rgba(255,255,255,0.2)';
      ctx.fill();
      ctx.strokeStyle = blocked ? 'rgba(255,128,128,0.8)' : 'rgba(255,255,255,0.6)';
      ctx.lineWidth = 1.5;
      ctx.setLineDash([4, 4]);
      ctx.stroke();
      ctx.setLineDash([]);
    }
  }

  /**
   * Draw highlight ring and rotation handle around the selected spawn marker.
   * @returns {void}
   */
  _drawSelectedSpawnHighlight() {
    if (!this.selectedSpawn) return;
    const spawn = this.grid.meta.spawn;
    if (!spawn || !this.grid.hasTile(spawn[0], spawn[1])) return;

    const ctx = this.ctx;
    const sq = spawn.length > 2 ? spawn[2] : 0;
    const sr = spawn.length > 3 ? spawn[3] : 0;
    const facing = spawn.length >= 5 ? spawn[4] : 0;
    const screenPos = this._subHexScreenPos(spawn[0], spawn[1], sq, sr);
    const size = 8 * this.camera.zoom;

    // Selection ring
    ctx.beginPath();
    ctx.arc(screenPos.x, screenPos.y, size + 3, 0, Math.PI * 2);
    ctx.strokeStyle = SELECTION_COLOR;
    ctx.lineWidth = 1.5;
    ctx.stroke();

    // Rotation handle at facing line endpoint
    const rotation = this._dragMode === 'rotating' && this._previewRotation != null
      ? this._previewRotation : facing;
    const angleRad = (rotation - 90) * Math.PI / 180;
    const lineLen = size * 2;
    const handleX = screenPos.x + Math.cos(angleRad) * lineLen;
    const handleY = screenPos.y + Math.sin(angleRad) * lineLen;

    // Preview facing line during rotation drag
    if (this._dragMode === 'rotating' && this._previewRotation != null) {
      ctx.beginPath();
      ctx.moveTo(screenPos.x, screenPos.y);
      ctx.lineTo(handleX, handleY);
      ctx.strokeStyle = SELECTION_COLOR;
      ctx.lineWidth = 1.5;
      ctx.stroke();
    }

    // Handle circle
    ctx.beginPath();
    ctx.arc(handleX, handleY, 4 * this.camera.zoom, 0, Math.PI * 2);
    ctx.fillStyle = 'rgba(255,255,255,0.8)';
    ctx.fill();
    ctx.strokeStyle = SELECTION_COLOR;
    ctx.lineWidth = 1;
    ctx.stroke();

    // Move preview ghost
    if (this._dragMode === 'moving' && this._movePreview) {
      const previewScreen = this._subHexScreenPos(spawn[0], spawn[1], this._movePreview.sq, this._movePreview.sr);
      ctx.beginPath();
      ctx.arc(previewScreen.x, previewScreen.y, size, 0, Math.PI * 2);
      ctx.fillStyle = 'rgba(255,204,0,0.3)';
      ctx.fill();
      ctx.strokeStyle = 'rgba(255,255,255,0.6)';
      ctx.lineWidth = 1.5;
      ctx.setLineDash([4, 4]);
      ctx.stroke();
      ctx.setLineDash([]);
    }
  }

  // --- Prop/spawn selection helpers ---

  /**
   * Find a prop at the given sub-hex position within a tile.
   * @param {number} q - Hex q
   * @param {number} r - Hex r
   * @param {number} sq - Sub-hex q
   * @param {number} sr - Sub-hex r
   * @returns {{ propIndex: number, prop: Object }|null}
   */
  _findPropAtSubHex(q, r, sq, sr) {
    const tile = this.grid.getTile(q, r);
    if (!tile || !tile.props) return null;
    for (let i = 0; i < tile.props.length; i++) {
      const prop = tile.props[i];
      if (prop.sq === sq && prop.sr === sr) return { propIndex: i, prop };
      if (prop.footprint) {
        for (const f of prop.footprint) {
          if (f.q === sq && f.r === sr) return { propIndex: i, prop };
        }
      }
    }
    return null;
  }

  /**
   * Check if the given screen coordinates are near the rotation handle of a prop or spawn.
   * @param {number} screenX - Mouse screen X
   * @param {number} screenY - Mouse screen Y
   * @param {number} cx - Prop/spawn center screen X
   * @param {number} cy - Prop/spawn center screen Y
   * @param {number} rotation - Current rotation in degrees
   * @param {number} lineLen - Length of facing line in screen pixels
   * @returns {boolean}
   */
  _isNearRotationHandle(screenX, screenY, cx, cy, rotation, lineLen) {
    const angleRad = (rotation - 90) * Math.PI / 180;
    const handleX = cx + Math.cos(angleRad) * lineLen;
    const handleY = cy + Math.sin(angleRad) * lineLen;
    const dist = Math.hypot(screenX - handleX, screenY - handleY);
    return dist <= 10;
  }

  /**
   * Compute the screen position of a sub-hex center within a hex.
   * @param {number} q - Hex q
   * @param {number} r - Hex r
   * @param {number} sq - Sub-hex q
   * @param {number} sr - Sub-hex r
   * @returns {{ x: number, y: number }}
   */
  _subHexScreenPos(q, r, sq, sr) {
    const { screen } = this._getHexScreen(q, r);
    const subOffset = HexMath.subHexToPixel(sq, sr);
    return {
      x: screen.x + subOffset.x * this.camera.zoom,
      y: screen.y + subOffset.y * this.camera.zoom,
    };
  }

  /**
   * Compute angle from a center point to mouse position, normalized to [0, 360).
   * 0 degrees = north/up.
   * @param {number} cx - Center X (screen)
   * @param {number} cy - Center Y (screen)
   * @param {number} mx - Mouse X (screen)
   * @param {number} my - Mouse Y (screen)
   * @returns {number}
   */
  _angleFromCenter(cx, cy, mx, my) {
    const dx = mx - cx;
    const dy = my - cy;
    let angle = Math.atan2(dy, dx) * 180 / Math.PI + 90;
    angle = ((angle % 360) + 360) % 360;
    return angle;
  }

  /**
   * Clear prop/spawn selection state.
   * @returns {void}
   */
  clearPropSelection() {
    this.selectedProp = null;
    this.selectedSpawn = false;
    this._dragMode = 'none';
    this._movePreview = null;
    this._previewRotation = null;
    this._dragStartPos = null;
  }

  /**
   * Handle mouse down for the Select tool: prop/spawn selection, drag initiation.
   * @param {{ q: number, r: number }} hex
   * @param {number} mx - Mouse screen X
   * @param {number} my - Mouse screen Y
   * @returns {void}
   */
  _handleSelectToolMouseDown(hex, mx, my) {
    // Compute sub-hex under cursor
    const world = HexMath.axialToPixel(hex.q, hex.r);
    const mouseWorld = this.screenToWorld(mx, my);
    const offsetX = mouseWorld.x - world.x;
    const offsetY = mouseWorld.y - world.y;
    const subHex = HexMath.pixelToSubHex(offsetX, offsetY);
    const subSize = HEX_SIZE * HexMath.SUB_HEX_SCALE * this.camera.zoom;

    // --- Priority 1: Check rotation handle of ALREADY-SELECTED prop/spawn ---
    // The selected handle is drawn at extended length and may be outside the prop's sub-hex,
    // so we must check it first before any new-selection logic.
    if (this.selectedSpawn) {
      const spawn = this.grid.meta.spawn;
      if (spawn) {
        const spawnSq = spawn.length > 2 ? spawn[2] : 0;
        const spawnSr = spawn.length > 3 ? spawn[3] : 0;
        const spawnRot = spawn.length >= 5 ? spawn[4] : 0;
        const spawnScreen = this._subHexScreenPos(spawn[0], spawn[1], spawnSq, spawnSr);
        const spawnLineLen = 8 * this.camera.zoom * 2; // matches selected render length
        if (this._isNearRotationHandle(mx, my, spawnScreen.x, spawnScreen.y, spawnRot, spawnLineLen)) {
          this._dragMode = 'rotating';
          this._previewRotation = spawnRot;
          return;
        }
      }
    }
    if (this.selectedProp) {
      const sp = this.selectedProp;
      const tile = this.grid.getTile(sp.hexQ, sp.hexR);
      if (tile && tile.props && tile.props[sp.propIndex]) {
        const prop = tile.props[sp.propIndex];
        const propScreen = this._subHexScreenPos(sp.hexQ, sp.hexR, prop.sq, prop.sr);
        const propLineLen = 8 * this.camera.zoom * 2; // matches selected render length
        if (typeof prop.rotation === 'number' &&
            this._isNearRotationHandle(mx, my, propScreen.x, propScreen.y, prop.rotation, propLineLen)) {
          this._dragMode = 'rotating';
          this._previewRotation = prop.rotation;
          return;
        }
      }
    }

    // --- Priority 2: Check spawn body ---
    const spawn = this.grid.meta.spawn;
    if (spawn && spawn[0] === hex.q && spawn[1] === hex.r) {
      const spawnSq = spawn.length > 2 ? spawn[2] : 0;
      const spawnSr = spawn.length > 3 ? spawn[3] : 0;
      if (subHex.q === spawnSq && subHex.r === spawnSr) {
        this.selectedSpawn = true;
        this.selectedProp = null;
        this._dragMode = 'moving';
        this._dragStartPos = { sq: spawnSq, sr: spawnSr };
        this._movePreview = null;
        return;
      }
    }

    // --- Priority 3: Check props ---
    const found = this._findPropAtSubHex(hex.q, hex.r, subHex.q, subHex.r);
    if (found) {
      this.selectedProp = { hexQ: hex.q, hexR: hex.r, propIndex: found.propIndex };
      this.selectedSpawn = false;
      this._dragMode = 'moving';
      this._dragStartPos = { sq: found.prop.sq, sr: found.prop.sr };
      this._movePreview = null;
      return;
    }

    // Nothing hit: clear selection
    this.clearPropSelection();
  }

  /**
   * Handle mouse move during prop/spawn drag in select mode.
   * @param {number} mx - Mouse screen X
   * @param {number} my - Mouse screen Y
   * @returns {void}
   */
  _handleSelectToolMouseMove(mx, my) {
    if (this._dragMode === 'moving') {
      // Compute which hex and sub-hex the mouse is over.
      const hex = this.screenToHex(mx, my);
      const world = HexMath.axialToPixel(hex.q, hex.r);
      const mouseWorld = this.screenToWorld(mx, my);
      const subHex = HexMath.pixelToSubHex(mouseWorld.x - world.x, mouseWorld.y - world.y);

      // Spawn stays locked to its hex — it's the map's anchor and we
      // don't auto-create tiles to hold it. Props can cross-hex drag
      // as long as the target tile exists (canvas commit validates).
      if (this.selectedSpawn) {
        const targetQ = this.grid.meta.spawn ? this.grid.meta.spawn[0] : hex.q;
        const targetR = this.grid.meta.spawn ? this.grid.meta.spawn[1] : hex.r;
        if (hex.q !== targetQ || hex.r !== targetR) return;
      }

      if (!this._movePreview
          || this._movePreview.q !== hex.q || this._movePreview.r !== hex.r
          || this._movePreview.sq !== subHex.q || this._movePreview.sr !== subHex.r) {
        this._movePreview = { q: hex.q, r: hex.r, sq: subHex.q, sr: subHex.r };
        this.requestRender();
      }
    } else if (this._dragMode === 'rotating') {
      // Compute angle from entity center to mouse
      let cx, cy;
      if (this.selectedProp) {
        const sp = this.selectedProp;
        const tile = this.grid.getTile(sp.hexQ, sp.hexR);
        if (!tile || !tile.props[sp.propIndex]) return;
        const prop = tile.props[sp.propIndex];
        const pos = this._subHexScreenPos(sp.hexQ, sp.hexR, prop.sq, prop.sr);
        cx = pos.x;
        cy = pos.y;
      } else if (this.selectedSpawn) {
        const spawn = this.grid.meta.spawn;
        if (!spawn) return;
        const spawnSq = spawn.length > 2 ? spawn[2] : 0;
        const spawnSr = spawn.length > 3 ? spawn[3] : 0;
        const pos = this._subHexScreenPos(spawn[0], spawn[1], spawnSq, spawnSr);
        cx = pos.x;
        cy = pos.y;
      } else {
        return;
      }

      const newAngle = this._angleFromCenter(cx, cy, mx, my);
      if (this._previewRotation !== newAngle) {
        this._previewRotation = newAngle;
        this.requestRender();
      }
    }
  }

  /**
   * Handle mouse up: commit prop/spawn move or rotation.
   * @param {number} mx - Mouse screen X
   * @param {number} my - Mouse screen Y
   * @returns {void}
   */
  _handleSelectToolMouseUp(mx, my) {
    if (this._dragMode === 'none') return;
    const cmdHistory = this.toolManager ? this.toolManager.commandHistory : null;
    if (!cmdHistory) {
      this._dragMode = 'none';
      this._movePreview = null;
      this._previewRotation = null;
      return;
    }

    if (this._dragMode === 'moving') {
      // Compute final hex + sub-hex from mouse position
      const hex = this.screenToHex(mx, my);
      const world = HexMath.axialToPixel(hex.q, hex.r);
      const mouseWorld = this.screenToWorld(mx, my);
      const newSub = HexMath.pixelToSubHex(mouseWorld.x - world.x, mouseWorld.y - world.y);

      if (this.selectedProp) {
        const sp = this.selectedProp;
        const srcTile = this.grid.getTile(sp.hexQ, sp.hexR);
        if (srcTile && srcTile.props[sp.propIndex]) {
          const prop = srcTile.props[sp.propIndex];
          const sameHex = (hex.q === sp.hexQ && hex.r === sp.hexR);
          const dstTile = this.grid.getTile(hex.q, hex.r);
          const moved = !sameHex || newSub.q !== prop.sq || newSub.r !== prop.sr;

          if (moved && dstTile) {
            // Occupancy at destination: if same hex, exclude our own
            // prop; if cross-hex, no exclusion.
            const occupied = this._isSubHexOccupiedExcluding(
              dstTile, newSub.q, newSub.r, sameHex ? sp.propIndex : -1);
            if (!occupied) {
              if (sameHex) {
                // In-hex move — keep the cheaper EditPropCommand so
                // footprint offsets can be translated in place.
                const oldValues = { sq: prop.sq, sr: prop.sr };
                const newValues = { sq: newSub.q, sr: newSub.r };
                if (prop.footprint) {
                  const dq = newSub.q - prop.sq;
                  const dr = newSub.r - prop.sr;
                  oldValues.footprint = prop.footprint.map(f => ({ q: f.q, r: f.r }));
                  newValues.footprint = prop.footprint.map(f => ({ q: f.q + dq, r: f.r + dr }));
                }
                const cmd = new EditPropCommand(this.grid, sp.hexQ, sp.hexR, sp.propIndex, oldValues, newValues);
                cmdHistory.execute(cmd);
                this.selectedProp = { hexQ: sp.hexQ, hexR: sp.hexR, propIndex: sp.propIndex };
              } else {
                // Cross-hex move — footprinted props skip the cross-hex
                // drag because translating absolute sub_hex coords
                // across hex boundaries isn't well-defined here.
                if (!prop.footprint) {
                  const cmd = new MovePropCommand(
                    this.grid, sp.hexQ, sp.hexR, sp.propIndex,
                    hex.q, hex.r, { sq: newSub.q, sr: newSub.r });
                  cmdHistory.execute(cmd);
                  // Re-anchor the selection to the new tile. props.length-1
                  // matches MovePropCommand.execute pushing to the end.
                  const newTile = this.grid.getTile(hex.q, hex.r);
                  if (newTile) {
                    this.selectedProp = { hexQ: hex.q, hexR: hex.r, propIndex: newTile.props.length - 1 };
                  }
                }
              }
            }
          }
        }
      } else if (this.selectedSpawn) {
        // Spawn drag still locked to the spawn's hex (see MouseMove).
        const spawn = this.grid.meta.spawn;
        const targetQ = spawn ? spawn[0] : 0;
        const targetR = spawn ? spawn[1] : 0;
        if (hex.q === targetQ && hex.r === targetR) {
          const spawn = this.grid.meta.spawn;
          if (spawn) {
            const oldSq = spawn.length > 2 ? spawn[2] : 0;
            const oldSr = spawn.length > 3 ? spawn[3] : 0;
            if (newSub.q !== oldSq || newSub.r !== oldSr) {
              const oldSpawn = [...spawn];
              const facing = spawn.length >= 5 ? spawn[4] : 0;
              const newSpawn = [spawn[0], spawn[1], newSub.q, newSub.r, facing];
              const cmd = new SetSpawnCommand(this.grid, oldSpawn, newSpawn);
              cmdHistory.execute(cmd);
            }
          }
        }
      }
    } else if (this._dragMode === 'rotating') {
      if (this._previewRotation != null) {
        const newAngle = Math.round(this._previewRotation) % 360;

        if (this.selectedProp) {
          const sp = this.selectedProp;
          const tile = this.grid.getTile(sp.hexQ, sp.hexR);
          if (tile && tile.props[sp.propIndex]) {
            const prop = tile.props[sp.propIndex];
            const oldRot = typeof prop.rotation === 'number' ? prop.rotation : 0;
            if (newAngle !== oldRot) {
              const cmd = new EditPropCommand(this.grid, sp.hexQ, sp.hexR, sp.propIndex,
                { rotation: oldRot }, { rotation: newAngle });
              cmdHistory.execute(cmd);
            }
          }
        } else if (this.selectedSpawn) {
          const spawn = this.grid.meta.spawn;
          if (spawn) {
            const oldFacing = spawn.length >= 5 ? spawn[4] : 0;
            if (newAngle !== oldFacing) {
              const oldSpawn = [...spawn];
              const sq = spawn.length > 2 ? spawn[2] : 0;
              const sr = spawn.length > 3 ? spawn[3] : 0;
              const newSpawn = [spawn[0], spawn[1], sq, sr, newAngle];
              const cmd = new SetSpawnCommand(this.grid, oldSpawn, newSpawn);
              cmdHistory.execute(cmd);
            }
          }
        }
      }
    }

    this._dragMode = 'none';
    this._movePreview = null;
    this._previewRotation = null;
    this._dragStartPos = null;
    this.requestRender();
  }

  /**
   * Check if a sub-hex is occupied by any prop other than the one at excludeIndex.
   * @param {Object} tile
   * @param {number} sq
   * @param {number} sr
   * @param {number} excludeIndex
   * @returns {boolean}
   */
  _isSubHexOccupiedExcluding(tile, sq, sr, excludeIndex) {
    if (!tile.props) return false;
    for (let i = 0; i < tile.props.length; i++) {
      if (i === excludeIndex) continue;
      const p = tile.props[i];
      if (p.sq === sq && p.sr === sr) return true;
      if (p.footprint) {
        for (const f of p.footprint) {
          if (f.q === sq && f.r === sr) return true;
        }
      }
    }
    return false;
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

    // Right-click on the elevation tool is a dedicated decrement gesture
    // (left-click = +1, right-click = -1). Intercept before the generic
    // "right-click = pan" path so the drag batches with the same brush.
    const isElevation = this.toolManager && this.toolManager.activeToolType === 'elevation';
    if (event.button === 2 && isElevation && this.toolManager.activeTool) {
      // Authoritative modifier read from the MouseEvent — matches the
      // left-click path below. Previously OR'd with keyboard-tracked
      // state to cover browsers that consume Alt for native bindings,
      // but that let stale `this.altHeld=true` leak into later clicks
      // and caused the border-tile bug (2026-04-20). Trust the event.
      this.altHeld = event.altKey;
      this.ctrlHeld = event.ctrlKey;
      this.toolManager.altHeld = this.altHeld;
      this.toolManager.ctrlHeld = this.ctrlHeld;
      this.toolManager.activeTool.delta = -1;
      const hex = this.screenToHex(mx, my);
      this.selectedHex = { q: hex.q, r: hex.r };
      this._mouseDown = true;
      this.toolManager.onMouseDown({ q: hex.q, r: hex.r });
      event.preventDefault();
      this.requestRender();
      return;
    }

    // Middle-click, right-click (non-elevation), or space+left-click: pan
    if (event.button === 1 || event.button === 2 || (event.button === 0 && this.spaceHeld)) {
      this.isPanning = true;
      this.panStart = { x: event.clientX, y: event.clientY };
      event.preventDefault();
      return;
    }

    // Left click
    if (event.button === 0) {
      this._mouseDown = true;
      const hex = this.screenToHex(mx, my);
      // Wall tool: don't update selection (it blocks the wall highlight)
      if (!this.toolManager || this.toolManager.activeToolType !== 'wall') {
        this.selectedHex = { q: hex.q, r: hex.r };
      }

      // --- Select tool: prop/spawn interaction ---
      if (this.toolManager && this.toolManager.activeToolType === 'select') {
        // Ensure back-reference for selection clearing on tool switch
        if (!this.toolManager.canvas) this.toolManager.canvas = this;
        if (this.grid.hasTile(hex.q, hex.r)) {
          this._handleSelectToolMouseDown(hex, mx, my);
        } else {
          this.clearPropSelection();
        }
      }

      if (this.toolManager) {
        if (isElevation && this.toolManager.activeTool) {
          this.toolManager.activeTool.delta = 1;
        }
        // Pass sub-hex or edge info depending on tool
        const hexWithExtra = { q: hex.q, r: hex.r };
        if (this.hoveredSubHex && this._isSubHexTool()) {
          hexWithExtra.sq = this.hoveredSubHex.q;
          hexWithExtra.sr = this.hoveredSubHex.r;
        }
        if (this.hoveredEdge && this.toolManager.activeToolType === 'wall') {
          hexWithExtra.edgeIdx = this.hoveredEdge.edgeIdx;
        }
        // Authoritative modifier read from the MouseEvent — survives
        // any missed keydown (focus loss, browser / OS intercept).
        this.ctrlHeld = event.ctrlKey;
        this.altHeld = event.altKey;
        this.toolManager.ctrlHeld = this.ctrlHeld;
        this.toolManager.altHeld = this.altHeld;
        this.toolManager.onMouseDown(hexWithExtra);
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
    if (this._isSubHexTool() && this.grid.hasTile(hex.q, hex.r)) {
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

    // Compute hovered edge for wall tool
    if (this.toolManager && this.toolManager.activeToolType === 'wall' && this.grid.hasTile(hex.q, hex.r)) {
      const mouseWorld = this.screenToWorld(mx, my);
      const edgeIdx = this._closestEdge(hex.q, hex.r, mouseWorld.x, mouseWorld.y);
      if (!this.hoveredEdge || this.hoveredEdge.q !== hex.q || this.hoveredEdge.r !== hex.r || this.hoveredEdge.edgeIdx !== edgeIdx) {
        this.hoveredEdge = { q: hex.q, r: hex.r, edgeIdx };
        this.requestRender();
      }
    } else if (this.hoveredEdge) {
      this.hoveredEdge = null;
      this.requestRender();
    }

    // Notify hex inspector of hovered hex/sub-hex
    if (this.onHexHover) {
      this.onHexHover(this.hoveredHex, this.hoveredSubHex);
    }

    // Handle prop/spawn drag (select tool)
    if (this._mouseDown && this._dragMode !== 'none' && this.toolManager &&
        this.toolManager.activeToolType === 'select') {
      this._handleSelectToolMouseMove(mx, my);
    }

    // Ctrl+hover paint: apply tool on hover without clicking.
    // Only for DragBrushTool-based tools (biome) that have drag state.
    // DeleteHexTool uses simple onMouseDown per hex.
    if (this.ctrlHeld && this.toolManager && !this._mouseDown) {
      const tt = this.toolManager.activeToolType;
      const tool = this.toolManager.activeTool;
      if (tt === 'biome' && tool && typeof tool._isDragging !== 'undefined') {
        if (!tool._isDragging) {
          tool._isDragging = true;
          tool._visited.clear();
          tool._dragCommands = [];
        }
        this.toolManager.onMouseMove(hex);
      } else if (tt === 'delete_hex' && tool) {
        tool.onMouseDown(hex);
      }
    }

    // Forward to tool during drag. Refresh the modifier state from
    // the live MouseEvent so each drag step respects the current
    // Alt/Ctrl — user can press or release Alt mid-drag to switch
    // between water surface / floor editing on-the-fly.
    if (this._mouseDown && this.toolManager) {
      this.ctrlHeld = event.ctrlKey;
      this.altHeld = event.altKey;
      this.toolManager.ctrlHeld = this.ctrlHeld;
      this.toolManager.altHeld = this.altHeld;
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

      // Commit prop/spawn drag if active
      if (this._dragMode !== 'none' && this.toolManager &&
          this.toolManager.activeToolType === 'select') {
        this._handleSelectToolMouseUp(mx, my);
      }

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

    // Multiplicative zoom: 10% per scroll step, feels natural at any level
    const factor = event.deltaY > 0 ? 0.9 : 1.1;
    this.camera.zoom = Math.max(0.03, Math.min(6.0, this.camera.zoom * factor));

    // Adjust offsets so world point stays under cursor
    this.camera.offsetX = mx - worldBefore.x * this.camera.zoom;
    this.camera.offsetY = my - worldBefore.y * this.camera.zoom;

    this.requestRender();
  }

  /** @param {KeyboardEvent} event */
  _onKeyDown(event) {
    if (event.key === ' ') this.spaceHeld = true;
    if (event.key === 'Control') this.ctrlHeld = true;
    if (event.key === 'Alt') this.altHeld = true;
  }

  /** @param {KeyboardEvent} event */
  _onKeyUp(event) {
    if (event.key === ' ') this.spaceHeld = false;
    if (event.key === 'Alt') {
      this.altHeld = false;
      if (this.toolManager) this.toolManager.altHeld = false;
    }
    if (event.key === 'Control') {
      this.ctrlHeld = false;
      if (this.toolManager) {
        this.toolManager.ctrlHeld = false;
        // Commit any Ctrl+hover paint batch
        if (this.toolManager.activeTool && this.toolManager.activeTool._isDragging) {
          this.toolManager.onMouseUp(null);
        }
        // Clear pinch accumulators on Ctrl release
        if (this.toolManager.activeTool && this.toolManager.activeTool._pinchAccum) {
          this.toolManager.activeTool._pinchAccum.clear();
        }
      }
    }
  }

  /** @param {MouseEvent} event */
  _onContextMenu(event) {
    event.preventDefault();
    // Dispatch a right-click on a placed prop to whoever registered
    // onPropContextMenu — used by app.js to open the override panel
    // (feature-011). Anything else is swallowed so the browser menu
    // doesn't interrupt the editor.
    if (typeof this.onPropContextMenu !== 'function') return;
    const rect = this.canvas.getBoundingClientRect();
    const mx = event.clientX - rect.left;
    const my = event.clientY - rect.top;
    const hex = this.screenToHex(mx, my);
    const world = HexMath.axialToPixel(hex.q, hex.r);
    const mouseWorld = this.screenToWorld(mx, my);
    const subHex = HexMath.pixelToSubHex(mouseWorld.x - world.x, mouseWorld.y - world.y);
    const found = this._findPropAtSubHex(hex.q, hex.r, subHex.q, subHex.r);
    if (!found) return;
    this.onPropContextMenu({
      hexQ: hex.q,
      hexR: hex.r,
      propIndex: found.propIndex,
      prop: found.prop,
      screenX: event.clientX,
      screenY: event.clientY,
    });
  }

  // --- Ghost Grid ---

  /**
   * Compute the set of empty hex positions adjacent to visible tiles.
   * When `bounds` is provided, only tiles inside the viewport (with extra
   * padding for ghost neighbors just outside) are considered.
   * @param {{ minX: number, maxX: number, minY: number, maxY: number }} [bounds]
   * @returns {Set<string>} Set of "q,r" keys for ghost positions
   */
  _computeGhostSet(bounds) {
    const ghosts = new Set();
    // Expand bounds by 3× hex size so ghosts just outside the viewport
    // (neighbors of visible tiles) are included.
    const pad = HEX_SIZE * 3;
    const useBounds = !!bounds;
    const bMinX = useBounds ? bounds.minX - pad : 0;
    const bMaxX = useBounds ? bounds.maxX + pad : 0;
    const bMinY = useBounds ? bounds.minY - pad : 0;
    const bMaxY = useBounds ? bounds.maxY + pad : 0;
    for (const key of this.grid.tiles.keys()) {
      const { q, r } = HexGrid.parseKey(key);
      if (useBounds) {
        const wp = HexMath.axialToPixel(q, r);
        if (wp.x < bMinX || wp.x > bMaxX || wp.y < bMinY || wp.y > bMaxY) continue;
      }
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
  /**
   * Center camera on spawn point at 100% zoom.
   */
  centerOnSpawn() {
    const spawn = this.grid.meta.spawn;
    const sq = spawn ? spawn[0] : 0;
    const sr = spawn ? spawn[1] : 0;
    const world = HexMath.axialToPixel(sq, sr);
    this.camera.zoom = 1.0;
    this.camera.offsetX = this.canvas.width / 2 - world.x * this.camera.zoom;
    this.camera.offsetY = this.canvas.height / 2 - world.y * this.camera.zoom;
    this.requestRender();
  }

  /**
   * Zoom and pan to fit all tiles in view with padding.
   * @param {number} [padding=40]
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
    this.camera.zoom = Math.min(scaleX, scaleY, 6.0);
    this.camera.zoom = Math.max(this.camera.zoom, 0.03);

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
