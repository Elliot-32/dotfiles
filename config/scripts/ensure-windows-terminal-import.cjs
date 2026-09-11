#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const { applyEdits, modify, parse } = require('jsonc-parser');

function fail(message) {
  console.error(`error: ${message}`);
  process.exit(1);
}

function detectFormatting(text) {
  const eol = text.includes('\r\n') ? '\r\n' : '\n';
  const indentMatch = text.match(/(?:^|\r?\n)([ \t]+)"/);
  const indent = indentMatch?.[1] ?? '    ';

  if (indent.includes('\t')) {
    return { eol, insertSpaces: false, tabSize: 1 };
  }

  return {
    eol,
    insertSpaces: true,
    tabSize: Math.max(indent.length, 1),
  };
}

const settingsPath = process.argv[2];
const importPath = process.argv[3] ?? 'palette.json';

if (!settingsPath) {
  fail('usage: ensure-windows-terminal-import.cjs <settings.json> [import-path]');
}

let text;
try {
  text = fs.readFileSync(settingsPath, 'utf8');
} catch (error) {
  fail(`failed to read ${settingsPath}: ${error.message}`);
}

const errors = [];
const settings = parse(text, errors, {
  allowTrailingComma: true,
  disallowComments: false,
});

if (errors.length > 0) {
  const details = errors
    .map(({ error, offset, length }) => `${error}@${offset}+${length}`)
    .join(', ');
  fail(`refusing to edit invalid JSONC in ${settingsPath}: ${details}`);
}

if (settings === null || typeof settings !== 'object' || Array.isArray(settings)) {
  fail(`expected the root of ${settingsPath} to be a JSON object`);
}

const imports = settings.import;
if (imports !== undefined && !Array.isArray(imports)) {
  fail(`expected "import" in ${settingsPath} to be an array`);
}

if (Array.isArray(imports) && imports.some((entry) => typeof entry !== 'string')) {
  fail(`expected every "import" entry in ${settingsPath} to be a string`);
}

if (Array.isArray(imports) && imports.includes(importPath)) {
  console.log(`Windows Terminal already imports ${importPath}: ${settingsPath}`);
  process.exit(0);
}

const formattingOptions = detectFormatting(text);
let edits;

if (Array.isArray(imports)) {
  // Prepend rather than append so an inline comment on the previous last item
  // cannot be re-attached to the newly inserted value by jsonc-parser.
  edits = modify(text, ['import', 0], importPath, {
    formattingOptions,
    isArrayInsertion: true,
  });
} else {
  // Insert the property first for the same reason: jsonc-parser has a known
  // edge case when appending after a property with a trailing inline comment.
  edits = modify(text, ['import'], [importPath], {
    formattingOptions,
    getInsertionIndex: () => 0,
  });
}

const updated = applyEdits(text, edits);

try {
  fs.writeFileSync(settingsPath, updated, 'utf8');
} catch (error) {
  fail(`failed to write ${settingsPath}: ${error.message}`);
}

console.log(`Added Windows Terminal import ${importPath}: ${settingsPath}`);
