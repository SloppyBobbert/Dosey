import { createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';

const [sourcePath, outputPath, typescriptPath, dartPath] = process.argv.slice(2);

if (sourcePath === undefined || outputPath === undefined) {
  throw new Error(
    'Usage: node generate-timezones.mjs <tzdata.zi> <canonical-timezones.json> [typescript-contract] [dart-contract]',
  );
}

const source = await readFile(sourcePath, 'utf8');
const versionMatch = /^# version (\S+)$/m.exec(source);
if (versionMatch === null) {
  throw new Error('tzdata.zi does not declare a version.');
}

const zones = [...source.matchAll(/^Z\s+(\S+)/gm)].map((match) => match[1]);
zones.push('UTC');
zones.sort();

if (new Set(zones).size !== zones.length) {
  throw new Error('Canonical timezone source contains duplicate names.');
}

const document = {
  contractVersion: 1,
  tzdbVersion: versionMatch[1].replace(/-rearguard$/, ''),
  sourceVariant: versionMatch[1],
  source: 'IANA tzdata.zi Zone records plus the contract UTC compatibility name',
  sourceUrl: 'https://data.iana.org/time-zones/releases/',
  sourceSha256: createHash('sha256').update(source).digest('hex'),
  generationCommand:
    'node contracts/medication-sync/v1/generate-timezones.mjs <tzdata.zi> contracts/medication-sync/v1/canonical-timezones.json backend/appwrite/src/domain/medication-sync-contract.ts mobile_app/dosey_app/lib/core/sync/domain_contracts.dart',
  zones,
};

await writeFile(outputPath, `${JSON.stringify(document, null, 2)}\n`);

async function replaceGeneratedBlock(path, start, end, generated) {
  const current = await readFile(path, 'utf8');
  const startIndex = current.indexOf(start);
  const endIndex = current.indexOf(end);
  if (startIndex < 0 || endIndex < startIndex) {
    throw new Error(`${path} is missing canonical timezone generation markers.`);
  }
  const before = current.slice(0, startIndex + start.length);
  const after = current.slice(endIndex);
  await writeFile(path, `${before}\n${generated}\n${after}`);
}

if ((typescriptPath === undefined) !== (dartPath === undefined)) {
  throw new Error('TypeScript and Dart mirror paths must be supplied together.');
}

if (typescriptPath !== undefined && dartPath !== undefined) {
  const typescriptValues = zones.map((zone) => `  ${JSON.stringify(zone)},`).join('\n');
  await replaceGeneratedBlock(
    typescriptPath,
    '// BEGIN GENERATED CANONICAL TIMEZONES',
    '// END GENERATED CANONICAL TIMEZONES',
    `export const medicationSyncCanonicalTimezones: readonly string[] = Object.freeze([\n${typescriptValues}\n]);`,
  );

  const dartValues = zones.map((zone) => `  '${zone}',`).join('\n');
  await replaceGeneratedBlock(
    dartPath,
    '// BEGIN GENERATED CANONICAL TIMEZONES',
    '// END GENERATED CANONICAL TIMEZONES',
    `final Set<String> medicationSyncCanonicalTimezones = Set.unmodifiable(<String>{\n${dartValues}\n});`,
  );
}
