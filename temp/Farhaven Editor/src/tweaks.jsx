/* Farhaven Editor — Tweaks panel */

const { useState: useStateT } = React;

function TweaksPanel({ open, tweaks, setTweak, onClose }) {
  if (!open) return null;
  const Seg = ({ k, options }) => (
    <div className="tweak-seg">
      {options.map(o => (
        <button key={o} className={tweaks[k] === o ? 'active' : ''} onClick={() => setTweak(k, o)}>{o}</button>
      ))}
    </div>
  );
  const Toggle = ({ k, label }) => (
    <div className={'tweak-toggle ' + (tweaks[k] ? 'on' : '')} onClick={() => setTweak(k, !tweaks[k])}>
      <span>{label}</span>
      <span className="sw"/>
    </div>
  );
  return (
    <div className="tweaks">
      <div className="tweaks-head">
        <span>Tweaks</span>
        <button onClick={onClose} style={{color: 'var(--text-2)'}}><window.Icon name="x" size={12}/></button>
      </div>
      <div className="tweaks-body">
        <div className="tweak-row">
          <div className="tlabel">Layout</div>
          <Seg k="layout" options={['classic','inspector-left','zen']}/>
        </div>
        <div className="tweak-row">
          <div className="tlabel">Density</div>
          <Seg k="density" options={['compact','comfortable']}/>
        </div>
        <div className="tweak-row">
          <div className="tlabel">Canvas Style</div>
          <Seg k="canvasStyle" options={['flat','elevation','biome-only']}/>
        </div>
        <div className="tweak-row">
          <div className="tlabel">Accent</div>
          <Seg k="accent" options={['amber','blue','green','violet']}/>
        </div>
        <Toggle k="showCoords" label="Show hex coordinates"/>
        <Toggle k="showElevationNumbers" label="Show elevation numbers"/>
        <Toggle k="showMinimap" label="Show minimap"/>
        <Toggle k="commandPaletteHint" label="Show ⌘K hint in titlebar"/>
      </div>
    </div>
  );
}

window.TweaksPanel = TweaksPanel;
