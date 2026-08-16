import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';

import { canonicalTemplate, validateTemplate } from '../tool/validate-appwrite-template.js';

test('checked-in template equals the full canonical descriptor', () => {
  const path = new URL('../appwrite.pairing-household.template.json', import.meta.url);
  const template = JSON.parse(readFileSync(path, 'utf8')) as {
    tables: Array<{ $id: string; $permissions: string[] }>;
  };

  assert.deepEqual(template, canonicalTemplate);
  assert.equal(validateTemplate(template), true);
});

test('template validation rejects representative exact mutations', () => {
  const cases = [
    (value: any) => { value.tables.reverse(); },
    (value: any) => { value.tables[0].$id = 'renamed'; },
    (value: any) => { value.tables.pop(); },
    (value: any) => { value.tables.push(structuredClone(value.tables[0])); },
    (value: any) => { value.tables[0].name = 'changed'; },
    (value: any) => { value.tables[0].enabled = false; },
    (value: any) => { value.tables[0].columns[0].key = ''; },
    (value: any) => { value.tables[0].columns.reverse(); },
    (value: any) => { value.tables[0].columns.pop(); },
    (value: any) => { value.tables[0].columns.push(structuredClone(value.tables[0].columns[0])); },
    (value: any) => { value.tables[0].columns[0].type = 'integer'; },
    (value: any) => { value.tables[0].columns[0].size = 0; },
    (value: any) => { value.tables[0].columns[5].min = 9; value.tables[0].columns[5].max = 1; },
    (value: any) => { value.tables[0].columns[0].required = false; },
    (value: any) => { value.tables[0].columns[0].array = true; },
    (value: any) => { value.tables[0].columns[0].default = 'changed'; },
    (value: any) => { value.tables[0].indexes.push({ ...value.tables[0].indexes[0] }); },
    (value: any) => { value.tables[0].indexes.reverse(); },
    (value: any) => { value.tables[0].indexes[0].key = 'renamed'; },
    (value: any) => { value.tables[0].indexes[0].type = 'unique'; },
    (value: any) => { value.tables[0].indexes[0].columns = ['missing']; },
  ];
  for (const mutate of cases) { const template = loadTemplate(); mutate(template); assert.equal(validateTemplate(template), false); }
  for (const value of [null, [], 'secret_eyJhbGciOiJIUzI1NiJ9.email@example.test.payload', '{']) assert.equal(validateTemplate(value), false);
});

test('CLI returns fixed output and status for every template outcome', () => {
  const directory = mkdtempSync(join(tmpdir(), 'dosey-template-'));
  const invalid = join(directory, 'invalid.json');
  const malformed = join(directory, 'malformed.json');
  const missing = join(directory, 'missing.json');
  const valid = new URL('../appwrite.pairing-household.template.json', import.meta.url).pathname;
  try {
    writeFileSync(invalid, '{"secret":"key_live_token@example.test.jwt.payload"}');
    writeFileSync(malformed, '{"secret":');
    const cases = [
      { path: valid, status: 0, output: 'APPWRITE_TEMPLATE_VALIDATION status=pass\n' },
      { path: invalid, status: 1, output: 'APPWRITE_TEMPLATE_VALIDATION status=fail reason=TEMPLATE_INVALID\n' },
      { path: malformed, status: 1, output: 'APPWRITE_TEMPLATE_VALIDATION status=fail reason=TEMPLATE_INVALID\n' },
      { path: missing, status: 1, output: 'APPWRITE_TEMPLATE_VALIDATION status=fail reason=TEMPLATE_INVALID\n' },
    ];
    for (const scenario of cases) {
      const result = spawnSync('./node_modules/.bin/tsx', ['tool/validate-appwrite-template.ts', scenario.path], { cwd: new URL('..', import.meta.url), encoding: 'utf8' });
      assert.equal(result.status, scenario.status);
      assert.equal(result.stdout, scenario.output);
      assert.equal(result.stderr, '');
    }
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

function loadTemplate(): any {
  return JSON.parse(readFileSync(new URL('../appwrite.pairing-household.template.json', import.meta.url), 'utf8'));
}
