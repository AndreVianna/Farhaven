/**
 * Minimal DOM mocks for running ES module tests in Node.js.
 * Must be imported BEFORE any modules that reference document/window.
 */
globalThis.document = {
  querySelectorAll: () => [],
  getElementById: () => ({
    addEventListener: () => {},
    classList: { add: () => {}, remove: () => {} },
    textContent: '',
    style: {},
    value: '',
    click: () => {},
    checked: false,
  }),
  activeElement: null,
  addEventListener: () => {},
  createElement: (tag) => ({
    click: () => {}, href: '', download: '', style: { cssText: '' },
    appendChild: () => {}, remove: () => {},
    textContent: '', type: '', value: '',
    addEventListener: () => {},
    focus: () => {}, select: () => {},
    id: '',
  }),
  body: { appendChild: () => {}, removeChild: () => {} },
};
globalThis.window = { addEventListener: () => {}, showDirectoryPicker: undefined };
globalThis.requestAnimationFrame = (cb) => setTimeout(cb, 0);
globalThis.URL = { createObjectURL: () => '', revokeObjectURL: () => {} };
