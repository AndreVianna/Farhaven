/* Farhaven Editor — interactive hex canvas (SVG) */

const { useState, useRef, useEffect, useMemo, useCallback } = React;

const HEX_SIZE = 28;
const SQRT3 = Math.sqrt(3);

// Flat-top axial -> pixel
function hexToPixel(q, r, size = HEX_SIZE) {
  const x = size * (3 / 2) * q;
  const y = size * (SQRT3 / 2 * q + SQRT3 * r);
  return [x, y];
}

// Pixel -> axial (with cube rounding)
function pixelToHex(x, y, size = HEX_SIZE) {
  const q = (2 / 3 * x) / size;
  const r = (-1 / 3 * x + SQRT3 / 3 * y) / size;
  // cube round
  let cx = q, cz = r, cy = -cx - cz;
  let rx = Math.round(cx), rz = Math.round(cz), ry = Math.round(cy);
  const dx = Math.abs(rx - cx), dy = Math.abs(ry - cy), dz = Math.abs(rz - cz);
  if (dx > dy && dx > dz) rx = -ry - rz;
  else if (dy > dz)       ry = -rx - rz;
  else                    rz = -rx - ry;
  return [rx, rz];
}

function hexCorners(cx, cy, size = HEX_SIZE) {
  const pts = [];
  for (let i = 0; i < 6; i++) {
    const a = (Math.PI / 3) * i; // flat-top: 0, 60, 120, ...
    pts.push([cx + size * Math.cos(a), cy + size * Math.sin(a)]);
  }
  return pts;
}

function hexPath(cx, cy, size = HEX_SIZE) {
  return hexCorners(cx, cy, size).map(([x, y], i) => (i === 0 ? `M${x.toFixed(2)} ${y.toFixed(2)}` : `L${x.toFixed(2)} ${y.toFixed(2)}`)).join('') + 'Z';
}

// Darken / lighten a hex color by a delta in [-1..1]
function shadeHex(hex, delta) {
  const n = parseInt(hex.slice(1), 16);
  const r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
  const f = (c) => {
    if (delta > 0) return Math.round(c + (255 - c) * delta);
    return Math.round(c * (1 + delta));
  };
  return '#' + [f(r), f(g), f(b)].map(v => v.toString(16).padStart(2, '0')).join('');
}

window.HEX = { HEX_SIZE, SQRT3, hexToPixel, pixelToHex, hexCorners, hexPath, shadeHex };

// ============================================================
// HexCanvas
// ============================================================

function HexCanvas({
  map, selected, onSelect, onPaint, activeTool, activeBiome, activeProp,
  showCoords, showElevationNumbers, canvasStyle, showLayers,
  onHoverChange, onViewChange,
}) {
  const wrapRef = useRef(null);
  const svgRef = useRef(null);
  const [view, setView] = useState({ cx: 0, cy: 0, zoom: 1 });
  const [size, setSize] = useState({ w: 800, h: 600 });
  const [hover, setHover] = useState(null);
  const isDown = useRef(false);
  const panStart = useRef(null);
  const isPanning = useRef(false);

  // Resize observer
  useEffect(() => {
    if (!wrapRef.current) return;
    const ro = new ResizeObserver(entries => {
      for (const e of entries) {
        setSize({ w: e.contentRect.width, h: e.contentRect.height });
      }
    });
    ro.observe(wrapRef.current);
    return () => ro.disconnect();
  }, []);

  // Report view for minimap
  useEffect(() => {
    onViewChange && onViewChange({ ...view, w: size.w, h: size.h });
  }, [view, size]);

  // Wheel zoom
  const onWheel = (e) => {
    e.preventDefault();
    const rect = wrapRef.current.getBoundingClientRect();
    const mx = e.clientX - rect.left - size.w / 2;
    const my = e.clientY - rect.top - size.h / 2;
    setView(v => {
      const factor = e.deltaY < 0 ? 1.12 : 1 / 1.12;
      const nz = Math.max(0.4, Math.min(2.4, v.zoom * factor));
      const realFactor = nz / v.zoom;
      const ncx = mx - (mx - v.cx) * realFactor;
      const ncy = my - (my - v.cy) * realFactor;
      return { cx: ncx, cy: ncy, zoom: nz };
    });
  };

  useEffect(() => {
    const el = wrapRef.current;
    if (!el) return;
    el.addEventListener('wheel', onWheel, { passive: false });
    return () => el.removeEventListener('wheel', onWheel);
  }, [size]);

  const clientToHex = (clientX, clientY) => {
    const rect = wrapRef.current.getBoundingClientRect();
    const px = (clientX - rect.left - size.w / 2 - view.cx) / view.zoom;
    const py = (clientY - rect.top - size.h / 2 - view.cy) / view.zoom;
    return pixelToHex(px, py);
  };

  const onMouseDown = (e) => {
    if (e.button === 1 || e.button === 2 || e.shiftKey) {
      isPanning.current = true;
      panStart.current = { x: e.clientX, y: e.clientY, cx: view.cx, cy: view.cy };
      e.preventDefault();
      return;
    }
    isDown.current = true;
    const [q, r] = clientToHex(e.clientX, e.clientY);
    if (activeTool === 'cursor') onSelect && onSelect(q, r);
    else onPaint && onPaint(q, r, e);
  };

  const onMouseMove = (e) => {
    if (isPanning.current && panStart.current) {
      const dx = e.clientX - panStart.current.x;
      const dy = e.clientY - panStart.current.y;
      setView(v => ({ ...v, cx: panStart.current.cx + dx, cy: panStart.current.cy + dy }));
      return;
    }
    const [q, r] = clientToHex(e.clientX, e.clientY);
    const key = `${q},${r}`;
    const tile = map.tiles[key];
    const rect = wrapRef.current.getBoundingClientRect();
    const local = { x: e.clientX - rect.left, y: e.clientY - rect.top };
    setHover({ q, r, tile, x: local.x, y: local.y });
    onHoverChange && onHoverChange({ q, r, tile });
    if (isDown.current && activeTool !== 'cursor') {
      onPaint && onPaint(q, r, e);
    }
  };

  const onMouseUp = () => {
    isDown.current = false;
    isPanning.current = false;
    panStart.current = null;
  };
  const onMouseLeave = () => {
    isDown.current = false;
    isPanning.current = false;
    setHover(null);
    onHoverChange && onHoverChange(null);
  };

  const onContextMenu = (e) => e.preventDefault();

  // Render tiles as SVG
  const tiles = useMemo(() => Object.values(map.tiles), [map]);

  return (
    <div className="canvas-wrap" ref={wrapRef}
         onMouseDown={onMouseDown}
         onMouseMove={onMouseMove}
         onMouseUp={onMouseUp}
         onMouseLeave={onMouseLeave}
         onContextMenu={onContextMenu}
         style={{ cursor: isPanning.current ? 'grabbing' : (activeTool === 'cursor' ? 'default' : 'crosshair') }}
    >
      <div className="grid-bg" />
      <svg ref={svgRef} className="hex-canvas" viewBox={`${-size.w/2} ${-size.h/2} ${size.w} ${size.h}`}
           preserveAspectRatio="xMidYMid meet">
        <g transform={`translate(${view.cx} ${view.cy}) scale(${view.zoom})`}>
          {/* Tiles */}
          {tiles.map(t => {
            const [cx, cy] = hexToPixel(t.q, t.r);
            const biome = window.BIOME_BY_ID[t.biome];
            const baseColor = biome ? biome.color : '#444';
            // Darken by elevation — higher = lighter, per design doc
            const elevFactor = (t.elevation - 2) * 0.06;
            let fill = shadeHex(baseColor, elevFactor);
            // Style modes
            if (canvasStyle === 'elevation') {
              const g = Math.round(60 + (t.elevation / 9) * 180);
              fill = `rgb(${g}, ${g}, ${g})`;
            }
            if (canvasStyle === 'biome-only') {
              fill = baseColor;
            }
            const isSel = selected && selected.q === t.q && selected.r === t.r;
            const isSpawn = map.spawn[0] === t.q && map.spawn[1] === t.r;
            return (
              <g key={`${t.q},${t.r}`}>
                <path d={hexPath(cx, cy)} fill={fill}
                      stroke={isSel ? '#f4a261' : 'rgba(0,0,0,0.25)'}
                      strokeWidth={isSel ? 2.4 / view.zoom : 0.8 / view.zoom} />
                {/* Elevation rim — subtle contour */}
                {showLayers.elevation && t.elevation > 0 && canvasStyle !== 'elevation' && (
                  <path d={hexPath(cx, cy, HEX_SIZE - 2)}
                        fill="none"
                        stroke="rgba(255,255,255,0.08)"
                        strokeWidth={0.6 / view.zoom}
                        strokeDasharray={t.elevation >= 4 ? '2 2' : '0'} />
                )}
                {/* Elevation number */}
                {showElevationNumbers && t.elevation > 0 && (
                  <text x={cx} y={cy - 11} textAnchor="middle"
                        fontSize={8.5 / view.zoom * view.zoom}
                        fontFamily="IBM Plex Mono"
                        fill="rgba(255,255,255,0.55)"
                        style={{ pointerEvents: 'none' }}>
                    {t.elevation}
                  </text>
                )}
                {/* Props */}
                {showLayers.props && t.props && t.props.map((p, i) => {
                  const prop = window.PROP_BY_ID[p.type];
                  const color = prop ? prop.color : '#fff';
                  return (
                    <circle key={i} cx={cx + p.x * 8} cy={cy + p.y * 8} r={2.2}
                            fill={color} stroke="rgba(0,0,0,0.5)" strokeWidth={0.6} />
                  );
                })}
                {/* Structure */}
                {showLayers.structures && t.structure && (
                  <rect x={cx - 5} y={cy - 5} width={10} height={10}
                        fill="#f4a261" stroke="#1a1412" strokeWidth={1}
                        transform={`rotate(45 ${cx} ${cy})`} />
                )}
                {/* Anomaly */}
                {showLayers.anomalies && t.anomaly && (
                  <>
                    <circle cx={cx} cy={cy} r={9} fill="none" stroke="#a88bd9" strokeWidth={1.4} strokeDasharray="2 2" />
                    <circle cx={cx} cy={cy} r={3} fill="#a88bd9" />
                  </>
                )}
                {/* Spawn */}
                {isSpawn && (
                  <g style={{ pointerEvents: 'none' }}>
                    <circle cx={cx} cy={cy} r={11} fill="none" stroke="#f4a261" strokeWidth={1.6} />
                    <path d={`M${cx} ${cy-6} L${cx+5} ${cy+4} L${cx-5} ${cy+4} Z`} fill="#f4a261" />
                  </g>
                )}
                {/* Coord label */}
                {showCoords && (
                  <text x={cx} y={cy + 14} textAnchor="middle"
                        fontSize={7}
                        fontFamily="IBM Plex Mono"
                        fill="rgba(255,255,255,0.35)"
                        style={{ pointerEvents: 'none' }}>
                    {t.q},{t.r}
                  </text>
                )}
              </g>
            );
          })}

          {/* Cliff edges — between tiles with |Δelev|≥2 */}
          {showLayers.cliffs && tiles.map(t => {
            const [cx, cy] = hexToPixel(t.q, t.r);
            const corners = hexCorners(cx, cy);
            return window.HEX_DIRS.map(([dq, dr], i) => {
              const n = map.tiles[`${t.q + dq},${t.r + dr}`];
              if (!n) return null;
              const diff = Math.abs(t.elevation - n.elevation);
              if (diff < 2 || t.elevation < n.elevation) return null;
              const [ax, ay] = corners[i];
              const [bx, by] = corners[(i + 1) % 6];
              const color = diff >= 4 ? '#e07b7b' : '#f0d060';
              return <line key={`cl-${t.q},${t.r}-${i}`} x1={ax} y1={ay} x2={bx} y2={by}
                           stroke={color} strokeWidth={2 / view.zoom} strokeLinecap="round" />;
            });
          })}

          {/* Hover outline */}
          {hover && map.tiles[`${hover.q},${hover.r}`] && (() => {
            const [cx, cy] = hexToPixel(hover.q, hover.r);
            return <path d={hexPath(cx, cy)} fill="none" stroke="#fff" strokeWidth={1.6 / view.zoom} opacity="0.55" pointerEvents="none"/>;
          })()}
        </g>
      </svg>

      {hover && hover.tile && (
        <div className="hex-tooltip" style={{ left: hover.x + 14, top: hover.y + 14 }}>
          <div><span className="tk">coord </span><span className="tv">{hover.q},{hover.r}</span></div>
          <div><span className="tk">biome </span><span className="tv">{(window.BIOME_BY_ID[hover.tile.biome]||{}).name || '—'}</span></div>
          <div><span className="tk">elev  </span><span className="tv">{hover.tile.elevation}</span></div>
          {hover.tile.props && hover.tile.props.length > 0 && <div><span className="tk">props </span><span className="tv">{hover.tile.props.length}</span></div>}
          {hover.tile.structure && <div><span className="tk">struct</span><span className="tv">{(window.PROP_BY_ID[hover.tile.structure]||{}).name}</span></div>}
          {hover.tile.anomaly && <div><span className="tk">anom  </span><span className="tv">{hover.tile.anomaly}</span></div>}
        </div>
      )}
    </div>
  );
}

window.HexCanvas = HexCanvas;
