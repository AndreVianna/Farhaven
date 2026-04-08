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
    /** @type {Map<string, {handle: FileSystemFileHandle|null, data: Object, raw: import('./tres-parser.js').TresFile}>}
     * Holds prop definitions (ResourceDef .tres files). */
    props: new Map(),
    /** @type {Map<string, {handle: FileSystemFileHandle|null, data: Object, raw: import('./tres-parser.js').TresFile}>} */
    biomes: new Map(),
  },
};

// ============================================================
// FileDiscovery (task-002)
// ============================================================

/**
 * Parse a single .tres file, validating scriptClass and round-trip integrity.
 * @param {string} name - Filename for logging
 * @param {string} text - Raw .tres file content
 * @param {string} expectedClass - Expected scriptClass value
 * @returns {{ data: Object, raw: import('./tres-parser.js').TresFile } | null}
 */
function _parseTresFile(name, text, expectedClass) {
  const raw = TresParser.parse(text);
  if (raw.scriptClass !== expectedClass) {
    console.warn(`FileDiscovery: "${name}" has scriptClass "${raw.scriptClass}", expected "${expectedClass}". Skipping.`);
    return null;
  }
  const roundTrip = TresParser.serialize(raw);
  if (roundTrip !== text) {
    console.warn(`FileDiscovery: "${name}" round-trip MISMATCH.`);
  }
  const data = {};
  for (const [key, tv] of raw.resourceFields) {
    data[key] = tv.value;
  }
  return { data, raw };
}

/**
 * Load .tres files from FSA handles into a storage map using _parseTresFile.
 * Used by discoverProject to avoid duplicating the prop/biome parse loop.
 * @param {Array<{name: string, handle: FileSystemFileHandle}>} files
 * @param {string} expectedClass - Expected scriptClass for _parseTresFile
 * @param {Map<string, Object>} storageMap - Target map in ProjectContext.files
 * @param {string} labelPrefix - Label for console logging (e.g. "Resource", "Biome")
 * @returns {Promise<void>}
 */
async function _loadTresFilesFromHandles(files, expectedClass, storageMap, labelPrefix) {
  for (const { name, handle } of files) {
    try {
      const file = await handle.getFile();
      const text = await file.text();
      const result = _parseTresFile(name, text, expectedClass);
      if (!result) continue;
      storageMap.set(name, { handle, data: result.data, raw: result.raw });
      console.log(`  ${labelPrefix} "${name}" loaded — scriptClass: ${result.raw.scriptClass}`);
    } catch (err) {
      console.warn(`  ${labelPrefix} "${name}" FAILED: ${err.message}. Skipping.`);
    }
  }
}

/**
 * Load .tres files via fetch into a storage map using _parseTresFile.
 * Used by discoverViaApi to avoid duplicating the prop/biome parse loop.
 * @param {string[]} fileNames
 * @param {string} dir - Directory path for API URL
 * @param {string} expectedClass
 * @param {Map<string, Object>} storageMap
 * @param {string} labelPrefix
 * @returns {Promise<void>}
 */
async function _loadTresFilesViaApi(fileNames, dir, expectedClass, storageMap, labelPrefix) {
  for (const name of fileNames) {
    try {
      const resp = await fetch(`/api/file?path=${encodeURIComponent(dir + '/' + name)}`);
      const text = await resp.text();
      const result = _parseTresFile(name, text, expectedClass);
      if (!result) continue;
      storageMap.set(name, { handle: null, dir, data: result.data, raw: result.raw });
      console.log(`  ${labelPrefix} "${name}" loaded — scriptClass: ${result.raw.scriptClass}`);
    } catch (err) {
      console.warn(`  ${labelPrefix} "${name}" FAILED: ${err.message}. Skipping.`);
    }
  }
}

// Note on D3 duplication: The three discovery methods (discoverProject, discoverFromFileList,
// discoverViaApi) each use fundamentally different file-access strategies (FSA handles, FileList
// with FileReader, and fetch API). The .tres parse-and-store loops for props/biomes have been
// extracted into _loadTresFilesFromHandles and _loadTresFilesViaApi. The FileList method inlines
// its logic because it intermixes path-based file categorization with parsing, making extraction
// impractical without over-engineering.

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
    const propFiles = await FileDiscovery.scanDirectory(rootHandle, 'data/props', '.tres');
    const biomeFiles = await FileDiscovery.scanDirectory(rootHandle, 'data/biomes', '.tres');
    console.log(`Scan results — maps: ${mapFiles.length}, props: ${propFiles.length}, biomes: ${biomeFiles.length}`);

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

    // Parse prop and biome .tres files
    await _loadTresFilesFromHandles(propFiles, 'ResourceDef', ProjectContext.files.props, 'Prop');
    await _loadTresFilesFromHandles(biomeFiles, 'BiomeData', ProjectContext.files.biomes, 'Biome');

    console.log(`Summary — maps: ${ProjectContext.files.maps.size}, props: ${ProjectContext.files.props.size}, biomes: ${ProjectContext.files.biomes.size}`);
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
        } else if (relPath.startsWith('data/props/') && relPath.endsWith('.tres')) {
          const name = relPath.split('/').pop();
          const text = await readFileText(file);
          const result = _parseTresFile(name, text, 'ResourceDef');
          if (!result) continue;
          ProjectContext.files.props.set(name, { handle: null, data: result.data, raw: result.raw });
        } else if (relPath.startsWith('data/biomes/') && relPath.endsWith('.tres')) {
          const name = relPath.split('/').pop();
          const text = await readFileText(file);
          const result = _parseTresFile(name, text, 'BiomeData');
          if (!result) continue;
          ProjectContext.files.biomes.set(name, { handle: null, data: result.data, raw: result.raw });
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
    try {
      const resp = await fetch(`/api/file?path=${encodeURIComponent(dir + '/' + filename)}`, {
        method: 'POST',
        headers: { 'Content-Type': 'text/plain' },
        body: content,
      });
      if (!resp.ok) {
        const err = await resp.json().catch(() => ({ error: resp.statusText }));
        throw new Error(err.error || `Save failed: ${resp.status}`);
      }
    } catch (err) {
      // Fallback: download via Blob when server is unavailable (e.g. network error)
      if (err.message.includes('fetch') || err.name === 'TypeError') {
        const blob = new Blob([content], { type: 'application/octet-stream' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
      } else {
        throw err;
      }
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

    console.log(`Manifest — maps: ${manifest.maps.files.length}, props: ${manifest.props.files.length}, biomes: ${manifest.biomes.files.length}`);

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

    // Load prop and biome .tres files
    await _loadTresFilesViaApi(manifest.props.files, manifest.props.dir, 'ResourceDef', ProjectContext.files.props, 'Prop');
    await _loadTresFilesViaApi(manifest.biomes.files, manifest.biomes.dir, 'BiomeData', ProjectContext.files.biomes, 'Biome');

    console.log(`Summary — maps: ${ProjectContext.files.maps.size}, props: ${ProjectContext.files.props.size}, biomes: ${ProjectContext.files.biomes.size}`);
    console.groupEnd();
    return { success: true };
  }
}
