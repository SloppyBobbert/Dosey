import { createRobotHandler } from '../functions/household-handlers.js';
import { createHouseholdRuntime } from '../runtime/household-runtime.js';

export default async function createRobot(
  context: Parameters<ReturnType<typeof createRobotHandler>>[0],
) {
  const runtime = createHouseholdRuntime(
    context.req.headers,
    process.env,
    context.error,
  );
  return createRobotHandler(runtime.createRobot, runtime.identity)(context);
}
