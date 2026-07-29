import { createGetMountedRobotHandler } from '../functions/get-mounted-robot.js';
import { createMountedRobotRuntime } from '../runtime/mounted-robot-runtime.js';

export default async function getMountedRobot(
  context: Parameters<ReturnType<typeof createGetMountedRobotHandler>>[0],
) {
  const runtime = createMountedRobotRuntime(
    context.req.headers,
    process.env,
  );
  return createGetMountedRobotHandler(runtime.service, runtime.identity)(context);
}
