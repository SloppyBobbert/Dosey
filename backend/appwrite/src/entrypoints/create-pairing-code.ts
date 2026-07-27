import { createPairingCodeHandler } from '../functions/create-pairing-code.js';
import { createPairingRuntime } from '../runtime/pairing-runtime.js';

export default async function createPairingCode(
  context: Parameters<ReturnType<typeof createPairingCodeHandler>>[0],
) {
  const runtime = createPairingRuntime(
    context.req.headers,
    process.env,
    context.error,
  );
  return createPairingCodeHandler(runtime.createPairingCode, runtime.identity)(
    context,
  );
}
