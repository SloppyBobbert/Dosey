import { createClaimRobotHandler } from '../functions/claim-robot.js';
import { createPairingRuntime } from '../runtime/pairing-runtime.js';

const handler = createClaimRobotHandler(createPairingRuntime().claimRobot);

export default handler;
