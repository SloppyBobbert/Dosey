import { medicationSyncContractParser } from '../functions/medication-sync-contract-adapter.js';
import { medicationSyncPullHandler } from '../functions/medication-sync-handlers.js';
import { createMedicationSyncRuntime } from '../runtime/medication-sync-runtime.js';

export default async function medicationSyncPull(
  context: Parameters<ReturnType<typeof medicationSyncPullHandler>>[0],
) {
  const runtime = createMedicationSyncRuntime(
    context.req.headers,
    medicationSyncContractParser,
    process.env,
    context.error,
  );
  return medicationSyncPullHandler(runtime.pull, runtime.identity, runtime.parser)(context);
}
