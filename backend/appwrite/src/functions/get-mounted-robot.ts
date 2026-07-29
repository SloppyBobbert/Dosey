import type { GetMountedRobotService } from '../application/mounted-robot-services.js';
import type { AnonymousFunctionIdentityVerifier } from './function-identity.js';
import type { FunctionContext } from './claim-robot.js';

export function createGetMountedRobotHandler(
  service: Pick<GetMountedRobotService, 'get'>,
  identity: AnonymousFunctionIdentityVerifier,
) {
  return async (context: FunctionContext) => {
    if (context.req.method !== 'POST') {
      return context.res.json({ error: 'method_not_allowed' }, 405);
    }
    const identityResult = await identity.verifyAnonymous(context.req.headers);
    if (identityResult != null && typeof identityResult !== 'string') {
      return context.res.json({ error: 'anonymous_account_required' }, 403);
    }
    if (identityResult == null) {
      return context.res.json({ error: 'authentication_required' }, 401);
    }
    if (!isEmptyObject(context.req.bodyJson)) {
      return context.res.json({ error: 'invalid_request' }, 400);
    }
    return context.res.json(await service.get(identityResult));
  };
}

function isEmptyObject(value: unknown): value is Record<string, never> {
  return (
    value != null &&
    typeof value === 'object' &&
    !Array.isArray(value) &&
    Object.keys(value).length === 0
  );
}
