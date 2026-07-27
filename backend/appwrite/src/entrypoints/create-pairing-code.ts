import { createPairingCodeHandler } from '../functions/create-pairing-code.js';
import { createPairingRuntime } from '../runtime/pairing-runtime.js';

const handler = createPairingCodeHandler(
  createPairingRuntime().createPairingCode,
);

export default handler;
