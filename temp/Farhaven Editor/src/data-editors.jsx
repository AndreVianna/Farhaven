/* Farhaven Editor — master-detail data editors (Biomes, Props, Recipes, Journal, Cutscenes, Events, Settings) */

const { useState: useStateD, useMemo: useMemoD } = React;

function MasterHeader({ search, setSearch, onNew, count }) {
  return (
    <div className="master-head">
      <div className="row-flex">
        <div className="search">
          <window.Icon name="search" size={12}/>
          <input placeholder="Search…" value={search} onChange={e => setSearch(e.target.value)}/>
        </div>
        <button className="icon-btn primary" onClick={onNew} title="New"><window.Icon name="plus" size={12}/></button>
      </div>
      <div style={{display:'flex', justifyContent:'space-between', fontSize: 10.5, color:'var(--text-2)', fontFamily:'var(--font-mono)', letterSpacing: 0.02, textTransform:'uppercase', fontWeight: 600}}>
        <span>{count} entries</span>
        <span>A–Z</span>
      </div>
    </div>
  );
}

/* ---------- Biome Editor ---------- */
function BiomeEditor() {
  const [sel, setSel] = useStateD('B00003');
  const [search, setSearch] = useStateD('');
  const biome = window.BIOME_BY_ID[sel];
  const filtered = window.BIOMES.filter(b => b.name.toLowerCase().includes(search.toLowerCase()) || b.id.toLowerCase().includes(search.toLowerCase()));

  return (
    <div className="master-detail">
      <div className="master">
        <MasterHeader search={search} setSearch={setSearch} count={filtered.length} onNew={() => {}}/>
        <div className="master-list">
          {filtered.map(b => (
            <div key={b.id} className={'master-row ' + (sel === b.id ? 'active' : '')} onClick={() => setSel(b.id)}>
              <div className="mr-swatch" style={{background: b.color}}/>
              <div className="mr-name">{b.name}</div>
              <div className="mr-id">{b.id}</div>
            </div>
          ))}
        </div>
      </div>
      <div className="detail">
        <div className="detail-head">
          <div className="head-swatch" style={{background: biome.color}}/>
          <div className="title-col">
            <div className="title">{biome.name}</div>
            <div className="sub">{biome.id} · elevation {biome.elev[0]}–{biome.elev[1]}</div>
          </div>
          <div className="actions">
            <button className="btn"><window.Icon name="download"/>Export .tres</button>
            <button className="btn danger"><window.Icon name="trash"/>Delete</button>
            <button className="btn primary"><window.Icon name="save"/>Save</button>
          </div>
        </div>
        <div className="detail-body">
          <div className="detail-form">
            <div className="section-title">Identity</div>
            <div className="row"><label>Display Name</label><div className="ctrl"><input className="input" defaultValue={biome.name}/></div></div>
            <div className="row"><label>ID</label><div className="ctrl"><input className="input" defaultValue={biome.id} disabled/></div></div>
            <div className="row"><label>Short Desc</label><div className="ctrl"><input className="input" defaultValue={biome.desc}/></div></div>
            <div className="row" style={{gridTemplateColumns:'80px 1fr', alignItems:'flex-start'}}>
              <label style={{paddingTop: 6}}>Long Desc</label>
              <div className="ctrl">
                <textarea className="input" rows={3} style={{height: 'auto', padding: '6px 8px', resize:'vertical'}} defaultValue="Wide meadows broken by stands of fiber-rich grass. Easy to cross, easy to spot what is around you, easy to be spotted in turn."/>
              </div>
            </div>

            <div className="section-title">Visual</div>
            <div className="row"><label>Base Color</label><div className="ctrl"><div className="color-row"><div className="color-swatch" style={{background: biome.color}}/><input className="input" defaultValue={biome.color} style={{flex: 1}}/></div></div></div>
            <div className="row"><label>Variations</label><div className="ctrl"><div className="color-mini-list">
              <div className="color-mini" style={{background: window.HEX.shadeHex(biome.color, -0.15)}}/>
              <div className="color-mini" style={{background: window.HEX.shadeHex(biome.color, 0.12)}}/>
              <div className="color-mini" style={{background: window.HEX.shadeHex(biome.color, -0.3)}}/>
              <div className="color-mini add">+</div>
            </div></div></div>

            <div className="section-title">Terrain</div>
            <div className="row"><label>Elev. Min</label><div className="ctrl"><div className="num"><input type="number" defaultValue={biome.elev[0]}/><button>+</button><button>−</button></div></div></div>
            <div className="row"><label>Elev. Max</label><div className="ctrl"><div className="num"><input type="number" defaultValue={biome.elev[1]}/><button>+</button><button>−</button></div></div></div>

            <div className="section-title">Resource Table</div>
            <div className="rtable">
              <div className="thead"><div>Prop</div><div>Chance</div><div>Min</div><div>Max</div><div/></div>
              {biome.resources.map((r, i) => {
                const p = window.PROP_BY_ID[r.prop] || { name: r.prop, color: '#888' };
                return (
                  <div key={i} className="trow">
                    <div className="cell-select"><span className="color-mini" style={{background: p.color, width: 12, height: 12}}/>{p.name}</div>
                    <div className="cell-num">{(r.chance*100).toFixed(0)}%</div>
                    <div className="cell-num">{r.min}</div>
                    <div className="cell-num">{r.max}</div>
                    <button className="rm-btn"><window.Icon name="x" size={10}/></button>
                  </div>
                );
              })}
            </div>
            <button className="rtable-add"><window.Icon name="plus" size={11}/>Add resource row</button>
          </div>

          <div className="detail-preview">
            <div className="section-title" style={{margin: 0, padding: 0, border: 'none'}}>Hex Preview</div>
            <svg viewBox="-60 -60 120 120" style={{width: '100%', aspectRatio: '1/1', background: 'var(--bg-0)', borderRadius: 6, border: '1px solid var(--line)'}}>
              {[[0,0],[1,-1],[-1,1],[1,0],[-1,0],[0,1],[0,-1]].map(([q,r], i) => {
                const [x, y] = window.HEX.hexToPixel(q, r, 18);
                return <path key={i} d={window.HEX.hexPath(x, y, 18)} fill={window.HEX.shadeHex(biome.color, (i%3-1)*0.06)} stroke="rgba(0,0,0,0.25)" strokeWidth="0.8"/>;
              })}
            </svg>
            <div className="section-title" style={{margin: 0, padding: 0, border: 'none'}}>Used In</div>
            <div style={{fontSize: 11.5, color:'var(--text-1)', display:'flex', flexDirection:'column', gap: 4}}>
              <div style={{display:'flex', justifyContent:'space-between'}}><span>ch1 Crash Landing</span><span style={{fontFamily:'var(--font-mono)', color:'var(--text-2)'}}>48</span></div>
              <div style={{display:'flex', justifyContent:'space-between'}}><span>ch2 The Ridgeline</span><span style={{fontFamily:'var(--font-mono)', color:'var(--text-2)'}}>112</span></div>
            </div>
            <div className="section-title" style={{margin: 0, padding: 0, border: 'none'}}>Metadata</div>
            <div style={{fontSize: 11, fontFamily:'var(--font-mono)', color:'var(--text-2)', lineHeight: 1.7}}>
              <div>uid: cgrassland001</div>
              <div>file: biomes/{biome.id}.tres</div>
              <div>textures: 4</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

/* ---------- Prop Editor ---------- */
function PropEditor({ category }) {
  const pool = category ? window.PROPS.filter(p => p.category === category) : window.PROPS;
  const [sel, setSel] = useStateD(pool[0]?.id || window.PROPS[0].id);
  const [search, setSearch] = useStateD('');
  const prop = window.PROP_BY_ID[sel] || pool[0];
  const filtered = pool.filter(p => p.name.toLowerCase().includes(search.toLowerCase()) || p.id.toLowerCase().includes(search.toLowerCase()));

  return (
    <div className="master-detail">
      <div className="master">
        <MasterHeader search={search} setSearch={setSearch} count={filtered.length} onNew={() => {}}/>
        <div className="master-list">
          {filtered.map(p => (
            <div key={p.id} className={'master-row ' + (sel === p.id ? 'active' : '')} onClick={() => setSel(p.id)}>
              <div className="mr-glyph" style={{color: p.color}}>{p.glyph}</div>
              <div className="mr-name">{p.name}</div>
              <div className="mr-meta">{p.rarity}</div>
              <div className="mr-id">{p.id}</div>
            </div>
          ))}
        </div>
      </div>
      <div className="detail">
        <div className="detail-head">
          <div className="head-swatch" style={{background: 'var(--bg-3)', display:'flex', alignItems:'center', justifyContent:'center', color: prop.color, fontFamily:'var(--font-mono)', fontSize: 12, fontWeight: 600}}>{prop.glyph}</div>
          <div className="title-col">
            <div className="title">{prop.name}</div>
            <div className="sub">{prop.id} · {prop.category} · {prop.rarity}</div>
          </div>
          <div className="actions">
            <button className="btn"><window.Icon name="download"/>.tres</button>
            <button className="btn danger"><window.Icon name="trash"/>Delete</button>
            <button className="btn primary"><window.Icon name="save"/>Save</button>
          </div>
        </div>
        <div className="detail-body">
          <div className="detail-form">
            <div className="section-title">Identity</div>
            <div className="row"><label>Display Name</label><div className="ctrl"><input className="input" defaultValue={prop.name}/></div></div>
            <div className="row"><label>ID</label><div className="ctrl"><input className="input" defaultValue={prop.id} disabled/></div></div>
            <div className="row"><label>Category</label><div className="ctrl">
              <select className="select" defaultValue={prop.category}>
                {['plant','animal','mineral','structure','stuff','equipment','vehicle','storage','fungi','ooze','liquid'].map(c =>
                  <option key={c}>{c}</option>)}
              </select>
            </div></div>
            <div className="row"><label>Rarity</label><div className="ctrl">
              <select className="select" defaultValue={prop.rarity}>
                {['common','uncommon','rare','unique'].map(c => <option key={c}>{c}</option>)}
              </select>
            </div></div>
            <div className="row"><label>Short Desc</label><div className="ctrl"><input className="input" defaultValue={prop.desc}/></div></div>

            <div className="section-title">Tags</div>
            <div className="row" style={{gridTemplateColumns:'80px 1fr'}}>
              <label>Tags</label>
              <div className="ctrl">
                <div className="tag-strip">
                  <div className="tag">resource_source<span className="x">×</span></div>
                  <div className="tag">harvestable<span className="x">×</span></div>
                  <div className="tag">+ add</div>
                </div>
              </div>
            </div>

            <div className="section-title">Placeable</div>
            <div className="row"><label>Footprint</label><div className="ctrl">
              <div style={{display:'flex', gap: 6}}>
                <div className="num" style={{flex:1}}><input type="number" defaultValue={1}/><button>+</button><button>−</button></div>
                <span style={{alignSelf:'center', color:'var(--text-2)', fontFamily:'var(--font-mono)'}}>×</span>
                <div className="num" style={{flex:1}}><input type="number" defaultValue={1}/><button>+</button><button>−</button></div>
              </div>
            </div></div>
            <div className="row"><label>Mesh Variants</label><div className="ctrl"><input className="input" defaultValue="mesh_v1.glb, mesh_v2.glb, mesh_v3.glb"/></div></div>

            <div className="section-title">Catalogable</div>
            <div className="row"><label>Scan Time</label><div className="ctrl">
              <div className="slider-row"><input type="range" min={0.5} max={10} step={0.5} defaultValue={1}/><span className="val">1.0s</span></div>
            </div></div>
            <div className="row"><label>Anomaly</label><div className="ctrl">
              <div className="tweak-toggle" style={{padding: 0}}><span style={{color:'var(--text-2)', fontSize: 11}}>Show as anomaly on catalog</span><span className="sw"/></div>
            </div></div>

            <div className="section-title">Harvestable</div>
            <div className="rtable">
              <div className="thead"><div>Yield</div><div>Amount</div><div>Condition</div><div></div><div/></div>
              <div className="trow"><div className="cell-select"><span className="color-mini" style={{background:'#7ec886', width:12, height:12}}/>plant_fiber</div><div className="cell-num">1</div><div className="cell-num" style={{fontSize: 10.5}}>—</div><div/><button className="rm-btn"><window.Icon name="x" size={10}/></button></div>
            </div>
            <button className="rtable-add"><window.Icon name="plus" size={11}/>Add yield</button>
          </div>

          <div className="detail-preview">
            <div className="section-title" style={{margin: 0, padding: 0, border: 'none'}}>Mesh Preview</div>
            <div style={{aspectRatio: '1/1', background: 'var(--bg-0)', borderRadius: 6, border: '1px solid var(--line)', display:'flex', alignItems:'center', justifyContent:'center', position:'relative'}}>
              <svg viewBox="0 0 100 100" style={{width: '70%', height: '70%'}}>
                <defs>
                  <pattern id="stripe-p" patternUnits="userSpaceOnUse" width="6" height="6" patternTransform="rotate(45)">
                    <line x1="0" y1="0" x2="0" y2="6" stroke={prop.color} strokeOpacity="0.35" strokeWidth="2"/>
                  </pattern>
                </defs>
                <rect x="10" y="10" width="80" height="80" fill="url(#stripe-p)" stroke={prop.color} strokeWidth="1.4" rx="4"/>
                <text x="50" y="52" textAnchor="middle" fill={prop.color} fontFamily="IBM Plex Mono" fontSize="14" fontWeight="600">{prop.glyph}</text>
                <text x="50" y="70" textAnchor="middle" fill="var(--text-2)" fontFamily="IBM Plex Mono" fontSize="6">{prop.id}.glb</text>
              </svg>
            </div>
            <div className="section-title" style={{margin: 0, padding: 0, border: 'none'}}>Drop Sources</div>
            <div style={{fontSize: 11.5, color:'var(--text-1)', display:'flex', flexDirection:'column', gap: 4}}>
              {window.BIOMES.filter(b => b.resources.some(r => r.prop === prop.id)).map(b =>
                <div key={b.id} style={{display:'flex', alignItems:'center', gap: 6}}>
                  <span className="biome-swatch" style={{background: b.color, width: 10, height: 10}}/>
                  <span style={{flex: 1}}>{b.name}</span>
                </div>
              )}
              {window.BIOMES.filter(b => b.resources.some(r => r.prop === prop.id)).length === 0 &&
                <div style={{color: 'var(--text-3)', fontSize: 11}}>Not used in any biome table.</div>}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

/* ---------- Recipe Editor ---------- */
function RecipeEditor() {
  const [sel, setSel] = useStateD('R00002');
  const [search, setSearch] = useStateD('');
  const recipe = window.RECIPES.find(r => r.id === sel);
  const filtered = window.RECIPES.filter(r => r.name.toLowerCase().includes(search.toLowerCase()));
  return (
    <div className="master-detail">
      <div className="master">
        <MasterHeader search={search} setSearch={setSearch} count={filtered.length} onNew={() => {}}/>
        <div className="master-list">
          {filtered.map(r => (
            <div key={r.id} className={'master-row ' + (sel === r.id ? 'active' : '')} onClick={() => setSel(r.id)}>
              <div className="mr-glyph"><window.Icon name="flask" size={10}/></div>
              <div className="mr-name">{r.name}</div>
              <div className="mr-meta">{r.station}</div>
              <div className="mr-id">{r.id}</div>
            </div>
          ))}
        </div>
      </div>
      <div className="detail">
        <div className="detail-head">
          <div className="head-swatch" style={{background:'var(--bg-3)', display:'flex', alignItems:'center', justifyContent:'center', color:'var(--amber)'}}><window.Icon name="flask" size={16}/></div>
          <div className="title-col">
            <div className="title">{recipe.name}</div>
            <div className="sub">{recipe.id} · {recipe.station} · {recipe.time}s</div>
          </div>
          <div className="actions">
            <button className="btn"><window.Icon name="download"/>.tres</button>
            <button className="btn primary"><window.Icon name="save"/>Save</button>
          </div>
        </div>
        <div className="detail-body">
          <div className="detail-form">
            <div className="section-title">Identity</div>
            <div className="row"><label>Name</label><div className="ctrl"><input className="input" defaultValue={recipe.name}/></div></div>
            <div className="row"><label>Station</label><div className="ctrl">
              <select className="select" defaultValue={recipe.station}><option>hand</option><option>workbench</option><option>forge</option></select>
            </div></div>
            <div className="row"><label>Time</label><div className="ctrl">
              <div className="slider-row"><input type="range" min={1} max={60} defaultValue={recipe.time}/><span className="val">{recipe.time}s</span></div>
            </div></div>

            <div className="section-title">Ingredients</div>
            {recipe.ingredients.map((ing, i) => (
              <div key={i} className="ingr-row">
                <div className="glyph">{(ing.prop[0]||'?').toUpperCase()}</div>
                <select className="select" style={{height: 24}} defaultValue={ing.prop}>
                  <option>{ing.prop}</option>
                </select>
                <div className="num"><input type="number" defaultValue={ing.qty}/><button>+</button><button>−</button></div>
                <button className="rm-btn" style={{color:'var(--text-2)'}}><window.Icon name="x" size={10}/></button>
              </div>
            ))}
            <button className="rtable-add"><window.Icon name="plus" size={11}/>Add ingredient</button>

            <div className="section-title">Output</div>
            <div className="ingr-row">
              <div className="glyph" style={{background:'var(--accent-bg)', color:'var(--accent)', borderColor:'color-mix(in oklab, var(--accent) 40%, transparent)'}}>{(recipe.output.prop[0]||'?').toUpperCase()}</div>
              <select className="select" style={{height: 24}} defaultValue={recipe.output.prop}><option>{recipe.output.prop}</option></select>
              <div className="num"><input type="number" defaultValue={recipe.output.qty}/><button>+</button><button>−</button></div>
              <div/>
            </div>
          </div>
          <div className="detail-preview">
            <div className="section-title" style={{margin: 0, padding: 0, border: 'none'}}>Flow</div>
            <svg viewBox="0 0 240 140" style={{width:'100%', background:'var(--bg-0)', borderRadius: 6, border:'1px solid var(--line)'}}>
              {recipe.ingredients.map((ing, i) => (
                <g key={i} transform={`translate(20, ${14 + i*30})`}>
                  <rect width="80" height="22" rx="3" fill="var(--bg-2)" stroke="var(--line-2)"/>
                  <text x="8" y="15" fontFamily="IBM Plex Mono" fontSize="10" fill="var(--text-0)">{ing.qty}× {ing.prop.slice(0,9)}</text>
                  <path d={`M100 11 L150 ${70 - 14 - i*30 + 70}`} stroke="var(--text-2)" strokeDasharray="2 2" fill="none"/>
                </g>
              ))}
              <g transform="translate(150, 56)">
                <rect width="80" height="28" rx="4" fill="var(--accent-bg)" stroke="var(--accent)"/>
                <text x="8" y="12" fontFamily="IBM Plex Mono" fontSize="9" fill="var(--text-2)">{recipe.time}s · {recipe.station}</text>
                <text x="8" y="23" fontFamily="IBM Plex Mono" fontSize="10" fill="var(--accent)" fontWeight="600">{recipe.output.qty}× {recipe.output.prop.slice(0,9)}</text>
              </g>
            </svg>
          </div>
        </div>
      </div>
    </div>
  );
}

/* ---------- Journal Editor ---------- */
function JournalEditor() {
  const [sel, setSel] = useStateD('J0003');
  const [search, setSearch] = useStateD('');
  const entry = window.JOURNAL.find(j => j.id === sel);
  const filtered = window.JOURNAL.filter(j => j.title.toLowerCase().includes(search.toLowerCase()));
  return (
    <div className="master-detail">
      <div className="master">
        <MasterHeader search={search} setSearch={setSearch} count={filtered.length} onNew={() => {}}/>
        <div className="master-list">
          <div className="section-label">Chapter 1</div>
          {filtered.map(j => (
            <div key={j.id} className={'master-row ' + (sel === j.id ? 'active' : '')} onClick={() => setSel(j.id)}>
              <div className="mr-glyph"><window.Icon name="book" size={10}/></div>
              <div className="mr-name">{j.title}</div>
              <div className="mr-meta">D{j.day}</div>
              <div className="mr-id">{j.id}</div>
            </div>
          ))}
        </div>
      </div>
      <div className="detail">
        <div className="detail-head">
          <div className="head-swatch" style={{background:'var(--bg-3)', display:'flex', alignItems:'center', justifyContent:'center', color:'var(--gold)'}}><window.Icon name="book" size={16}/></div>
          <div className="title-col">
            <div className="title">{entry.title}</div>
            <div className="sub">{entry.id} · Day {entry.day}</div>
          </div>
          <div className="actions">
            <button className="btn primary"><window.Icon name="save"/>Save</button>
          </div>
        </div>
        <div className="detail-body">
          <div className="detail-form" style={{maxWidth: 720}}>
            <div className="section-title">Entry</div>
            <div className="row"><label>Title</label><div className="ctrl"><input className="input" defaultValue={entry.title}/></div></div>
            <div className="row"><label>Day Unlock</label><div className="ctrl"><div className="num"><input type="number" defaultValue={entry.day}/><button>+</button><button>−</button></div></div></div>
            <div className="row"><label>Trigger</label><div className="ctrl"><input className="input" defaultValue="phase_change:dawn"/></div></div>

            <div className="section-title">Body</div>
            <textarea className="input" style={{height: 180, padding: '10px 12px', lineHeight: 1.6, fontFamily:'var(--font-sans)', fontSize: 13, resize: 'vertical'}} defaultValue={entry.body + '\n\nThe soil here holds warmth long after dusk. If the radio is still alive, it is quiet for now.'}/>

            <div className="section-title">Illustration</div>
            <div style={{aspectRatio:'16/9', background:'var(--bg-2)', border:'1px dashed var(--line-2)', borderRadius: 6, display:'flex', alignItems:'center', justifyContent:'center', color:'var(--text-2)', fontFamily:'var(--font-mono)', fontSize: 11.5}}>
              drop illustration · 1920×1080
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

/* ---------- Cutscene Editor ---------- */
function CutsceneEditor() {
  const [sel, setSel] = useStateD('C0001');
  const [search, setSearch] = useStateD('');
  const c = window.CUTSCENES.find(x => x.id === sel);
  const filtered = window.CUTSCENES.filter(x => x.name.toLowerCase().includes(search.toLowerCase()));
  return (
    <div className="master-detail">
      <div className="master">
        <MasterHeader search={search} setSearch={setSearch} count={filtered.length} onNew={() => {}}/>
        <div className="master-list">
          {filtered.map(x => (
            <div key={x.id} className={'master-row ' + (sel === x.id ? 'active' : '')} onClick={() => setSel(x.id)}>
              <div className="mr-glyph"><window.Icon name="film" size={10}/></div>
              <div className="mr-name">{x.name}</div>
              <div className="mr-meta">{x.frames}f</div>
              <div className="mr-id">{x.id}</div>
            </div>
          ))}
        </div>
      </div>
      <div className="detail">
        <div className="detail-head">
          <div className="head-swatch" style={{background:'var(--bg-3)', display:'flex', alignItems:'center', justifyContent:'center', color:'var(--violet)'}}><window.Icon name="film" size={16}/></div>
          <div className="title-col">
            <div className="title">{c.name}</div>
            <div className="sub">{c.id} · trigger: {c.trigger}</div>
          </div>
          <div className="actions">
            <button className="btn"><window.Icon name="redo"/>Preview</button>
            <button className="btn primary"><window.Icon name="save"/>Save</button>
          </div>
        </div>
        <div className="detail-body" style={{flexDirection:'column'}}>
          <div style={{padding: '12px 18px', borderBottom: '1px solid var(--line)', display:'flex', gap: 18, alignItems:'center'}}>
            <div style={{display:'flex', flexDirection:'column', gap: 2}}>
              <span style={{fontSize: 10.5, color:'var(--text-2)', textTransform:'uppercase', letterSpacing: 0.04}}>Trigger</span>
              <span style={{fontFamily:'var(--font-mono)', color:'var(--text-0)'}}>{c.trigger}</span>
            </div>
            <div style={{display:'flex', flexDirection:'column', gap: 2}}>
              <span style={{fontSize: 10.5, color:'var(--text-2)', textTransform:'uppercase', letterSpacing: 0.04}}>Skip</span>
              <span style={{fontFamily:'var(--font-mono)', color:'var(--text-0)'}}>allowed after 2s</span>
            </div>
          </div>
          {/* Timeline */}
          <div style={{padding: 18}}>
            <div style={{fontSize: 10.5, color:'var(--text-2)', textTransform:'uppercase', letterSpacing: 0.06, fontWeight: 600, marginBottom: 10}}>Frames</div>
            <div style={{display:'grid', gridTemplateColumns: `repeat(${c.frames}, 1fr)`, gap: 12}}>
              {Array.from({length: c.frames}).map((_, i) => (
                <div key={i} style={{aspectRatio:'16/9', background:'var(--bg-1)', border:'1px solid var(--line-2)', borderRadius: 6, position:'relative', overflow:'hidden'}}>
                  <svg viewBox="0 0 160 90" style={{width:'100%', height:'100%', display:'block'}}>
                    <defs>
                      <linearGradient id={`frg-${i}`} x1="0" y1="0" x2="0" y2="1">
                        <stop offset="0" stopColor={i % 2 ? '#2a3040' : '#3a2820'}/>
                        <stop offset="1" stopColor="#14151a"/>
                      </linearGradient>
                    </defs>
                    <rect width="160" height="90" fill={`url(#frg-${i})`}/>
                    <path d="M0 70 L40 50 L80 60 L120 45 L160 55 L160 90 L0 90Z" fill="#1a1a22" opacity="0.7"/>
                    <circle cx={30 + i*30} cy={30} r="6" fill="#f4a261" opacity="0.8"/>
                    <text x="6" y="84" fontFamily="IBM Plex Mono" fontSize="6" fill="rgba(255,255,255,0.4)">FRAME {i+1}</text>
                  </svg>
                  <div style={{position:'absolute', top: 4, left: 6, fontSize: 10, color:'var(--text-1)', fontFamily:'var(--font-mono)'}}>{i+1}/{c.frames}</div>
                </div>
              ))}
            </div>
            <div style={{marginTop: 12, fontSize: 10.5, color:'var(--text-2)', textTransform:'uppercase', letterSpacing: 0.06, fontWeight: 600}}>Script</div>
            <div style={{marginTop: 6, display:'flex', flexDirection:'column', gap: 4, fontFamily:'var(--font-mono)', fontSize: 11.5, color:'var(--text-1)'}}>
              <div><span style={{color:'var(--text-2)'}}>01 </span><span style={{color:'var(--accent)'}}>fade_in</span> 1.2s</div>
              <div><span style={{color:'var(--text-2)'}}>02 </span><span style={{color:'var(--accent)'}}>dialog</span> "…systems offline. Running on auxiliary."</div>
              <div><span style={{color:'var(--text-2)'}}>03 </span><span style={{color:'var(--accent)'}}>wait</span> 2.0s</div>
              <div><span style={{color:'var(--text-2)'}}>04 </span><span style={{color:'var(--accent)'}}>dialog</span> "Scanner check. Coordinates… unknown planet."</div>
              <div><span style={{color:'var(--text-2)'}}>05 </span><span style={{color:'var(--accent)'}}>fade_out</span> 0.8s</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

/* ---------- Events Editor (compact list) ---------- */
function EventsEditor() {
  return (
    <div className="master-detail">
      <div className="master" style={{width: 320, minWidth: 320}}>
        <MasterHeader search="" setSearch={() => {}} count={window.EVENTS.length} onNew={() => {}}/>
        <div className="master-list">
          {window.EVENTS.map(e => (
            <div key={e.id} className="master-row">
              <div className="mr-glyph"><window.Icon name="bolt" size={10}/></div>
              <div className="mr-name">{e.name}</div>
              <div className="mr-meta">{(e.rarity*100).toFixed(0)}%</div>
              <div className="mr-id">{e.id}</div>
            </div>
          ))}
        </div>
      </div>
      <div className="detail">
        <div className="empty-state">
          <div className="big"><window.Icon name="bolt" size={28}/></div>
          <div>Select an event to edit its schedule, rarity and effects.</div>
          <div className="sub">Events are world-triggered side-effects — weather, fauna spawns, narrative beats.</div>
        </div>
      </div>
    </div>
  );
}

/* ---------- Settings Editor ---------- */
function SettingsEditor() {
  return (
    <div style={{flex: 1, display:'flex', minHeight: 0, background: 'var(--bg-0)', padding: 24, overflow:'auto'}}>
      <div style={{width: 720, margin: '0 auto', display:'flex', flexDirection:'column', gap: 22}}>
        <div>
          <div style={{fontSize: 18, fontWeight: 600, color:'var(--text-0)'}}>Game Settings</div>
          <div style={{fontSize: 12, color:'var(--text-2)', fontFamily:'var(--font-mono)', marginTop: 4}}>data/game_settings.tres</div>
        </div>

        {[
          { title: 'World', rows: [
            ['Default chapter', 'ch1'],
            ['Hex size', '3.0'],
            ['Day length (min)', '20'],
            ['Dusk length (min)', '4'],
          ]},
          { title: 'Player', rows: [
            ['Spawn HP', '100'],
            ['Hunger rate', '1.0 / min'],
            ['Thirst rate', '1.3 / min'],
            ['Move speed', '3.5 u/s'],
          ]},
          { title: 'Scanner', rows: [
            ['Base range', '2 hexes'],
            ['Upgrade tiers', '4'],
            ['Anomaly bias', '0.6'],
          ]},
          { title: 'Performance', rows: [
            ['Max visible hexes', '120'],
            ['Texture variants', '4'],
            ['Shadow quality', 'medium'],
          ]},
        ].map(group => (
          <div key={group.title} style={{background:'var(--bg-1)', border:'1px solid var(--line)', borderRadius: 6}}>
            <div style={{padding: '10px 14px', borderBottom:'1px solid var(--line)', fontSize: 12, fontWeight: 600, color:'var(--text-0)'}}>{group.title}</div>
            <div style={{padding: 8}}>
              {group.rows.map(([k, v]) => (
                <div className="row" key={k} style={{gridTemplateColumns:'200px 1fr'}}>
                  <label>{k}</label>
                  <div className="ctrl"><input className="input" defaultValue={v}/></div>
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

window.BiomeEditor = BiomeEditor;
window.PropEditor = PropEditor;
window.RecipeEditor = RecipeEditor;
window.JournalEditor = JournalEditor;
window.CutsceneEditor = CutsceneEditor;
window.EventsEditor = EventsEditor;
window.SettingsEditor = SettingsEditor;
