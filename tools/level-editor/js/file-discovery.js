// ============================================================
// ProjectContext (task-002)
// ============================================================

import { TresParser } from './tres-parser.js';

/** @type {Object} Global singleton holding all project state after discovery. */
export const ProjectContext = {
  /** @type {FileSystemDirectoryHandle|null} */
  rootHandle: null,
  /** @type {boolean} */
  hasFileSystemAccess: typeof window.showDirectoryPicker === 'function',
  files: {
    /** @type {Map<string, {handle: FileSystemFileHandle|null, data: Object}>} */
    maps: new Map(),
    /** @type {Map<string, {handle: FileSystemFileHandle|null, data: Object, raw: import('./tres-parser.js').TresFile}>} */
    resources: new Map(),
    /** @type {Map<string, {handle: FileSystemFileHandle|null, data: Object, raw: import('./tres-parser.js').TresFile}>} */
    biomes: new Map(),
  },
};

// ============================================================
// FileDiscovery (task-002)
// ============================================================

export class FileDiscovery {
  /**
   * Navigate from root to a subdirectory path like 'data/maps'.
   * @param {FileSystemDirectoryHandle} rootHandle
   * @param {string} path
   * @returns {Promise<FileSystemDirectoryHandle|null>}
   */
  static async getSubdirectory(rootHandle, path) {
    const parts = path.split('/');
    let current = rootHandle;
    for (const part of parts) {
      try {
        current = await current.getDirectoryHandle(part);
      } catch (err) {
        return null;
      }
    }
    return current;
  }

  /**
   * Scan a directory for files matching the given extension.
   * @param {FileSystemDirectoryHandle} rootHandle
   * @param {string} path - Subdirectory path e.g. 'data/maps'
   * @param {string} extension - File extension e.g. '.json'
   * @returns {Promise<Array<{name: string, handle: FileSystemFileHandle}>>}
   */
  static async scanDirectory(rootHandle, path, extension) {
    const dirHandle = await FileDiscovery.getSubdirectory(rootHandle, path);
    if (!dirHandle) {
      console.warn(`FileDiscovery: Directory "${path}" not found. Continuing without it.`);
      return [];
    }
    const results = [];
    for await (const [name, handle] of dirHandle) {
      if (handle.kind === 'file' && name.endsWith(extension)) {
        results.push({ name, handle });
      }
    }
    return results;
  }

  /**
   * Full discovery flow: validate root, scan all three dirs, parse files.
   * @param {FileSystemDirectoryHandle} rootHandle
   * @returns {Promise<{success: boolean, error?: string}>}
   */
  static async discoverProject(rootHandle) {
    console.group('FileDiscovery.discoverProject');
    console.log(`Root directory: "${rootHandle.name}"`);

    // Validate project root
    try {
      await rootHandle.getFileHandle('project.godot');
      console.log('project.godot found — valid Godot project.');
    } catch (err) {
      console.error('project.godot NOT found. Aborting.');
      console.groupEnd();
      return { success: false, error: 'Not a Godot project. Please select the folder containing project.godot.' };
    }

    ProjectContext.rootHandle = rootHandle;

    // Scan directories
    const mapFiles = await FileDiscovery.scanDirectory(rootHandle, 'data/maps', '.json');
    const resourceFiles = await FileDiscovery.scanDirectory(rootHandle, 'data/resources', '.tres');
    const biomeFiles = await FileDiscovery.scanDirectory(rootHandle, 'data/biomes', '.tres');
    console.log(`Scan results — maps: ${mapFiles.length}, resources: ${resourceFiles.length}, biomes: ${biomeFiles.length}`);

    // Parse map files
    for (const { name, handle } of mapFiles) {
      try {
        const file = await handle.getFile();
        const text = await file.text();
        const data = JSON.parse(text);
        ProjectContext.files.maps.set(name, { handle, data });
        const tileCount = data.tiles ? Object.keys(data.tiles).length : 0;
        console.log(`  Map "${name}" loaded — ${tileCount} tiles.`);
      } catch (err) {
        console.warn(`  Map "${name}" FAILED: ${err.message}. Skipping.`);
      }
    }

    // Parse resource files
    for (const { name, handle } of resourceFiles) {
      try {
        const file = await handle.getFile();
        const text = await file.text();
        const raw = TresParser.parse(text);
        if (raw.scriptClass !== 'ResourceDef') {
          console.warn(`  Resource "${name}" has scriptClass "${raw.scriptClass}", expected "ResourceDef". Skipping.`);
          continue;
        }

        // Round-trip validation
        const roundTrip = TresParser.serialize(raw);
        if (roundTrip !== text) {
          console.warn(`  Resource "${name}" round-trip MISMATCH. Parser output differs from original.`);
        }

        // Build data object from resource fields
        const data = {};
        for (const [key, tv] of raw.resourceFields) {
          data[key] = tv.value;
        }
        ProjectContext.files.resources.set(name, { handle, data, raw });
        console.log(`  Resource "${name}" loaded — scriptClass: ${raw.scriptClass}`);
      } catch (err) {
        console.warn(`  Resource "${name}" FAILED: ${err.message}. Skipping.`);
      }
    }

    // Parse biome files
    for (const { name, handle } of biomeFiles) {
      try {
        const file = await handle.getFile();
        const text = await file.text();
        const raw = TresParser.parse(text);
        if (raw.scriptClass !== 'BiomeData') {
          console.warn(`  Biome "${name}" has scriptClass "${raw.scriptClass}", expected "BiomeData". Skipping.`);
          continue;
        }

        // Round-trip validation
        const roundTrip = TresParser.serialize(raw);
        if (roundTrip !== text) {
          console.warn(`  Biome "${name}" round-trip MISMATCH. Parser output differs from original.`);
        }

        // Build data object from resource fields
        const data = {};
        for (const [key, tv] of raw.resourceFields) {
          data[key] = tv.value;
        }
        ProjectContext.files.biomes.set(name, { handle, data, raw });
        console.log(`  Biome "${name}" loaded — scriptClass: ${raw.scriptClass}`);
      } catch (err) {
        console.warn(`  Biome "${name}" FAILED: ${err.message}. Skipping.`);
      }
    }

    console.log(`Summary — maps: ${ProjectContext.files.maps.size}, resources: ${ProjectContext.files.resources.size}, biomes: ${ProjectContext.files.biomes.size}`);
    console.groupEnd();
    return { success: true };
  }

  /**
   * Fallback: process FileList from <input webkitdirectory>.
   * @param {FileList} fileList
   * @returns {Promise<{success: boolean, error?: string}>}
   */
  static async discoverFromFileList(fileList) {
    // Validate: check for project.godot at root level
    let hasProjectGodot = false;
    /** @type {string} */
    let rootPrefix = '';

    for (const file of fileList) {
      const parts = file.webkitRelativePath.split('/');
      if (parts.length === 2 && parts[1] === 'project.godot') {
        hasProjectGodot = true;
        rootPrefix = parts[0] + '/';
        break;
      }
    }

    if (!hasProjectGodot) {
      return { success: false, error: 'Not a Godot project. Please select the folder containing project.godot.' };
    }

    /**
     * Read a File as text.
     * @param {File} file
     * @returns {Promise<string>}
     */
    function readFileText(file) {
      return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => resolve(/** @type {string} */ (reader.result));
        reader.onerror = () => reject(reader.error);
        reader.readAsText(file);
      });
    }

    // Categorize files
    for (const file of fileList) {
      const relPath = file.webkitRelativePath.substring(rootPrefix.length);

      try {
        if (relPath.startsWith('data/maps/') && relPath.endsWith('.json')) {
          const name = relPath.split('/').pop();
          const text = await readFileText(file);
          const data = JSON.parse(text);
          ProjectContext.files.maps.set(name, { handle: null, data });
        } else if (relPath.startsWith('data/resources/') && relPath.endsWith('.tres')) {
          const name = relPath.split('/').pop();
          const text = await readFileText(file);
          const raw = TresParser.parse(text);
          if (raw.scriptClass !== 'ResourceDef') {
            console.warn(`FileDiscovery: "${name}" has scriptClass "${raw.scriptClass}", expected "ResourceDef". Skipping.`);
            continue;
          }
          const roundTrip = TresParser.serialize(raw);
          if (roundTrip !== text) {
            console.warn(`FileDiscovery: Round-trip mismatch for "${name}".`);
          }
          const data = {};
          for (const [key, tv] of raw.resourceFields) {
            data[key] = tv.value;
          }
          ProjectContext.files.resources.set(name, { handle: null, data, raw });
        } else if (relPath.startsWith('data/biomes/') && relPath.endsWith('.tres')) {
          const name = relPath.split('/').pop();
          const text = await readFileText(file);
          const raw = TresParser.parse(text);
          if (raw.scriptClass !== 'BiomeData') {
            console.warn(`FileDiscovery: "${name}" has scriptClass "${raw.scriptClass}", expected "BiomeData". Skipping.`);
            continue;
          }
          const roundTrip = TresParser.serialize(raw);
          if (roundTrip !== text) {
            console.warn(`FileDiscovery: Round-trip mismatch for "${name}".`);
          }
          const data = {};
          for (const [key, tv] of raw.resourceFields) {
            data[key] = tv.value;
          }
          ProjectContext.files.biomes.set(name, { handle: null, data, raw });
        }
      } catch (err) {
        const name = file.webkitRelativePath.split('/').pop();
        console.warn(`FileDiscovery: Failed to parse "${name}": ${err.message}. Skipping.`);
      }
    }

    return { success: true };
  }

  /**
   * Save a file via the dev server API.
   * @param {string} dir - Directory prefix e.g. 'data/maps'
   * @param {string} content - Serialized JSON or .tres
   * @param {string} filename - File name e.g. 'ch1.json'
   * @returns {Promise<void>}
   */
  static async saveFile(dir, content, filename) {
    const resp = await fetch(`/api/file?path=${encodeURIComponent(dir + '/' + filename)}`, {
      method: 'POST',
      headers: { 'Content-Type': 'text/plain' },
      body: content,
    });
    if (!resp.ok) {
      const err = await resp.json().catch(() => ({ error: resp.statusText }));
      throw new Error(err.error || `Save failed: ${resp.status}`);
    }
  }

  /**
   * Auto-discover and load project files via the dev server API.
   * @returns {Promise<{success: boolean, error?: string}>}
   */
  static async discoverViaApi() {
    console.group('FileDiscovery.discoverViaApi');

    // Discover available files
    let manifest;
    try {
      const resp = await fetch('/api/discover');
      if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
      manifest = await resp.json();
    } catch (err) {
      console.error(`Discovery API failed: ${err.message}`);
      console.groupEnd();
      return { success: false, error: `Server API unavailable: ${err.message}` };
    }

    console.log(`Manifest — maps: ${manifest.maps.files.length}, resources: ${manifest.resources.files.length}, biomes: ${manifest.biomes.files.length}`);

    // Load map files
    for (const name of manifest.maps.files) {
      try {
        const resp = await fetch(`/api/file?path=${encodeURIComponent(manifest.maps.dir + '/' + name)}`);
        const text = await resp.text();
        const data = JSON.parse(text);
        ProjectContext.files.maps.set(name, { handle: null, dir: manifest.maps.dir, data });
        const tileCount = data.tiles ? Object.keys(data.tiles).length : 0;
        console.log(`  Map "${name}" loaded — ${tileCount} tiles.`);
      } catch (err) {
        console.warn(`  Map "${name}" FAILED: ${err.message}. Skipping.`);
      }
    }

    // Load resource files
    for (const name of manifest.resources.files) {
      try {
        const resp = await fetch(`/api/file?path=${encodeURIComponent(manifest.resources.dir + '/' + name)}`);
        const text = await resp.text();
        const raw = TresParser.parse(text);
        if (raw.scriptClass !== 'ResourceDef') {
          console.warn(`  Resource "${name}" has scriptClass "${raw.scriptClass}", expected "ResourceDef". Skipping.`);
          continue;
        }
        const roundTrip = TresParser.serialize(raw);
        if (roundTrip !== text) {
          console.warn(`  Resource "${name}" round-trip MISMATCH.`);
        }
        const data = {};
        for (const [key, tv] of raw.resourceFields) {
          data[key] = tv.value;
        }
        ProjectContext.files.resources.set(name, { handle: null, dir: manifest.resources.dir, data, raw });
        console.log(`  Resource "${name}" loaded — scriptClass: ${raw.scriptClass}`);
      } catch (err) {
        console.warn(`  Resource "${name}" FAILED: ${err.message}. Skipping.`);
      }
    }

    // Load biome files
    for (const name of manifest.biomes.files) {
      try {
        const resp = await fetch(`/api/file?path=${encodeURIComponent(manifest.biomes.dir + '/' + name)}`);
        const text = await resp.text();
        const raw = TresParser.parse(text);
        if (raw.scriptClass !== 'BiomeData') {
          console.warn(`  Biome "${name}" has scriptClass "${raw.scriptClass}", expected "BiomeData". Skipping.`);
          continue;
        }
        const roundTrip = TresParser.serialize(raw);
        if (roundTrip !== text) {
          console.warn(`  Biome "${name}" round-trip MISMATCH.`);
        }
        const data = {};
        for (const [key, tv] of raw.resourceFields) {
          data[key] = tv.value;
        }
        ProjectContext.files.biomes.set(name, { handle: null, dir: manifest.biomes.dir, data, raw });
        console.log(`  Biome "${name}" loaded — scriptClass: ${raw.scriptClass}`);
      } catch (err) {
        console.warn(`  Biome "${name}" FAILED: ${err.message}. Skipping.`);
      }
    }

    console.log(`Summary — maps: ${ProjectContext.files.maps.size}, resources: ${ProjectContext.files.resources.size}, biomes: ${ProjectContext.files.biomes.size}`);
    console.groupEnd();
    return { success: true };
  }
}
