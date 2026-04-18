/* Farhaven Editor — inline SVG icons (16x16) */

const Icon = ({ name, size = 16, className, style }) => {
  const S = size;
  const p = { width: S, height: S, viewBox: '0 0 16 16', fill: 'none', stroke: 'currentColor', strokeWidth: 1.35, strokeLinecap: 'round', strokeLinejoin: 'round', className, style };
  switch (name) {
    case 'cursor':    return <svg {...p}><path d="M3 2l10 5.5-4.5 1.5L7 14 3 2z"/></svg>;
    case 'hand':      return <svg {...p}><path d="M5 7V3.5a1 1 0 1 1 2 0V7"/><path d="M7 7V2.5a1 1 0 1 1 2 0V7"/><path d="M9 7V3.5a1 1 0 1 1 2 0V8"/><path d="M11 7.5V5.5a1 1 0 1 1 2 0v5c0 2.5-1.5 4-4 4s-4.5-1.5-5-3.5L2.5 8a1 1 0 0 1 1.6-1.1L5 8"/></svg>;
    case 'brush':     return <svg {...p}><path d="M3 13c0-1.5 1.5-2 2.5-2s2 .5 2 2c0 1-1 1.5-2.5 1.5S3 14 3 13z"/><path d="M7.5 11l6-6a1.4 1.4 0 0 1 2 2l-6 6"/></svg>;
    case 'bucket':    return <svg {...p}><path d="M3 6l5-3 5 3-5 3-5-3z"/><path d="M3 6v3l5 3 5-3V6"/><circle cx="12.5" cy="12" r="1.5"/></svg>;
    case 'mountain':  return <svg {...p}><path d="M2 13l4-7 3 4 2-2 3 5z"/></svg>;
    case 'tree':      return <svg {...p}><path d="M8 2l4 5H9v3h4l-5 4-5-4h4V7H4z"/></svg>;
    case 'pin':       return <svg {...p}><path d="M8 1.5c3 0 5 2 5 4.5 0 3.5-5 8.5-5 8.5S3 9.5 3 6c0-2.5 2-4.5 5-4.5z"/><circle cx="8" cy="6" r="1.5"/></svg>;
    case 'eraser':    return <svg {...p}><path d="M3 11l5-5 4 4-5 5H5l-2-2v-2z"/><path d="M8 6l4 4"/><path d="M2 14h12"/></svg>;
    case 'trash':     return <svg {...p}><path d="M3 4h10"/><path d="M5 4V2.5h6V4"/><path d="M4 4l1 10h6l1-10"/><path d="M7 7v5M9 7v5"/></svg>;
    case 'spark':     return <svg {...p}><path d="M8 2v3M8 11v3M2 8h3M11 8h3M4.5 4.5l2 2M9.5 9.5l2 2M4.5 11.5l2-2M9.5 6.5l2-2"/></svg>;
    case 'map':       return <svg {...p}><path d="M2 4l4-2 4 2 4-2v10l-4 2-4-2-4 2V4z"/><path d="M6 2v10M10 4v10"/></svg>;
    case 'layers':    return <svg {...p}><path d="M8 2l6 3-6 3-6-3 6-3z"/><path d="M2 8l6 3 6-3"/><path d="M2 11l6 3 6-3"/></svg>;
    case 'grid':      return <svg {...p}><rect x="2" y="2" width="5" height="5"/><rect x="9" y="2" width="5" height="5"/><rect x="2" y="9" width="5" height="5"/><rect x="9" y="9" width="5" height="5"/></svg>;
    case 'hex':       return <svg {...p}><path d="M8 1.5l5.5 3v7L8 14.5 2.5 11.5v-7L8 1.5z"/></svg>;
    case 'eye':       return <svg {...p}><path d="M1.5 8s2.5-4.5 6.5-4.5 6.5 4.5 6.5 4.5-2.5 4.5-6.5 4.5S1.5 8 1.5 8z"/><circle cx="8" cy="8" r="2"/></svg>;
    case 'eye-off':   return <svg {...p}><path d="M2 8s2.5-4.5 6-4.5c1 0 2 .3 3 .7"/><path d="M14 8s-2.5 4.5-6 4.5c-1 0-2-.2-3-.7"/><path d="M2 2l12 12"/></svg>;
    case 'search':    return <svg {...p}><circle cx="7" cy="7" r="4.5"/><path d="M10.5 10.5l3 3"/></svg>;
    case 'plus':      return <svg {...p}><path d="M8 3v10M3 8h10"/></svg>;
    case 'minus':     return <svg {...p}><path d="M3 8h10"/></svg>;
    case 'x':         return <svg {...p}><path d="M4 4l8 8M12 4l-8 8"/></svg>;
    case 'chevron':   return <svg {...p}><path d="M4 6l4 4 4-4"/></svg>;
    case 'chev-r':    return <svg {...p}><path d="M6 4l4 4-4 4"/></svg>;
    case 'undo':      return <svg {...p}><path d="M5 4L2 7l3 3"/><path d="M2 7h8a4 4 0 0 1 0 8H7"/></svg>;
    case 'redo':      return <svg {...p}><path d="M11 4l3 3-3 3"/><path d="M14 7H6a4 4 0 0 0 0 8h3"/></svg>;
    case 'save':      return <svg {...p}><path d="M2 3h9l3 3v8H2z"/><path d="M4 3v4h7V3"/><rect x="5" y="9" width="6" height="5"/></svg>;
    case 'zoom-in':   return <svg {...p}><circle cx="7" cy="7" r="4.5"/><path d="M10.5 10.5l3 3M5 7h4M7 5v4"/></svg>;
    case 'zoom-out':  return <svg {...p}><circle cx="7" cy="7" r="4.5"/><path d="M10.5 10.5l3 3M5 7h4"/></svg>;
    case 'target':    return <svg {...p}><circle cx="8" cy="8" r="5"/><circle cx="8" cy="8" r="1.5"/><path d="M8 1v2M8 13v2M1 8h2M13 8h2"/></svg>;
    case 'book':      return <svg {...p}><path d="M3 3h4a2 2 0 0 1 2 2v8a2 2 0 0 0-2-2H3V3z"/><path d="M13 3H9a2 2 0 0 0-2 2v8a2 2 0 0 1 2-2h4V3z"/></svg>;
    case 'flask':     return <svg {...p}><path d="M6 2h4M6.5 2v4.5L3 13a1 1 0 0 0 .9 1.5h8.2a1 1 0 0 0 .9-1.5L9.5 6.5V2"/><path d="M5 10h6"/></svg>;
    case 'cube':      return <svg {...p}><path d="M8 1.5l6 3v7L8 14.5l-6-3v-7l6-3z"/><path d="M2 4.5l6 3 6-3M8 7.5v7"/></svg>;
    case 'leaf':      return <svg {...p}><path d="M3 13c0-6 4-10 11-10-1 8-4 11-11 11-.5-.5-1-1-1-1z"/><path d="M3 13l5-5"/></svg>;
    case 'rocks':     return <svg {...p}><path d="M3 12l3-5 3 4-2 2H3z"/><path d="M7 13l3-5 4 5H7z"/></svg>;
    case 'drop':      return <svg {...p}><path d="M8 2s4 5 4 8a4 4 0 0 1-8 0c0-3 4-8 4-8z"/></svg>;
    case 'house':     return <svg {...p}><path d="M2 8l6-5 6 5v6H2V8z"/><path d="M6 14V9h4v5"/></svg>;
    case 'bug':       return <svg {...p}><ellipse cx="8" cy="9" rx="3" ry="4"/><path d="M5 9H2M11 9h3M5 6l-2-2M11 6l2-2M8 5V2"/></svg>;
    case 'film':      return <svg {...p}><rect x="2" y="3" width="12" height="10"/><path d="M2 5h12M2 11h12M5 3v10M11 3v10"/></svg>;
    case 'bolt':      return <svg {...p}><path d="M8 1l-4 8h3l-1 6 5-8H8l1-6z" fill="currentColor" stroke="none"/></svg>;
    case 'gear':      return <svg {...p}><circle cx="8" cy="8" r="2"/><path d="M8 1v2M8 13v2M1 8h2M13 8h2M3.5 3.5l1.5 1.5M11 11l1.5 1.5M3.5 12.5L5 11M11 5l1.5-1.5"/></svg>;
    case 'menu':      return <svg {...p}><path d="M2 4h12M2 8h12M2 12h12"/></svg>;
    case 'download':  return <svg {...p}><path d="M8 2v8M4.5 6.5L8 10l3.5-3.5M2 13h12"/></svg>;
    case 'upload':    return <svg {...p}><path d="M8 10V2M4.5 5.5L8 2l3.5 3.5M2 13h12"/></svg>;
    case 'dot':       return <svg {...p}><circle cx="8" cy="8" r="2" fill="currentColor" stroke="none"/></svg>;
    case 'paw':       return <svg {...p}><circle cx="4.5" cy="6" r="1.5"/><circle cx="8" cy="4" r="1.5"/><circle cx="11.5" cy="6" r="1.5"/><path d="M4 11c0-2 2-3 4-3s4 1 4 3c0 1.5-1.5 2.5-4 2.5S4 12.5 4 11z"/></svg>;
    case 'tool':      return <svg {...p}><path d="M11 2a3 3 0 0 0-3 3c0 .4.1.7.2 1L3 11l2 2 5-5c.3.1.6.2 1 .2a3 3 0 0 0 3-3c0-.4-.1-.7-.2-1L12 6l-2-2 2-2c-.3-.1-.6 0-1 0z"/></svg>;
    case 'box':       return <svg {...p}><path d="M2 5l6-3 6 3v8l-6 3-6-3V5z"/><path d="M2 5l6 3 6-3M8 8v7"/></svg>;
    case 'play':      return <svg {...p}><path d="M4 3l9 5-9 5V3z" fill="currentColor" stroke="none"/></svg>;
    case 'git':       return <svg {...p}><circle cx="5" cy="4" r="1.5"/><circle cx="5" cy="12" r="1.5"/><circle cx="12" cy="8" r="1.5"/><path d="M5 5.5v5M5 8h3a3 3 0 0 0 3-3"/></svg>;
    default:          return <svg {...p}><circle cx="8" cy="8" r="4"/></svg>;
  }
};

window.Icon = Icon;
