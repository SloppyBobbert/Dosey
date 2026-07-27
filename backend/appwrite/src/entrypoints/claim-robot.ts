import { createClaimRobotHandler } from '../functions/claim-robot.js';
import { createPairingRuntime } from '../runtime/pairing-runtime.js';

export default async function claimRobot(context: Parameters<ReturnType<typeof createClaimRobotHandler>>[0]) {
  const runtime = createPairingRuntime(
    context.req.headers,
    process.env,
    context.error,
  );
  return createClaimRobotHandler(runtime.claimRobot, runtime.identity)(context);
}
