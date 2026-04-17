/* Farhaven Editor — Map Editor tab */

const { useState: useStateM, useMemo: useMemoM, useRef: useRefM } = React;

const TOOLS = [
  { id: 'cursor',    name: 'Select',       icon: 'cursor',   kbd: 'V' },
  { id: 'pan',       name: 'Pan',          icon: 'hand',     kbd: 'Space' },
  { id: '__div1',    divider: true },
  { id: 'biome',     name: 'Biome Brush',  icon: 'brush',    kbd: 'B' },
  { id: 'flood',     name: 'Flood Fill',   icon: 'bucket',   kbd: 'F' },
  { id: 'elevation', name: 'Elevation',    icon: 'mountain', kbd: 'E' },
  { id: '__div2',    divider: true },
  { id: 'prop',      name: 'Place Prop',   icon: 'tree',     kbd: 'R' },
  { id: 'structure', name: 'Structure',    icon: 'house',    kbd: 'S' },
  { id: 'anomaly',   name: 'Anomaly',      icon: 'spark',    kbd: 'A' },
  { id: 'spawn',     name: 'Spawn',        icon: 'pin',      kbd: 'P' },
  { id: '__div3',    divider: true },
  { id: 'eraser',    name: 'Eraser',       icon: 'eraser',   kbd: 'X' },
  { id: 'delete',    name: 'Delete Hex',   icon: 'trash',    kbd: 'D' },
];

function ToolRail({ active, onPick, onOpenRadial }) {
  return (
    <div className="toolrail" onContextMenu={e => { e.preventDefault(); onOpenRadial && onOpenRadial(e); }}>
      {TOOLS.map(t => t.divider ? (
        <div key={t.id} className="divider" />
      ) : (
        <button key={t.id}
                className={'tool ' + (active === t.id ? 'active' : '')}
                onClick={() => onPick(t.id)}>
          <window.Icon name={t.icon} />
          <span className="kbd">{t.kbd === 'Space' ? '␣' : t.kbd}</span>
          <span className="tip">{t.name}<span className="tip-kbd">{t.kbd}</span></span>
        </button>
      ))}
    </div>
  );
}

function LayerPanel({ layers, onToggle }) {
  const rows = [
    { id: 'biomes',     name: 'Biomes',     icon: 'brush' },
    { id: 'elevation',  name: 'Elevation',  icon: 'mountain' },
    { id: 'cliffs',     name: 'Cliffs',     icon: 'bolt' },
    { id: 'props',      name: 'Props',      icon: 'tree' },
    { id: 'structures', name: 'Structures', icon: 'house' },
    { id: 'anomalies',  name: 'Anomalies',  icon: 'spark' },
    { id: 'spawn',      name: 'Spawn',      icon: 'pin' },
  ];
  return (
    <div className="layer-list">
      {rows.map(r => (
        <div key={r.id} className={'layer-row ' + (!layers[r.id] ? 'hidden' : '')}
             onClick={() => onToggle(r.id)}>
          <span className="eye"><window.Icon name={layers[r.id] ? 'eye' : 'eye-off'} size={13}/></span>
          <span className="layer-name">{r.name}</span>
        </div>
      ))}
    </div>
  );
}

function BiomePalette({ active, onPick }) {
  return (
    <div className="biome-grid">
      {window.BIOMES.map(b => (
        <div key={b.id}
             className={'biome-swatch-row ' + (active === b.id ? 'active' : '')}
             onClick={() => onPick(b.id)}>
          <div className="biome-swatch" style={{ background: b.color }} />
          <div className="label">{b.name}</div>
          <div className="id">{b.id}</div>
        </div>
      ))}
    </div>
  );
}

function PropPalette({ active, onPick }) {
  const [cat, setCat] = useStateM('all');
  const filtered = window.PROPS.filter(p => cat === 'all' || p.category === cat);
  return (
    <>
      <div className="prop-filter">
        {window.PROP_CATEGORIES.map(c => (
          <div key={c} className={'chip ' + (cat === c ? 'active' : '')} onClick={() => setCat(c)}>{c}</div>
        ))}
      </div>
      <div className="prop-grid">
        {filtered.map(p => (
          <div key={p.id}
               className={'prop-cell ' + (active === p.id ? 'active' : '')}
               onClick={() => onPick(p.id)}
               title={`${p.name} — ${p.id}`}>
            <span className="glyph" style={{ color: p.color }}>{p.glyph}</span>
            <span className="dot" style={{ background: window.CATEGORY_COLORS[p.category] }} />
          </div>
        ))}
      </div>
    </>
  );
}

function MiniMap({ map, view }) {
  const pts = useMemoM(() => {
    if (!map) return { tiles: [], bounds: { minX:-100, minY:-100, w:200, h:200 } };
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    const list = Object.values(map.tiles).map(t => {
      const [x, y] = window.HEX.hexToPixel(t.q, t.r);
      if (x < minX) minX = x; if (x > maxX) maxX = x;
      if (y < minY) minY = y; if (y > maxY) maxY = y;
      return { x, y, color: (window.BIOME_BY_ID[t.biome]||{color:'#444'}).color };
    });
    const pad = 20;
    return { tiles: list, bounds: { minX: minX-pad, minY: minY-pad, w: (maxX-minX)+pad*2, h: (maxY-minY)+pad*2 } };
  }, [map]);
  const { bounds } = pts;
  return (
    <svg viewBox={`${bounds.minX} ${bounds.minY} ${bounds.w} ${bounds.h}`}
         preserveAspectRatio="xMidYMid meet">
      {pts.tiles.map((t, i) => (
        <circle key={i} cx={t.x} cy={t.y} r={3.6} fill={t.color} />
      ))}
      {view && (
        <rect x={-view.cx/view.zoom - (view.w/2)/view.zoom}
              y={-view.cy/view.zoom - (view.h/2)/view.zoom}
              width={view.w/view.zoom} height={view.h/view.zoom}
              className="mm-view"/>
      )}
    </svg>
  );
}

function Inspector({ selectedTile, spawn, onUpdate }) {
  if (!selectedTile) {
    return (
      <div className="empty-state">
        <div className="big"><window.Icon name="hex" size={24}/></div>
        <div>No hex selected</div>
        <div className="sub">Click a tile in the canvas to inspect and edit it here. Use the Command Palette (<span className="kbd-inline">⌘K</span>) for quick actions.</div>
      </div>
    );
  }
  const t = selectedTile;
  const biome = window.BIOME_BY_ID[t.biome];
  const isSpawn = spawn[0] === t.q && spawn[1] === t.r;

  return (
    <>
      <div className="inspector-head">
        <div className="inspector-title">
          <span>Hex</span>
          <span className="coord">{t.q}, {t.r}</span>
        </div>
        <div className="inspector-subtitle">
          {biome && biome.name} · elevation {t.elevation}
        </div>
        <div className="inspector-chip-row">
          {isSpawn && <span className="mini-pill"><span className="d" style={{background:'#f4a261'}}/>spawn</span>}
          {t.structure && <span className="mini-pill"><span className="d" style={{background:'#f4a261'}}/>struct</span>}
          {t.anomaly && <span className="mini-pill"><span className="d" style={{background:'#a88bd9'}}/>anomaly</span>}
          <span className="mini-pill"><span className="d" style={{background:biome.color}}/>{t.biome}</span>
        </div>
      </div>

      <div className="section-title" style={{margin: '8px 12px 4px', padding: 0, border: 'none'}}>Properties</div>

      <div className="row">
        <label>Biome</label>
        <div className="ctrl">
          <select className="select" value={t.biome} onChange={e => onUpdate({ biome: e.target.value })}>
            {window.BIOMES.map(b => <option key={b.id} value={b.id}>{b.name} — {b.id}</option>)}
          </select>
        </div>
      </div>

      <div className="row">
        <label>Elevation</label>
        <div className="ctrl">
          <div className="num">
            <input type="number" value={t.elevation} min={0} max={9}
                   onChange={e => onUpdate({ elevation: Math.max(0, Math.min(9, +e.target.value)) })}/>
            <button onClick={() => onUpdate({ elevation: Math.min(9, t.elevation+1) })}>+</button>
            <button onClick={() => onUpdate({ elevation: Math.max(0, t.elevation-1) })}>−</button>
          </div>
        </div>
      </div>

      <div className="row">
        <label>Structure</label>
        <div className="ctrl">
          <select className="select" value={t.structure || ''} onChange={e => onUpdate({ structure: e.target.value || null })}>
            <option value="">— none —</option>
            {window.PROPS.filter(p => p.category === 'structure').map(p => <option key={p.id} value={p.id}>{p.name}</option>)}
          </select>
        </div>
      </div>

      <div className="row">
        <label>Anomaly</label>
        <div className="ctrl">
          <input className="input" placeholder="none" value={t.anomaly || ''}
                 onChange={e => onUpdate({ anomaly: e.target.value || null })}/>
        </div>
      </div>

      <div className="section-title" style={{margin: '8px 12px 4px', padding: 0, border: 'none'}}>
        Walls <span style={{float:'right', color:'var(--text-2)', fontFamily:'var(--font-mono)', fontSize: 10, fontWeight: 400, letterSpacing: 0}}>6 edges</span>
      </div>

      <div className="wall-picker">
        <svg viewBox="-50 -50 100 100">
          <path d={window.HEX.hexPath(0, 0, 38)} className="hex-ref" />
          <text className="center-label" x={0} y={0}>{t.q},{t.r}</text>
          {(t.walls || [false,false,false,false,false,false]).map((w, i) => {
            const a1 = (Math.PI / 3) * i;
            const a2 = (Math.PI / 3) * (i + 1);
            const x1 = 38 * Math.cos(a1), y1 = 38 * Math.sin(a1);
            const x2 = 38 * Math.cos(a2), y2 = 38 * Math.sin(a2);
            return <line key={i} className={'edge ' + (w ? 'on' : '')}
                         x1={x1} y1={y1} x2={x2} y2={y2}
                         onClick={() => {
                           const walls = [...(t.walls || [false,false,false,false,false,false])];
                           walls[i] = !walls[i];
                           onUpdate({ walls });
                         }}/>;
          })}
        </svg>
      </div>

      <div className="section-title" style={{margin: '0 12px 4px', padding: 0, border: 'none'}}>
        Props <span style={{float:'right', color:'var(--text-2)', fontFamily:'var(--font-mono)', fontSize: 10, fontWeight: 400, letterSpacing: 0}}>{(t.props || []).length}</span>
      </div>

      <div className="prop-items">
        {(t.props || []).map((p, i) => {
          const prop = window.PROP_BY_ID[p.type];
          return (
            <div key={i} className="prop-item">
              <span className="glyph" style={{color: (prop||{}).color}}>{(prop||{}).glyph || '??'}</span>
              <span className="name">{(prop||{}).name || p.type}</span>
              <span className="coord">{p.x.toFixed(2)},{p.y.toFixed(2)} · {p.rot}°</span>
              <button className="rm" onClick={() => {
                const next = [...t.props]; next.splice(i, 1); onUpdate({ props: next });
              }}><window.Icon name="x" size={11}/></button>
            </div>
          );
        })}
        <button className="add-btn" onClick={() => {
          const next = [...(t.props||[])];
          next.push({ type: 'P00001', x: 0, y: 0, rot: 0 });
          onUpdate({ props: next });
        }}>
          <window.Icon name="plus" size={11}/> Add prop
        </button>
      </div>
    </>
  );
}

function MapEditor({ tweaks }) {
  const [map, setMap] = useStateM(window.SHOWCASE_MAP);
  const [activeTool, setActiveTool] = useStateM('biome');
  const [activeBiome, setActiveBiome] = useStateM('B00003');
  const [activeProp, setActiveProp] = useStateM('P00003');
  const [selected, setSelected] = useStateM({ q: 0, r: 0 });
  const [layers, setLayers] = useStateM({
    biomes: true, elevation: true, cliffs: true, props: true,
    structures: true, anomalies: true, spawn: true,
  });
  const [view, setView] = useStateM(null);

  const selectedTile = selected ? map.tiles[`${selected.q},${selected.r}`] : null;

  const updateTile = (q, r, patch) => {
    setMap(m => {
      const key = `${q},${r}`;
      const cur = m.tiles[key];
      if (!cur) return m;
      return { ...m, tiles: { ...m.tiles, [key]: { ...cur, ...patch } } };
    });
  };

  const onPaint = (q, r, e) => {
    const key = `${q},${r}`;
    const cur = map.tiles[key];
    if (activeTool === 'biome') {
      if (cur) updateTile(q, r, { biome: activeBiome });
    } else if (activeTool === 'elevation') {
      if (cur) {
        const delta = e.shiftKey || e.button === 2 ? -1 : 1;
        updateTile(q, r, { elevation: Math.max(0, Math.min(9, cur.elevation + delta)) });
      }
    } else if (activeTool === 'flood' && cur) {
      // flood fill biome
      const target = cur.biome;
      if (target === activeBiome) return;
      const visited = new Set();
      const stack = [[q, r]];
      setMap(m => {
        const tiles = { ...m.tiles };
        while (stack.length) {
          const [cq, cr] = stack.pop();
          const k = `${cq},${cr}`;
          if (visited.has(k)) continue;
          visited.add(k);
          const t = tiles[k];
          if (!t || t.biome !== target) continue;
          tiles[k] = { ...t, biome: activeBiome };
          for (const [dq, dr] of window.HEX_DIRS) stack.push([cq + dq, cr + dr]);
        }
        return { ...m, tiles };
      });
    } else if (activeTool === 'prop' && cur) {
      const next = [...(cur.props || [])];
      next.push({ type: activeProp, x: (Math.random()-0.5)*1.6, y: (Math.random()-0.5)*1.6, rot: Math.floor(Math.random()*360) });
      updateTile(q, r, { props: next });
    } else if (activeTool === 'structure' && cur) {
      updateTile(q, r, { structure: activeProp });
    } else if (activeTool === 'anomaly' && cur) {
      updateTile(q, r, { anomaly: 'strange_signal' });
    } else if (activeTool === 'spawn' && cur) {
      setMap(m => ({ ...m, spawn: [q, r] }));
    } else if (activeTool === 'eraser' && cur) {
      updateTile(q, r, { props: [], structure: null, anomaly: null });
    } else if (activeTool === 'delete') {
      setMap(m => {
        const tiles = { ...m.tiles };
        delete tiles[key];
        return { ...m, tiles };
      });
    }
  };

  const showBiomePalette = ['biome', 'flood'].includes(activeTool);
  const showPropPalette  = ['prop', 'structure'].includes(activeTool);
  const activeToolDef = TOOLS.find(t => t.id === activeTool);

  return (
    <div className="map-editor">
      <ToolRail active={activeTool} onPick={setActiveTool} />

      <div className="leftcol">
        <div className="panel">
          <div className="panel-header">
            <window.Icon name="layers" size={11}/>
            Layers
          </div>
          <div className="panel-body">
            <LayerPanel layers={layers} onToggle={k => setLayers(l => ({...l, [k]: !l[k]}))}/>
          </div>
        </div>

        {showBiomePalette && (
          <div className="panel">
            <div className="panel-header">
              <window.Icon name="brush" size={11}/>
              Biomes
              <div className="actions"><button title="New biome"><window.Icon name="plus" size={11}/></button></div>
            </div>
            <div className="panel-body">
              <BiomePalette active={activeBiome} onPick={setActiveBiome}/>
            </div>
          </div>
        )}

        {showPropPalette && (
          <div className="panel">
            <div className="panel-header">
              <window.Icon name="tree" size={11}/>
              Props
            </div>
            <div className="panel-body">
              <PropPalette active={activeProp} onPick={setActiveProp}/>
            </div>
          </div>
        )}

        {!showBiomePalette && !showPropPalette && (
          <div className="panel">
            <div className="panel-header">
              <window.Icon name="map" size={11}/>
              Map
            </div>
            <div className="panel-body">
              <div style={{fontSize: 11.5, color: 'var(--text-1)', lineHeight: 1.6}}>
                <div style={{color:'var(--text-0)', fontWeight: 500, marginBottom: 4}}>{map.name}</div>
                <div style={{fontFamily:'var(--font-mono)', color:'var(--text-2)', fontSize: 10.5}}>
                  ch1 · {Object.keys(map.tiles).length} tiles
                </div>
                <div style={{marginTop: 10, display:'flex', flexDirection:'column', gap: 4}}>
                  {window.BIOMES.map(b => {
                    const n = Object.values(map.tiles).filter(t => t.biome === b.id).length;
                    return (
                      <div key={b.id} style={{display:'flex', alignItems:'center', gap: 8, fontSize: 11}}>
                        <span className="biome-swatch" style={{background: b.color, width: 10, height: 10}}/>
                        <span style={{flex: 1}}>{b.name}</span>
                        <span style={{fontFamily:'var(--font-mono)', color:'var(--text-2)'}}>{n}</span>
                      </div>
                    );
                  })}
                </div>
              </div>
            </div>
          </div>
        )}
      </div>

      <window.HexCanvas
        map={map}
        selected={selected}
        onSelect={(q, r) => setSelected({q, r})}
        onPaint={onPaint}
        activeTool={activeTool}
        activeBiome={activeBiome}
        activeProp={activeProp}
        showCoords={tweaks.showCoords}
        showElevationNumbers={tweaks.showElevationNumbers}
        canvasStyle={tweaks.canvasStyle}
        showLayers={layers}
        onHoverChange={() => {}}
        onViewChange={setView}
      />

      {/* Canvas HUD overlays */}
      <div className="canvas-hud-top" style={{position:'absolute', top: 10, left: 10 + 40 + 224 + 10, right: 280 + 10, pointerEvents:'none'}}>
        <div className="hud-group">
          <button className="hud-btn"><window.Icon name="undo"/>Undo</button>
          <button className="hud-btn"><window.Icon name="redo"/>Redo</button>
        </div>
        <div className="hud-readout">
          <span><span className="lbl">tiles </span><span className="val">{Object.keys(map.tiles).length}</span></span>
          <span><span className="lbl">spawn </span><span className="val">{map.spawn[0]},{map.spawn[1]}</span></span>
          <span><span className="lbl">chapter </span><span className="val">{map.id}</span></span>
        </div>
      </div>

      <div className="canvas-hud-bottom" style={{position:'absolute', bottom: 10, left: 10 + 40 + 224 + 10, right: 280 + 10, pointerEvents:'none'}}>
        <div className="brush-readout">
          <span className="icon"><window.Icon name={activeToolDef.icon} /></span>
          <span className="name">{activeToolDef.name}</span>
          <span className="sep"/>
          {showBiomePalette && (<><span className="biome-swatch" style={{background: window.BIOME_BY_ID[activeBiome].color, width: 12, height: 12}}/><span className="val">{window.BIOME_BY_ID[activeBiome].name}</span></>)}
          {showPropPalette && (<><span className="val" style={{color: (window.PROP_BY_ID[activeProp]||{}).color}}>{(window.PROP_BY_ID[activeProp]||{}).glyph}</span><span className="val">{(window.PROP_BY_ID[activeProp]||{}).name}</span></>)}
          {activeTool === 'elevation' && (<span className="val">+1 / −1 shift</span>)}
          {!showBiomePalette && !showPropPalette && activeTool !== 'elevation' && (<span className="val">click to apply</span>)}
        </div>
        <div className="zoom-group">
          <button title="Zoom out"><window.Icon name="zoom-out"/></button>
          <span className="zoom-val">{view ? Math.round(view.zoom*100) : 100}%</span>
          <button title="Zoom in"><window.Icon name="zoom-in"/></button>
          <button title="Fit view"><window.Icon name="target"/></button>
        </div>
      </div>

      {tweaks.showMinimap && view && (
        <div className="minimap" style={{right: 280 + 10}}>
          <div className="mm-label">Overview</div>
          <MiniMap map={map} view={view}/>
        </div>
      )}

      <aside className="rightcol">
        <div className="scroll">
          <Inspector
            selectedTile={selectedTile}
            spawn={map.spawn}
            onUpdate={patch => selectedTile && updateTile(selected.q, selected.r, patch)}
          />
        </div>
      </aside>
    </div>
  );
}

window.MapEditor = MapEditor;
window.TOOLS = TOOLS;
