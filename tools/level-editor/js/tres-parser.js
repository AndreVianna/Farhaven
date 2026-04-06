// ============================================================
// TresParser — Parse and Serialize .tres files (task-003)
// ============================================================

/**
 * @typedef {Object} TresValue
 * @property {string} type - 'string'|'stringname'|'int'|'float'|'bool'|'color'|'vector2i'|'ext_resource'|'dict'|'array'|'packed_string_array'
 * @property {*} value
 * @property {string} [elementType] - For typed arrays
 * @property {string} [keyStyle] - For dicts: 'stringname' or 'string'
 */

/**
 * Intermediate representation preserving the full .tres file structure.
 */
export class TresFile {
  constructor() {
    /** @type {string} */
    this.headerLine = '';
    /** @type {string[]} */
    this.extResources = [];
    /** @type {Map<string, TresValue>} Ordered map of [resource] key-value pairs */
    this.resourceFields = new Map();
    /** @type {string|null} */
    this.uid = null;
    /** @type {string} */
    this.scriptClass = '';
    /** @type {string} Line ending style detected from source: '\r\n' or '\n' */
    this.lineEnding = '\n';
  }
}

/**
 * Parses and serializes Godot .tres resource files.
 * Round-trip safe: serialize(parse(text)) === text for well-formed files.
 */
export class TresParser {
  /**
   * Parse a .tres file string into a TresFile object.
   * @param {string} text
   * @returns {TresFile}
   */
  static parse(text) {
    const file = new TresFile();

    // Detect and preserve line ending style
    if (text.indexOf('\r\n') !== -1) {
      file.lineEnding = '\r\n';
    } else {
      file.lineEnding = '\n';
    }

    // Normalize to \n for parsing
    const normalized = text.replace(/\r\n/g, '\n');
    const lines = normalized.split('\n');

    /** @type {'header'|'between_header_ext'|'ext_resources'|'between_ext_resource'|'resource'} */
    let section = 'header';

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];

      // Header line
      if (section === 'header') {
        if (line.startsWith('[gd_resource')) {
          file.headerLine = line;

          // Extract uid from header
          const uidMatch = line.match(/uid="([^"]+)"/);
          if (uidMatch) {
            file.uid = uidMatch[1];
          }

          // Extract script_class from header
          const scMatch = line.match(/script_class="([^"]+)"/);
          if (scMatch) {
            file.scriptClass = scMatch[1];
          }

          section = 'between_header_ext';
          continue;
        }
        // Skip any leading empty lines
        if (line.trim() === '') continue;
        throw new Error(`TresParser: Expected [gd_resource ...] header at line ${i + 1}, got: "${line}"`);
      }

      // Between header and ext_resource / [resource] section
      if (section === 'between_header_ext') {
        if (line.trim() === '') {
          continue;
        }
        if (line.startsWith('[ext_resource')) {
          file.extResources.push(line);
          section = 'ext_resources';
          continue;
        }
        if (line === '[resource]') {
          section = 'resource';
          continue;
        }
        continue;
      }

      // Collecting ext_resource lines
      if (section === 'ext_resources') {
        if (line.startsWith('[ext_resource')) {
          file.extResources.push(line);
          continue;
        }
        if (line.trim() === '') {
          section = 'between_ext_resource';
          continue;
        }
        if (line === '[resource]') {
          section = 'resource';
          continue;
        }
        continue;
      }

      // Between ext_resources and [resource]
      if (section === 'between_ext_resource') {
        if (line.trim() === '') continue;
        if (line === '[resource]') {
          section = 'resource';
          continue;
        }
        continue;
      }

      // [resource] section — parse key = value pairs
      if (section === 'resource') {
        if (line.trim() === '') continue;
        const eqIndex = line.indexOf(' = ');
        if (eqIndex === -1) continue;
        const key = line.substring(0, eqIndex);
        const valueStr = line.substring(eqIndex + 3);
        file.resourceFields.set(key, TresParser.parseValue(valueStr));
      }
    }

    return file;
  }

  /**
   * Parse a single .tres value string into a TresValue.
   * @param {string} valueStr
   * @returns {TresValue}
   */
  static parseValue(valueStr) {
    const s = valueStr.trim();

    // StringName: &"..."
    if (s.startsWith('&"')) {
      const inner = s.slice(2, -1);
      return { type: 'stringname', value: inner };
    }

    // ExtResource: ExtResource("...")
    if (s.startsWith('ExtResource(')) {
      return { type: 'ext_resource', value: s };
    }

    // Color: Color(r, g, b, a)
    if (s.startsWith('Color(')) {
      const inner = s.slice(6, -1);
      const rawParts = inner.split(',').map(p => p.trim());
      return {
        type: 'color',
        value: {
          r: parseFloat(rawParts[0]),
          g: parseFloat(rawParts[1]),
          b: parseFloat(rawParts[2]),
          a: parseFloat(rawParts[3]),
        },
        raw: rawParts,
      };
    }

    // Vector2i: Vector2i(x, y)
    if (s.startsWith('Vector2i(')) {
      const inner = s.slice(9, -1);
      const parts = inner.split(',').map(p => parseInt(p.trim(), 10));
      return { type: 'vector2i', value: { x: parts[0], y: parts[1] } };
    }

    // PackedStringArray: PackedStringArray("a", "b")
    if (s.startsWith('PackedStringArray(')) {
      const inner = s.slice(18, -1);
      if (inner.trim() === '') return { type: 'packed_string_array', value: [] };
      const values = [];
      const re = /"([^"]*)"/g;
      let m;
      while ((m = re.exec(inner)) !== null) {
        values.push(m[1]);
      }
      return { type: 'packed_string_array', value: values };
    }

    // PackedColorArray: PackedColorArray(...) -> typed array with Color
    if (s.startsWith('PackedColorArray(')) {
      const inner = s.slice(17, -1);
      const colors = TresParser._parseColorList(inner);
      return { type: 'array', value: colors, elementType: 'Color' };
    }

    // Typed array: Array[Type](...)
    if (s.startsWith('Array[')) {
      const bracketEnd = s.indexOf(']');
      const elementType = s.substring(6, bracketEnd);
      const parenStart = s.indexOf('(', bracketEnd);
      const inner = s.slice(parenStart + 1, -1);
      const elements = TresParser._parseArrayElements(inner, elementType);
      return { type: 'array', value: elements, elementType: elementType };
    }

    // Bool
    if (s === 'true') return { type: 'bool', value: true };
    if (s === 'false') return { type: 'bool', value: false };

    // String: "..."
    if (s.startsWith('"') && s.endsWith('"')) {
      return { type: 'string', value: s.slice(1, -1) };
    }

    // Dict: { ... }
    if (s.startsWith('{')) {
      return TresParser._parseDict(s);
    }

    // Untyped array: [ ... ]
    if (s.startsWith('[')) {
      const inner = s.slice(1, -1).trim();
      if (inner === '') return { type: 'array', value: [], elementType: null };
      const elements = TresParser._parseArrayElements(inner, null);
      return { type: 'array', value: elements, elementType: null };
    }

    // Number: float vs int
    if (/^-?\d+\.\d*$/.test(s) || /^-?\d*\.\d+$/.test(s)) {
      return { type: 'float', value: parseFloat(s) };
    }
    if (/^-?\d+$/.test(s)) {
      return { type: 'int', value: parseInt(s, 10) };
    }

    // Fallback: treat as string
    return { type: 'string', value: s };
  }

  /**
   * Parse a dictionary value string.
   * @param {string} s - The full dict string including braces
   * @returns {TresValue}
   */
  static _parseDict(s) {
    const inner = s.slice(1, -1).trim();
    if (inner === '') {
      // Detect brace style: '{}' vs '{ }' — check for space after opening brace
      const hasSpaces = s.length > 2 && s[1] === ' ';
      return { type: 'dict', value: new Map(), keyStyle: 'stringname', braceSpaces: hasSpaces };
    }

    // Detect key style from the first key
    const keyStyle = inner.startsWith('&"') ? 'stringname' : 'string';

    // Detect brace spacing from original string
    // "{ &..." or "{ \"..." = spaces; "{&..." or "{\"..." = no spaces
    const braceSpaces = s[1] === ' ';

    const entries = new Map();
    // Parse key: value pairs, handling nested structures
    let pos = 0;
    while (pos < inner.length) {
      // Skip whitespace
      while (pos < inner.length && (inner[pos] === ' ' || inner[pos] === '\t')) pos++;
      if (pos >= inner.length) break;

      // Parse key
      let key;
      if (inner[pos] === '&' && inner[pos + 1] === '"') {
        // StringName key: &"key"
        pos += 2;
        const endQuote = inner.indexOf('"', pos);
        key = inner.substring(pos, endQuote);
        pos = endQuote + 1;
      } else if (inner[pos] === '"') {
        // String key: "key"
        pos += 1;
        const endQuote = inner.indexOf('"', pos);
        key = inner.substring(pos, endQuote);
        pos = endQuote + 1;
      } else {
        break;
      }

      // Skip ': ' or ':'
      while (pos < inner.length && (inner[pos] === ':' || inner[pos] === ' ')) pos++;

      // Parse value — find end considering nesting
      const valueStart = pos;
      pos = TresParser._findValueEnd(inner, pos);
      const valueStr = inner.substring(valueStart, pos).trim();
      entries.set(key, TresParser.parseValue(valueStr));

      // Skip comma and whitespace
      while (pos < inner.length && (inner[pos] === ',' || inner[pos] === ' ')) pos++;
    }

    return { type: 'dict', value: entries, keyStyle: keyStyle, braceSpaces: braceSpaces };
  }

  /**
   * Find the end position of a value in a comma-separated context.
   * Handles nested braces, brackets, parentheses, and quoted strings.
   * @param {string} s
   * @param {number} start
   * @returns {number}
   */
  static _findValueEnd(s, start) {
    let depth = 0;
    let inString = false;
    let i = start;
    while (i < s.length) {
      const ch = s[i];
      if (inString) {
        if (ch === '\\') { i += 2; continue; }
        if (ch === '"') inString = false;
        i++;
        continue;
      }
      if (ch === '"') { inString = true; i++; continue; }
      if (ch === '{' || ch === '[' || ch === '(') { depth++; i++; continue; }
      if (ch === '}' || ch === ']' || ch === ')') {
        if (depth === 0) return i;
        depth--;
        i++;
        continue;
      }
      if (ch === ',' && depth === 0) return i;
      i++;
    }
    return i;
  }

  /**
   * Parse comma-separated array elements.
   * @param {string} inner - Content between brackets/parens
   * @param {string|null} elementType
   * @returns {TresValue[]}
   */
  static _parseArrayElements(inner, elementType) {
    if (inner.trim() === '') return [];
    const elements = [];
    let pos = 0;
    while (pos < inner.length) {
      // Skip whitespace
      while (pos < inner.length && (inner[pos] === ' ' || inner[pos] === '\t')) pos++;
      if (pos >= inner.length) break;

      const valueStart = pos;
      pos = TresParser._findValueEnd(inner, pos);
      let valueStr = inner.substring(valueStart, pos).trim();

      // Handle the closing character being part of the match
      if (pos < inner.length && (inner[pos] === '}' || inner[pos] === ')')) {
        valueStr = inner.substring(valueStart, pos + 1).trim();
        pos++;
      }

      if (valueStr !== '') {
        elements.push(TresParser.parseValue(valueStr));
      }

      // Skip comma and whitespace
      if (pos < inner.length && inner[pos] === ',') pos++;
      while (pos < inner.length && inner[pos] === ' ') pos++;
    }
    return elements;
  }

  /**
   * Parse a comma-separated list of Color(...) values.
   * @param {string} inner
   * @returns {TresValue[]}
   */
  static _parseColorList(inner) {
    const colors = [];
    const re = /Color\([^)]+\)/g;
    let m;
    while ((m = re.exec(inner)) !== null) {
      colors.push(TresParser.parseValue(m[0]));
    }
    return colors;
  }

  /**
   * Serialize a TresFile back to a .tres string.
   * @param {TresFile} tresFile
   * @returns {string}
   */
  static serialize(tresFile) {
    const eol = tresFile.lineEnding || '\n';
    const parts = [];

    // Header line
    parts.push(tresFile.headerLine);

    // Blank line between header and ext_resources
    if (tresFile.extResources.length > 0) {
      parts.push('');
      for (const ext of tresFile.extResources) {
        parts.push(ext);
      }
    }

    // Blank line before [resource]
    parts.push('');
    parts.push('[resource]');

    // Resource fields
    for (const [key, value] of tresFile.resourceFields) {
      parts.push(key + ' = ' + TresParser.serializeValue(value));
    }

    return parts.join(eol) + eol;
  }

  /**
   * Serialize a TresValue back to its .tres string representation.
   * @param {TresValue} tv
   * @returns {string}
   */
  static serializeValue(tv) {
    switch (tv.type) {
      case 'stringname':
        return '&"' + tv.value + '"';
      case 'string':
        return '"' + tv.value + '"';
      case 'int':
        return String(tv.value);
      case 'float':
        return TresParser._serializeFloat(tv.value);
      case 'bool':
        return tv.value ? 'true' : 'false';
      case 'color':
        if (tv.raw) {
          return 'Color(' + tv.raw.join(', ') + ')';
        }
        return 'Color(' + TresParser._serializeFloat(tv.value.r)
          + ', ' + TresParser._serializeFloat(tv.value.g)
          + ', ' + TresParser._serializeFloat(tv.value.b)
          + ', ' + TresParser._serializeFloat(tv.value.a) + ')';
      case 'vector2i':
        return 'Vector2i(' + tv.value.x + ', ' + tv.value.y + ')';
      case 'ext_resource':
        return tv.value;
      case 'dict':
        return TresParser._serializeDict(tv);
      case 'array':
        return TresParser._serializeArray(tv);
      case 'packed_string_array':
        if (tv.value.length === 0) return 'PackedStringArray()';
        return 'PackedStringArray(' + tv.value.map(v => '"' + v + '"').join(', ') + ')';
      default:
        return String(tv.value);
    }
  }

  /**
   * Serialize a float value, ensuring it always has a decimal point.
   * @param {number} val
   * @returns {string}
   */
  static _serializeFloat(val) {
    const s = String(val);
    if (s.indexOf('.') === -1 && s.indexOf('e') === -1) {
      return s + '.0';
    }
    return s;
  }

  /**
   * Serialize a dict TresValue.
   * @param {TresValue} tv
   * @returns {string}
   */
  static _serializeDict(tv) {
    const map = tv.value;
    if (map.size === 0) return '{}';

    const keyStyle = tv.keyStyle || 'stringname';
    const pairs = [];
    for (const [key, val] of map) {
      const serializedKey = keyStyle === 'stringname'
        ? '&"' + key + '"'
        : '"' + key + '"';
      pairs.push(serializedKey + ': ' + TresParser.serializeValue(val));
    }

    // Use stored brace spacing style, defaulting to spaces
    const useSpaces = tv.braceSpaces !== undefined ? tv.braceSpaces : true;
    if (useSpaces) {
      return '{ ' + pairs.join(', ') + ' }';
    }
    return '{' + pairs.join(', ') + '}';
  }

  /**
   * Serialize an array TresValue.
   * @param {TresValue} tv
   * @returns {string}
   */
  static _serializeArray(tv) {
    const elements = tv.value;
    if (tv.elementType) {
      // Typed array: Array[Type](...)
      if (elements.length === 0) {
        return 'Array[' + tv.elementType + ']()';
      }
      return 'Array[' + tv.elementType + '](' + elements.map(e => TresParser.serializeValue(e)).join(', ') + ')';
    }
    // Untyped array: [...]
    if (elements.length === 0) return '[]';
    return '[' + elements.map(e => TresParser.serializeValue(e)).join(', ') + ']';
  }
}

/**
 * Generate a Godot-format uid for new .tres files.
 * @returns {string}
 */
export function generateTresUid() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  let id = 'uid://c';
  for (let i = 0; i < 13; i++) {
    id += chars[Math.floor(Math.random() * chars.length)];
  }
  return id;
}
