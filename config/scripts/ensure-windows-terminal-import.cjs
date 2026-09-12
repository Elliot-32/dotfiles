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

function parseSettings(text, settingsPath) {
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

  return settings;
}

function removeImport(text, settingsPath, importPath) {
  let updated = text;

  while (true) {
    const settings = parseSettings(updated, settingsPath);
    const imports = settings.import;
    if (!Array.isArray(imports)) {
      return updated;
    }

    const index = imports.indexOf(importPath);
    if (index === -1) {
      return updated;
    }

    const edits = modify(updated, ['import', index], undefined, {
      formattingOptions: detectFormatting(updated),
    });
    updated = applyEdits(updated, edits);
  }
}

const settingsPath = process.argv[2];
const importPath = process.argv[3] ?? 'tinty.json';
const legacyImportPaths = process.argv.slice(4).filter((entry) => entry !== importPath);

if (!settingsPath) {
  fail('usage: ensure-windows-terminal-import.cjs <settings.json> [import-path] [legacy-import ...]');
}

let text;
try {
  text = fs.readFileSync(settingsPath, 'utf8');
} catch (error) {
  fail(`failed to read ${settingsPath}: ${error.message}`);
}

const originalText = text;
for (const legacyImportPath of legacyImportPaths) {
  text = removeImport(text, settingsPath, legacyImportPath);
}

const settings = parseSettings(text, settingsPath);
const imports = settings.import;
if (!Array.isArray(imports) || !imports.includes(importPath)) {
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

  text = applyEdits(text, edits);
}

if (text === originalText) {
  console.log(`Windows Terminal already imports ${importPath}: ${settingsPath}`);
  process.exit(0);
}

try {
  fs.writeFileSync(settingsPath, text, 'utf8');
} catch (error) {
  fail(`failed to write ${settingsPath}: ${error.message}`);
}

console.log(`Updated Windows Terminal import to ${importPath}: ${settingsPath}`);
