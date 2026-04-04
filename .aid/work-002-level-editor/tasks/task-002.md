# task-002: File Discovery and Project Context

**Type:** IMPLEMENT

**Source:** feature-007-file-discovery -> delivery-001

**Depends on:** task-001

**Scope:**
- Implement `ProjectContext` global singleton with `rootHandle`, `hasFileSystemAccess`, and `files` (maps, resources, biomes as Maps)
- Implement `FileDiscovery` class with all static methods: `getSubdirectory()`, `scanDirectory()`, `discoverProject()`, `discoverFromFileList()`, `saveFile()`
- Implement the File System Access API path: `showDirectoryPicker()`, project root validation (`project.godot` check), directory scanning for `data/maps/*.json`, `data/resources/*.tres`, `data/biomes/*.tres`
- Implement the fallback path: `<input webkitdirectory>`, `FileList` processing with `webkitRelativePath`, `FileReader.readAsText()`
- Implement `saveFile()`: write via `FileSystemFileHandle.createWritable()` when available, fallback to Blob + `<a download>`
- Wire "Open Project" button on welcome screen to trigger discovery flow
- Transition from welcome overlay to editor workspace on successful discovery
- All error handling per SPEC: cancel = stay on welcome, missing project.godot = error banner, missing directories = log warning + continue, file parse errors = log warning + skip

**Acceptance Criteria:**
- [ ] Selecting a valid Farhaven project root discovers all .json and .tres files in the expected directories
- [ ] `ProjectContext.files.maps`, `.resources`, `.biomes` are populated with `{ handle, data, raw }` entries
- [ ] Cancelling the folder picker stays on welcome state without error
- [ ] Selecting a folder without `project.godot` shows an error message and returns to welcome
- [ ] Missing `data/maps/`, `data/resources/`, or `data/biomes/` directories log warnings but do not crash
- [ ] Individual file parse errors are logged and the file is skipped; other files still load
- [ ] `saveFile()` writes directly in Chrome/Edge; offers download in fallback browsers
- [ ] All existing tests still pass (N/A for new file -- no regressions in game code)
