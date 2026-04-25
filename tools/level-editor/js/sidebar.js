/* ============================================================
 * Farhaven Editor — Sidebar navigation (Phase 2)
 *
 * Hierarchical domain-grouped sidebar replacing the flat tab bar.
 * Data-driven from NAV[] array; each item can expose a live count
 * (via factory function) or a badge (e.g. dirty-tabs count).
 * ============================================================ */

import { iconSvg } from './icons.js';
import { ProjectContext } from './file-discovery.js';

/**
 * Count props in a given category from ProjectContext.
 * @param {string} category
 * @returns {number}
 */
function _countPropsByCategory(category) {
  let n = 0;
  for (const [, entry] of ProjectContext.files.props) {
    const d = entry && entry.data;
    if (!d) continue;
    if (d.category === category) n++;
  }
  return n;
}

/**
 * NAV definition — single source of truth for the sidebar.
 * Items are grouped by `section`. Order within the array drives
 * render order. `icon` is a key for iconSvg(). `count` is a factory
 * that returns a number; `badge` is either a factory or a literal
 * string rendered as an amber pill.
 *
 * @type {Array<{id: string, section: string, label: string, icon: string, count?: () => number, badge?: string | (() => string)}>}
 */
export const NAV = [
  { id: 'map',       section: 'WORLD',     label: 'Maps',       icon: 'map',     count: () => ProjectContext.files.maps.size },
  { id: 'biomes',    section: 'WORLD',     label: 'Biomes',     icon: 'brush',   count: () => ProjectContext.files.biomes.size },
  { id: 'events',    section: 'WORLD',     label: 'Events',     icon: 'bolt',    count: () => ProjectContext.files.events.size },

  { id: 'plant',     section: 'PROPS',     label: 'Flora',      icon: 'leaf',    count: () => _countPropsByCategory('plant') },
  { id: 'animal',    section: 'PROPS',     label: 'Fauna',      icon: 'paw',     count: () => _countPropsByCategory('animal') },
  { id: 'mineral',   section: 'PROPS',     label: 'Minerals',   icon: 'rocks',   count: () => _countPropsByCategory('mineral') },
  { id: 'fungi',     section: 'PROPS',     label: 'Fungi',      icon: 'drop',    count: () => _countPropsByCategory('fungi') },
  { id: 'ooze',      section: 'PROPS',     label: 'Oozes',      icon: 'drop',    count: () => _countPropsByCategory('ooze') },
  { id: 'liquid',    section: 'PROPS',     label: 'Liquids',    icon: 'drop',    count: () => _countPropsByCategory('liquid') },
  { id: 'debris',    section: 'PROPS',     label: 'Debris',     icon: 'trash',   count: () => _countPropsByCategory('debris') },
  { id: 'stuff',     section: 'PROPS',     label: 'Stuff',      icon: 'cube',    count: () => _countPropsByCategory('stuff') },
  { id: 'structure', section: 'PROPS',     label: 'Structures', icon: 'house',   count: () => _countPropsByCategory('structure') },
  { id: 'equipment', section: 'PROPS',     label: 'Equipment',  icon: 'tool',    count: () => _countPropsByCategory('equipment') },
  { id: 'vehicle',   section: 'PROPS',     label: 'Vehicles',   icon: 'cube',    count: () => _countPropsByCategory('vehicle') },
  { id: 'storage',   section: 'PROPS',     label: 'Storage',    icon: 'box',     count: () => _countPropsByCategory('storage') },

  { id: 'recipes',   section: 'SYSTEMS',   label: 'Recipes',    icon: 'flask',   count: () => ProjectContext.files.recipes.size },

  { id: 'journal',   section: 'NARRATIVE', label: 'Journal',    icon: 'book',    count: () => ProjectContext.files.journal.size },
  { id: 'cutscenes', section: 'NARRATIVE', label: 'Cutscenes',  icon: 'film',    count: () => ProjectContext.files.cutscenes.size },

  { id: 'settings',  section: 'PROJECT',   label: 'Settings',   icon: 'gear' },
];

/**
 * Mount the Sidebar into the given container.
 *
 * @param {HTMLElement} container - target <aside class="sidebar">
 * @param {Object} options
 * @param {(id: string) => void} options.onRouteChange - called when a nav-item is clicked
 * @param {() => string} [options.activeRouteId] - returns the currently-active route id
 * @returns {{ refresh: () => void, setActive: (id: string) => void }}
 */
export function mountSidebar(container, options) {
  const onRouteChange = options.onRouteChange;
  const getActive = options.activeRouteId || (() => null);
  let activeId = getActive() || NAV[0].id;

  /** @type {Map<string, HTMLElement>} nav-item element per id */
  const itemEls = new Map();

  container.innerHTML = '';

  // Project header
  const proj = document.createElement('div');
  proj.className = 'side-project';
  const projName = document.createElement('div');
  projName.className = 'side-project-name';
  projName.innerHTML = '<span class="status-dot"></span><span>farhaven</span>';
  const projMeta = document.createElement('div');
  projMeta.className = 'side-project-meta';
  projMeta.textContent = 'Level Editor';
  proj.appendChild(projName);
  proj.appendChild(projMeta);
  container.appendChild(proj);

  // Group items by section
  const sections = new Map();
  for (const item of NAV) {
    if (!sections.has(item.section)) sections.set(item.section, []);
    sections.get(item.section).push(item);
  }

  for (const [sectionName, items] of sections) {
    const section = document.createElement('div');
    section.className = 'side-section';

    const header = document.createElement('div');
    header.className = 'side-header';
    const headerLabel = document.createElement('span');
    headerLabel.textContent = sectionName;
    header.appendChild(headerLabel);
    section.appendChild(header);

    for (const item of items) {
      const el = document.createElement('div');
      el.className = 'nav-item';
      el.dataset.routeId = item.id;
      if (item.id === activeId) el.classList.add('active');

      const iconWrap = document.createElement('span');
      iconWrap.className = 'nav-icon';
      iconWrap.innerHTML = iconSvg(item.icon, 14);
      el.appendChild(iconWrap);

      const label = document.createElement('span');
      label.className = 'label';
      label.textContent = item.label;
      el.appendChild(label);

      // Count / badge (populated on refresh)
      if (item.count || item.badge) {
        const indicator = document.createElement('span');
        indicator.className = item.badge ? 'badge' : 'count';
        indicator.dataset.indicator = item.id;
        el.appendChild(indicator);
      }

      el.addEventListener('click', () => {
        if (item.id === activeId) return;
        activeId = item.id;
        _syncActive();
        if (onRouteChange) onRouteChange(item.id);
      });

      itemEls.set(item.id, el);
      section.appendChild(el);
    }

    container.appendChild(section);
  }

  function _syncActive() {
    for (const [id, el] of itemEls) {
      el.classList.toggle('active', id === activeId);
    }
  }

  function refresh() {
    for (const item of NAV) {
      if (!item.count && !item.badge) continue;
      const el = itemEls.get(item.id);
      if (!el) continue;
      const indicator = el.querySelector('[data-indicator]');
      if (!indicator) continue;
      if (item.badge) {
        const value = typeof item.badge === 'function' ? item.badge() : item.badge;
        if (value && value !== '0' && value !== 0) {
          indicator.textContent = String(value);
          indicator.style.display = '';
        } else {
          indicator.style.display = 'none';
        }
      } else if (item.count) {
        const n = item.count();
        if (n > 0) {
          indicator.textContent = String(n);
          indicator.style.display = '';
        } else {
          indicator.style.display = 'none';
        }
      }
    }
  }

  function setActive(id) {
    if (id === activeId) return;
    activeId = id;
    _syncActive();
  }

  refresh();

  return { refresh, setActive };
}
