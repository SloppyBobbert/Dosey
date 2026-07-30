import { medicationSyncContractParser } from '../functions/medication-sync-contract-adapter.js';
import { medicationSyncPushHandler } from '../functions/medication-sync-handlers.js';
import { createMedicationSyncRuntime } from '../runtime/medication-sync-runtime.js';

export default async function medicationSyncPush(
  context: Parameters<ReturnType<typeof medicationSyncPushHandler>>[0],
) {
  const runtime = createMedicationSyncRuntime(
    context.req.headers,
    medicationSyncContractParser,
    process.env,
    context.error,
  );
  return medicationSyncPushHandler(runtime.push, runtime.identity, runtime.parser)(context);
}
