import { createHash, randomUUID } from "node:crypto";
import { readFile, rename, rm, writeFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";

function replaceGeneratedBlock(current, path, start, end, generated) {
  const startIndex = current.indexOf(start);
  const endIndex = current.indexOf(end);
  if (startIndex < 0 || endIndex < startIndex) {
    throw new Error(
      `${path} is missing canonical timezone generation markers.`,
    );
  }
  const before = current.slice(0, startIndex + start.length);
  const after = current.slice(endIndex);
  return `${before}\n${generated}\n${after}`;
}

async function replaceAll(
  outputs,
  { beforeReplace, writeTemporary, removeBackup },
) {
  const token = `${process.pid}-${randomUUID()}`;
  const states = outputs.map((output, index) => ({
    ...output,
    temporaryPath: `${output.path}.tmp-${token}-${index}`,
    backupPath: `${output.path}.bak-${token}-${index}`,
    backupMoved: false,
    replacementMoved: false,
  }));

  const stagingResults = await Promise.allSettled(
    states.map((state, index) =>
      writeTemporary(state.temporaryPath, state.content, index),
    ),
  );
  const stagingErrors = stagingResults
    .filter((result) => result.status === "rejected")
    .map((result) => result.reason);
  if (stagingErrors.length > 0) {
    const cleanupResults = await Promise.allSettled(
      states.map((state) => rm(state.temporaryPath, { force: true })),
    );
    const cleanupErrors = cleanupResults
      .filter((result) => result.status === "rejected")
      .map((result) => result.reason);
    throw new AggregateError(
      [...stagingErrors, ...cleanupErrors],
      "Timezone generation staging failed.",
    );
  }

  try {
    for (const [index, state] of states.entries()) {
      await beforeReplace(index);
      await rename(state.path, state.backupPath);
      state.backupMoved = true;
      await rename(state.temporaryPath, state.path);
      state.replacementMoved = true;
    }
  } catch (error) {
    const rollbackErrors = [];
    for (const state of [...states].reverse()) {
      try {
        if (state.replacementMoved) await rm(state.path, { force: true });
      } catch (rollbackError) {
        rollbackErrors.push(rollbackError);
      }
      try {
        if (state.backupMoved) await rename(state.backupPath, state.path);
      } catch (rollbackError) {
        rollbackErrors.push(rollbackError);
      }
      await rm(state.temporaryPath, { force: true }).catch((cleanupError) => {
        rollbackErrors.push(cleanupError);
      });
    }
    if (rollbackErrors.length > 0) {
      throw new AggregateError(
        [error, ...rollbackErrors],
        "Timezone generation rollback failed.",
      );
    }
    throw error;
  }

  const cleanupResults = await Promise.allSettled(
    states.map((state, index) => removeBackup(state.backupPath, index)),
  );
  const cleanupErrors = cleanupResults
    .filter((result) => result.status === "rejected")
    .map((result) => result.reason);
  if (cleanupErrors.length > 0) {
    throw new AggregateError(
      cleanupErrors,
      "Timezone generation committed, but backup cleanup failed.",
    );
  }
}

export async function generateTimezones(
  sourcePath,
  outputPath,
  typescriptPath,
  dartPath,
  {
    beforeReplace = () => {},
    writeTemporary = (path, content) => writeFile(path, content, { flag: "wx" }),
    removeBackup = (path) => rm(path, { force: true }),
  } = {},
) {
  if (sourcePath === undefined || outputPath === undefined) {
    throw new Error(
      "Usage: node generate-timezones.mjs <tzdata.zi> <canonical-timezones.json> [typescript-contract] [dart-contract]",
    );
  }
  if ((typescriptPath === undefined) !== (dartPath === undefined)) {
    throw new Error(
      "TypeScript and Dart mirror paths must be supplied together.",
    );
  }

  const source = await readFile(sourcePath, "utf8");
  const versionMatch = /^# version (\S+)$/m.exec(source);
  if (versionMatch === null) {
    throw new Error("tzdata.zi does not declare a version.");
  }

  const zones = [...source.matchAll(/^Z\s+(\S+)/gm)].map((match) => match[1]);
  zones.push("UTC");
  zones.sort();
  if (new Set(zones).size !== zones.length) {
    throw new Error("Canonical timezone source contains duplicate names.");
  }

  const document = {
    contractVersion: 1,
    tzdbVersion: versionMatch[1].replace(/-rearguard$/, ""),
    sourceVariant: versionMatch[1],
    source:
      "IANA tzdata.zi Zone records plus the contract UTC compatibility name",
    sourceUrl: "https://data.iana.org/time-zones/releases/",
    sourceSha256: createHash("sha256").update(source).digest("hex"),
    generationCommand:
      "node contracts/medication-sync/v1/generate-timezones.mjs <tzdata.zi> contracts/medication-sync/v1/canonical-timezones.json backend/appwrite/src/domain/medication-sync-contract.ts mobile_app/dosey_app/lib/core/sync/domain_contracts.dart",
    zones,
  };

  const outputs = [
    { path: outputPath, content: `${JSON.stringify(document, null, 2)}\n` },
  ];
  if (typescriptPath !== undefined && dartPath !== undefined) {
    const [typescriptCurrent, dartCurrent] = await Promise.all([
      readFile(typescriptPath, "utf8"),
      readFile(dartPath, "utf8"),
    ]);
    const typescriptValues = zones
      .map((zone) => `  ${JSON.stringify(zone)},`)
      .join("\n");
    outputs.push({
      path: typescriptPath,
      content: replaceGeneratedBlock(
        typescriptCurrent,
        typescriptPath,
        "// BEGIN GENERATED CANONICAL TIMEZONES",
        "// END GENERATED CANONICAL TIMEZONES",
        `export const medicationSyncCanonicalTimezones: readonly string[] = Object.freeze([\n${typescriptValues}\n]);`,
      ),
    });
    const dartValues = zones.map((zone) => `  '${zone}',`).join("\n");
    outputs.push({
      path: dartPath,
      content: replaceGeneratedBlock(
        dartCurrent,
        dartPath,
        "// BEGIN GENERATED CANONICAL TIMEZONES",
        "// END GENERATED CANONICAL TIMEZONES",
        `final Set<String> medicationSyncCanonicalTimezones = Set.unmodifiable(<String>{\n${dartValues}\n});`,
      ),
    });
  }

  await replaceAll(outputs, { beforeReplace, writeTemporary, removeBackup });
}

const invokedPath = process.argv[1];
if (
  invokedPath !== undefined &&
  pathToFileURL(invokedPath).href === import.meta.url
) {
  await generateTimezones(...process.argv.slice(2));
}
