import type { IssuedPairingCredential } from '../application/pairing-credential.js';
import { RobotOwnerRequiredError } from '../application/pairing-services.js';
import type { FunctionContext } from './claim-robot.js';

export interface CreatePairingCodeService {
  create(input: {
    robotId: string;
    ownerAccountId: string;
  }): Promise<IssuedPairingCredential>;
}

export function createPairingCodeHandler(service: CreatePairingCodeService) {
  return async (context: FunctionContext) => {
    if (context.req.method !== 'POST') {
      return context.res.json({ error: 'method_not_allowed' }, 405);
    }
    const ownerAccountId = context.req.headers['x-appwrite-user-id'];
    if (ownerAccountId == null || ownerAccountId.length === 0) {
      return context.res.json({ error: 'authentication_required' }, 401);
    }

    const robotId = readRobotId(context.req.bodyJson);
    if (robotId == null) {
      return context.res.json({ error: 'invalid_robot_id' }, 400);
    }

    try {
      const credential = await service.create({ robotId, ownerAccountId });
      return context.res.json({
        code: credential.code,
        expiresAt: credential.record.expiresAt.toISOString(),
      });
    } catch (error) {
      if (error instanceof RobotOwnerRequiredError) {
        return context.res.json({ error: 'owner_required' }, 403);
      }
      throw error;
    }
  };
}

function readRobotId(body: unknown): string | null {
  if (body == null || typeof body !== 'object' || !('robotId' in body)) {
    return null;
  }
  const robotId = body.robotId;
  return typeof robotId === 'string' && robotId.trim().length > 0
    ? robotId.trim()
    : null;
}
