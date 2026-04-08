/**
 * Offline round-trip test for TresParser.
 * Tests against all .tres files in the project.
 * Run: node tools/level-editor/test-roundtrip.mjs
 */

// DOM mocks — imported first so globalThis.document/window exist before any other module evaluates
import './test-dom-mocks.mjs';

import { readFileSync, readdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { TresParser } from './js/tres-parser.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const projectRoot = join(__dirname, '..', '..');

// Test all .tres files
const dirs = [
  { path: 'data/props', expectedClass: 'PropDef' },
  { path: 'data/biomes', expectedClass: 'BiomeData' },
];

let passed = 0;
let failed = 0;

for (const { path: dirPath, expectedClass } of dirs) {
  const fullDir = join(projectRoot, dirPath);
  const files = readdirSync(fullDir).filter(f => f.endsWith('.tres'));

  for (const file of files) {
    const filePath = join(fullDir, file);
    const text = readFileSync(filePath, 'utf-8');

    try {
      const parsed = TresParser.parse(text);

      // Verify script class
      if (parsed.scriptClass !== expectedClass) {
        console.error(`FAIL ${dirPath}/${file}: scriptClass="${parsed.scriptClass}", expected="${expectedClass}"`);
        failed++;
        continue;
      }

      const serialized = TresParser.serialize(parsed);

      if (serialized === text) {
        console.log(`PASS ${dirPath}/${file}`);
        passed++;
      } else {
        console.error(`FAIL ${dirPath}/${file}: round-trip mismatch`);
        // Show diff
        const origLines = text.split('\n');
        const serLines = serialized.split('\n');
        const maxLines = Math.max(origLines.length, serLines.length);
        for (let i = 0; i < maxLines; i++) {
          if (origLines[i] !== serLines[i]) {
            console.error(`  Line ${i + 1}:`);
            console.error(`    Original:   ${JSON.stringify(origLines[i])}`);
            console.error(`    Serialized: ${JSON.stringify(serLines[i])}`);
          }
        }
        failed++;
      }
    } catch (err) {
      console.error(`FAIL ${dirPath}/${file}: ${err.message}`);
      failed++;
    }
  }
}

console.log(`\n${passed + failed} files tested: ${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);
