/* Farhaven Editor — command palette (⌘K / Ctrl+K) */

const { useState: useStateC, useEffect: useEffectC, useMemo: useMemoC, useRef: useRefC } = React;

function CommandPalette({ open, onClose, onAction }) {
  const [q, setQ] = useStateC('');
  const [idx, setIdx] = useStateC(0);
  const inputRef = useRefC(null);

  const cmds = useMemoC(() => [
    { section: 'Tools', items: [
      { id: 'tool:cursor',     label: 'Select Tool',       kbd: 'V', icon: 'cursor' },
      { id: 'tool:biome',      label: 'Biome Brush',       kbd: 'B', icon: 'brush' },
      { id: 'tool:elevation',  label: 'Elevation Brush',   kbd: 'E', icon: 'mountain' },
      { id: 'tool:flood',      label: 'Flood Fill',        kbd: 'F', icon: 'bucket' },
      { id: 'tool:prop',       label: 'Place Prop',        kbd: 'R', icon: 'tree' },
      { id: 'tool:spawn',      label: 'Set Spawn',         kbd: 'P', icon: 'pin' },
      { id: 'tool:eraser',     label: 'Eraser',            kbd: 'X', icon: 'eraser' },
    ]},
    { section: 'Navigation', items: [
      { id: 'goto:map',        label: 'Go to Map Editor',  icon: 'map', sub: 'maps' },
      { id: 'goto:biomes',     label: 'Go to Biomes',      icon: 'brush', sub: 'biomes' },
      { id: 'goto:plant',      label: 'Go to Flora',       icon: 'leaf', sub: 'props/plant' },
      { id: 'goto:mineral',    label: 'Go to Minerals',    icon: 'rocks', sub: 'props/mineral' },
      { id: 'goto:recipes',    label: 'Go to Recipes',     icon: 'flask', sub: 'recipes' },
      { id: 'goto:journal',    label: 'Go to Journal',     icon: 'book', sub: 'journal' },
      { id: 'goto:cutscenes',  label: 'Go to Cutscenes',   icon: 'film', sub: 'cutscenes' },
      { id: 'goto:settings',   label: 'Settings',          icon: 'gear', sub: 'settings' },
    ]},
    { section: 'File', items: [
      { id: 'file:new',        label: 'New Map',           kbd: '⌘N', icon: 'plus' },
      { id: 'file:save',       label: 'Save All',          kbd: '⌘S', icon: 'save' },
      { id: 'file:import',     label: 'Import ch1.json',   icon: 'upload' },
      { id: 'file:export',     label: 'Export chapter…',   icon: 'download' },
    ]},
    { section: 'View', items: [
      { id: 'view:coords',     label: 'Toggle Coordinates',    icon: 'grid' },
      { id: 'view:elev-num',   label: 'Toggle Elevation Numbers', icon: 'mountain' },
      { id: 'view:minimap',    label: 'Toggle Minimap',        icon: 'map' },
      { id: 'view:fit',        label: 'Fit Map to View',       icon: 'target' },
      { id: 'view:center',     label: 'Center on Spawn',       kbd: 'H', icon: 'pin' },
    ]},
  ], []);

  const flat = useMemoC(() => {
    const ql = q.toLowerCase();
    const out = [];
    for (const s of cmds) {
      const matched = s.items.filter(i => !ql || i.label.toLowerCase().includes(ql) || (i.sub||'').toLowerCase().includes(ql));
      if (matched.length) out.push({ section: s.section, items: matched });
    }
    return out;
  }, [q, cmds]);

  const allItems = useMemoC(() => flat.flatMap(s => s.items), [flat]);

  useEffectC(() => { setIdx(0); }, [q, open]);
  useEffectC(() => { if (open && inputRef.current) inputRef.current.focus(); }, [open]);

  const run = (item) => {
    onAction && onAction(item.id);
    onClose();
  };

  const onKey = (e) => {
    if (e.key === 'Escape') { onClose(); return; }
    if (e.key === 'ArrowDown') { e.preventDefault(); setIdx(i => Math.min(allItems.length - 1, i + 1)); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); setIdx(i => Math.max(0, i - 1)); }
    else if (e.key === 'Enter') { e.preventDefault(); if (allItems[idx]) run(allItems[idx]); }
  };

  if (!open) return null;
  let gIdx = -1;
  return (
    <div className="cmdk-backdrop" onMouseDown={onClose}>
      <div className="cmdk" onMouseDown={e => e.stopPropagation()}>
        <div className="cmdk-input">
          <window.Icon name="search"/>
          <input ref={inputRef} value={q} onChange={e => setQ(e.target.value)} placeholder="Type a command or search…" onKeyDown={onKey}/>
          <span className="hint-kbd">ESC</span>
        </div>
        <div className="cmdk-list">
          {flat.map(sec => (
            <div key={sec.section}>
              <div className="cmdk-section">{sec.section}</div>
              {sec.items.map(item => {
                gIdx++;
                const active = gIdx === idx;
                return (
                  <div key={item.id}
                       className={'cmdk-item ' + (active ? 'active' : '')}
                       onMouseEnter={() => setIdx(gIdx)}
                       onClick={() => run(item)}>
                    <span className="ci-icon"><window.Icon name={item.icon || 'dot'}/></span>
                    <span className="ci-label">{item.label}</span>
                    {item.sub && <span className="ci-sub">{item.sub}</span>}
                    {item.kbd && <span className="ci-kbd">{item.kbd}</span>}
                  </div>
                );
              })}
            </div>
          ))}
          {flat.length === 0 && (
            <div style={{padding: '24px 14px', color: 'var(--text-2)', textAlign: 'center', fontSize: 13}}>No matches.</div>
          )}
        </div>
      </div>
    </div>
  );
}

/* ---- Radial tool picker (right-click-hold on canvas) ---- */
function RadialPicker({ open, x, y, onPick, onClose }) {
  const [hover, setHover] = useStateC(null);
  if (!open) return null;
  const picks = [
    { id: 'cursor',    label: 'Select',    kbd: 'V', icon: 'cursor' },
    { id: 'biome',     label: 'Biome',     kbd: 'B', icon: 'brush' },
    { id: 'elevation', label: 'Elevation', kbd: 'E', icon: 'mountain' },
    { id: 'flood',     label: 'Flood',     kbd: 'F', icon: 'bucket' },
    { id: 'prop',      label: 'Prop',      kbd: 'R', icon: 'tree' },
    { id: 'spawn',     label: 'Spawn',     kbd: 'P', icon: 'pin' },
    { id: 'eraser',    label: 'Erase',     kbd: 'X', icon: 'eraser' },
    { id: 'delete',    label: 'Delete',    kbd: 'D', icon: 'trash' },
  ];
  const N = picks.length;
  const rOut = 100, rIn = 38;
  const cx = 110, cy = 110;
  const seg = (i) => {
    const a0 = (Math.PI * 2 / N) * i - Math.PI / 2 - (Math.PI / N);
    const a1 = a0 + (Math.PI * 2 / N);
    const x1 = cx + rOut * Math.cos(a0), y1 = cy + rOut * Math.sin(a0);
    const x2 = cx + rOut * Math.cos(a1), y2 = cy + rOut * Math.sin(a1);
    const x3 = cx + rIn  * Math.cos(a1), y3 = cy + rIn  * Math.sin(a1);
    const x4 = cx + rIn  * Math.cos(a0), y4 = cy + rIn  * Math.sin(a0);
    const am = (a0 + a1) / 2;
    const lx = cx + ((rOut + rIn) / 2) * Math.cos(am);
    const ly = cy + ((rOut + rIn) / 2) * Math.sin(am);
    return { d: `M${x1},${y1} A${rOut},${rOut} 0 0 1 ${x2},${y2} L${x3},${y3} A${rIn},${rIn} 0 0 0 ${x4},${y4} Z`, lx, ly };
  };
  return (
    <div className="radial" style={{left: x, top: y}} onMouseLeave={onClose}>
      <svg>
        {picks.map((p, i) => {
          const s = seg(i);
          return (
            <g key={p.id}>
              <path d={s.d} className={'segment ' + (hover === p.id ? 'hover' : '')}
                    onMouseEnter={() => setHover(p.id)}
                    onClick={() => { onPick(p.id); onClose(); }}/>
              <g className="seg-icon" transform={`translate(${s.lx - 8}, ${s.ly - 14})`}>
                <g style={{color: hover === p.id ? 'var(--accent)' : 'var(--text-0)'}}>
                  <window.Icon name={p.icon} size={16}/>
                </g>
              </g>
              <text className="seg-label" x={s.lx} y={s.ly + 10} style={{fill: hover === p.id ? 'var(--accent)' : 'var(--text-0)'}}>{p.label}</text>
              <text className="seg-sub"  x={s.lx} y={s.ly + 22}>{p.kbd}</text>
            </g>
          );
        })}
        <circle cx={cx} cy={cy} r={rIn - 2} className="center-disc"/>
        <text className="center-label" x={cx} y={cy}>{hover ? (picks.find(p=>p.id===hover)||{}).label : 'tools'}</text>
      </svg>
    </div>
  );
}

window.CommandPalette = CommandPalette;
window.RadialPicker = RadialPicker;
