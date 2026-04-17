/* Farhaven Editor — main app shell */

const { useState: useStateA, useEffect: useEffectA, useMemo: useMemoA, useCallback: useCallbackA } = React;

const NAV = [
  { id: 'maps', section: 'WORLD', label: 'Maps', icon: 'map', badge: 2 },
  { id: 'biomes', section: 'WORLD', label: 'Biomes', icon: 'brush', count: window.BIOMES.length },
  { id: 'events', section: 'WORLD', label: 'Events', icon: 'bolt', count: window.EVENTS.length },
  { id: 'plant', section: 'PROPS', label: 'Flora', icon: 'leaf', count: window.PROPS.filter(p=>p.category==='plant').length },
  { id: 'animal', section: 'PROPS', label: 'Fauna', icon: 'paw', count: window.PROPS.filter(p=>p.category==='animal').length },
  { id: 'mineral', section: 'PROPS', label: 'Minerals', icon: 'rocks', count: window.PROPS.filter(p=>p.category==='mineral').length },
  { id: 'structure', section: 'PROPS', label: 'Structures', icon: 'house', count: window.PROPS.filter(p=>p.category==='structure').length },
  { id: 'equipment', section: 'PROPS', label: 'Equipment', icon: 'tool', count: window.PROPS.filter(p=>p.category==='equipment').length },
  { id: 'storage', section: 'PROPS', label: 'Storage', icon: 'box', count: window.PROPS.filter(p=>p.category==='storage').length },
  { id: 'recipes', section: 'SYSTEMS', label: 'Recipes', icon: 'flask', count: window.RECIPES.length },
  { id: 'journal', section: 'NARRATIVE', label: 'Journal', icon: 'book', count: window.JOURNAL.length },
  { id: 'cutscenes', section: 'NARRATIVE', label: 'Cutscenes', icon: 'film', count: window.CUTSCENES.length },
  { id: 'settings', section: 'PROJECT', label: 'Settings', icon: 'gear' },
];

const CHAPTER_NAMES = {
  ch1: 'Crash Landing',
  ch2: 'The Ridgeline',
  ch3: 'Forges of the Bay',
};

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "layout": "classic",
  "density": "comfortable",
  "canvasStyle": "flat",
  "accent": "amber",
  "showCoords": false,
  "showElevationNumbers": false,
  "showMinimap": true,
  "commandPaletteHint": true
}/*EDITMODE-END*/;

function TitleBar({ chapter, setChapter, dirty, onCmdK, tweaks }) {
  const [openMenu, setOpenMenu] = useStateA(null);
  return (
    <div className="titlebar">
      <div className="brand">
        <div className="brand-mark">
          <svg viewBox="0 0 22 22">
            <path d={window.HEX.hexPath(11, 11, 8)} fill="currentColor" opacity="0.2"/>
            <path d={window.HEX.hexPath(11, 11, 8)} fill="none" stroke="currentColor" strokeWidth="1.4"/>
            <circle cx="11" cy="11" r="2.4" fill="currentColor"/>
          </svg>
          FARHAVEN
        </div>
        <span className="brand-sub">Editor</span>
        {['File','Edit','View','Tools','Run','Help'].map(m => (
          <button key={m} className="menu-btn" onClick={() => setOpenMenu(openMenu === m ? null : m)} onBlur={() => setTimeout(() => setOpenMenu(null), 120)}>{m}</button>
        ))}
      </div>

      <div className="center-crumbs">
        <div className="chapter-pill">
          <window.Icon name="book"/>
          <span className="label">Chapter</span>
          <select value={chapter} onChange={e => setChapter(e.target.value)}>
            {Object.entries(CHAPTER_NAMES).map(([id, name]) => (
              <option key={id} value={id}>{id} — {name}</option>
            ))}
          </select>
        </div>
        <div className="crumb">
          <span>farhaven.proj</span>
          <window.Icon name="chev-r" size={10}/>
          <span>{chapter}</span>
          <window.Icon name="chev-r" size={10}/>
          <span style={{color: 'var(--text-0)'}}>{CHAPTER_NAMES[chapter]}</span>
          {dirty && <span style={{color: 'var(--amber)', marginLeft: 6, fontSize: 14, lineHeight: 1}}>●</span>}
        </div>
      </div>

      <div className="right">
        {tweaks.commandPaletteHint && (
          <button className="cmdk-hint" onClick={onCmdK}>
            <window.Icon name="search" size={11}/>
            <span>Command…</span>
            <span className="k">⌘K</span>
          </button>
        )}
        <button className="pill-btn"><window.Icon name="undo" size={11}/>Undo<span className="k">⌘Z</span></button>
        <button className="pill-btn"><window.Icon name="redo" size={11}/>Redo</button>
        <button className="pill-btn"><window.Icon name="save" size={11}/>Save<span className="k">⌘S</span></button>
        <button className="pill-btn primary"><window.Icon name="play" size={11}/>Playtest</button>
      </div>
    </div>
  );
}

function Sidebar({ route, setRoute }) {
  const sections = useMemoA(() => {
    const out = {};
    for (const item of NAV) {
      if (!out[item.section]) out[item.section] = [];
      out[item.section].push(item);
    }
    return out;
  }, []);
  return (
    <aside className="sidebar">
      <div className="side-section">
        <div className="side-header">
          <span>Project</span>
          <button title="New"><window.Icon name="plus" size={10}/></button>
        </div>
        <div style={{padding: '2px 8px 6px'}}>
          <div style={{background: 'var(--bg-2)', border: '1px solid var(--line)', borderRadius: 4, padding: '8px 10px', display:'flex', flexDirection:'column', gap: 2}}>
            <div style={{fontSize: 12, color: 'var(--text-0)', fontWeight: 500, display:'flex', alignItems:'center', gap: 6}}>
              <span style={{display:'inline-block', width: 6, height: 6, borderRadius: '50%', background: 'var(--green)'}}/>
              farhaven
            </div>
            <div style={{fontSize: 10.5, color: 'var(--text-2)', fontFamily:'var(--font-mono)', letterSpacing: 0.02}}>v0.4.2 · 3 chapters · 47 assets</div>
          </div>
        </div>
      </div>

      {Object.entries(sections).map(([sec, items]) => (
        <div key={sec} className="side-section">
          <div className="side-header">
            <span>{sec}</span>
          </div>
          {items.map(item => (
            <div key={item.id}
                 className={'nav-item ' + (route === item.id ? 'active' : '')}
                 onClick={() => setRoute(item.id)}>
              <window.Icon name={item.icon} size={13}/>
              <span>{item.label}</span>
              {(item.count !== undefined) && <span className="count">{item.count}</span>}
              {item.badge && <span className="badge">{item.badge}</span>}
            </div>
          ))}
        </div>
      ))}

      <div style={{flex: 1}}/>
      <div style={{padding: '10px 12px', borderTop: '1px solid var(--line)', fontSize: 10.5, fontFamily: 'var(--font-mono)', color:'var(--text-2)', letterSpacing: 0.02, display:'flex', flexDirection:'column', gap: 2}}>
        <div>godot 4.3 · assembly ok</div>
        <div style={{color: 'var(--text-3)'}}>last scan 2s ago</div>
      </div>
    </aside>
  );
}

function StatusBar({ route, chapter, hover, tool, dirty, tweaks }) {
  const tileCount = Object.keys(window.SHOWCASE_MAP.tiles).length;
  return (
    <div className="statusbar">
      <div className="sb-group">
        <span className="sb-item"><span className="sb-dot" style={{background: dirty ? 'var(--amber)' : 'var(--green)'}}/>{dirty ? 'unsaved' : 'saved'}</span>
        <span className="sb-item"><window.Icon name="git" size={10}/>main · 2 ahead</span>
        <span className="sb-item">{route}</span>
      </div>
      <div className="sb-group">
        {route === 'maps' && hover && (
          <span className="sb-item">hex <span style={{color:'var(--text-0)'}}>{hover.q},{hover.r}</span></span>
        )}
        {route === 'maps' && (
          <>
            <span className="sb-item">tool <span style={{color:'var(--text-0)'}}>{tool}</span></span>
            <span className="sb-item">tiles <span style={{color:'var(--text-0)'}}>{tileCount}</span></span>
          </>
        )}
        <span className="sb-item">{chapter}</span>
        <span className="sb-item">UTF-8</span>
        <span className="sb-item">LF</span>
        <span className="sb-item">{tweaks.accent} · {tweaks.density}</span>
      </div>
    </div>
  );
}

function App() {
  const [route, setRoute] = useStateA('maps');
  const [chapter, setChapter] = useStateA('ch1');
  const [tweaks, setTweaks] = useStateA(TWEAK_DEFAULTS);
  const [editMode, setEditMode] = useStateA(false);
  const [cmdOpen, setCmdOpen] = useStateA(false);
  const [dirty] = useStateA(true);
  const [toolState] = useStateA({ tool: 'biome' });
  const [hoverHex] = useStateA(null);

  // Apply accent to CSS var
  useEffectA(() => {
    const map = {
      amber: { bg: 'rgba(244, 162, 97, 0.14)' , color: '#f4a261' },
      blue:  { bg: 'rgba(126, 165, 210, 0.14)' , color: '#7ea5d2' },
      green: { bg: 'rgba(126, 200, 134, 0.14)' , color: '#7ec886' },
      violet:{ bg: 'rgba(168, 139, 217, 0.14)' , color: '#a88bd9' },
    };
    const c = map[tweaks.accent] || map.amber;
    document.documentElement.style.setProperty('--accent', c.color);
    document.documentElement.style.setProperty('--accent-bg', c.bg);
  }, [tweaks.accent]);

  // Density
  useEffectA(() => {
    document.documentElement.dataset.density = tweaks.density;
  }, [tweaks.density]);

  // Edit mode protocol
  useEffectA(() => {
    const handler = (ev) => {
      if (!ev || !ev.data) return;
      if (ev.data.type === '__activate_edit_mode') setEditMode(true);
      if (ev.data.type === '__deactivate_edit_mode') setEditMode(false);
    };
    window.addEventListener('message', handler);
    try { window.parent.postMessage({ type: '__edit_mode_available' }, '*'); } catch (e) {}
    return () => window.removeEventListener('message', handler);
  }, []);

  const setTweak = useCallbackA((k, v) => {
    setTweaks(t => {
      const nt = { ...t, [k]: v };
      try { window.parent.postMessage({ type: '__edit_mode_set_keys', edits: { [k]: v } }, '*'); } catch (e) {}
      return nt;
    });
  }, []);

  // Cmd-K shortcut
  useEffectA(() => {
    const h = (e) => {
      if ((e.key === 'k' || e.key === 'K') && (e.metaKey || e.ctrlKey)) {
        e.preventDefault();
        setCmdOpen(o => !o);
      }
    };
    window.addEventListener('keydown', h);
    return () => window.removeEventListener('keydown', h);
  }, []);

  const runCommand = (id) => {
    if (id.startsWith('goto:')) setRoute(id.slice(5));
    // other commands are cosmetic for the prototype
  };

  const content = (() => {
    switch (route) {
      case 'maps':      return <window.MapEditor tweaks={tweaks}/>;
      case 'biomes':    return <window.BiomeEditor/>;
      case 'events':    return <window.EventsEditor/>;
      case 'plant':     return <window.PropEditor category="plant"/>;
      case 'animal':    return <window.PropEditor category="animal"/>;
      case 'mineral':   return <window.PropEditor category="mineral"/>;
      case 'structure': return <window.PropEditor category="structure"/>;
      case 'equipment': return <window.PropEditor category="equipment"/>;
      case 'storage':   return <window.PropEditor category="storage"/>;
      case 'recipes':   return <window.RecipeEditor/>;
      case 'journal':   return <window.JournalEditor/>;
      case 'cutscenes': return <window.CutsceneEditor/>;
      case 'settings':  return <window.SettingsEditor/>;
      default:          return <div style={{padding: 24}}>—</div>;
    }
  })();

  return (
    <>
      <div className="app-root" data-screen-label={`editor/${route}`}>
        <TitleBar chapter={chapter} setChapter={setChapter} dirty={dirty}
                  onCmdK={() => setCmdOpen(true)} tweaks={tweaks}/>
        <div className="main-row">
          <Sidebar route={route} setRoute={setRoute}/>
          <main className="main">
            {content}
          </main>
        </div>
        <StatusBar route={route} chapter={chapter}
                   hover={hoverHex} tool={toolState.tool} dirty={dirty} tweaks={tweaks}/>
      </div>
      <window.CommandPalette open={cmdOpen} onClose={() => setCmdOpen(false)} onAction={runCommand}/>
      <window.TweaksPanel open={editMode} tweaks={tweaks} setTweak={setTweak}
                          onClose={() => {
                            setEditMode(false);
                            try { window.parent.postMessage({ type: '__deactivate_edit_mode_request' }, '*'); } catch (e) {}
                          }}/>
    </>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App/>);
