import {
  InvalidPairingCodeError,
  normalizePairingCode,
} from '../domain/pairing-code.js';
import type { PairingClaimRejectionReason } from '../domain/pairing-claim.js';
import type { FunctionIdentityVerifier } from './function-identity.js';

export interface ClaimRobotService {
  claimRobot(input: {
    code: string;
    mountedDeviceAccountId: string;
  }): Promise<
    | { status: 'accepted'; robotId: string }
    | { status: 'rejected'; reason: PairingClaimRejectionReason }
  >;
}

interface FunctionRequest {
  readonly method: string;
  readonly headers: Readonly<Record<string, string | undefined>>;
  readonly bodyJson: unknown;
}

interface FunctionResponse {
  json(body: unknown, status?: number): unknown;
}

export interface FunctionContext {
  readonly req: FunctionRequest;
  readonly res: FunctionResponse;
  readonly error: (message: string) => void;
}

export function createClaimRobotHandler(
  service: ClaimRobotService,
  identity: FunctionIdentityVerifier,
) {
  return async (context: FunctionContext) => {
    if (context.req.method !== 'POST') {
      return context.res.json({ error: 'method_not_allowed' }, 405);
    }
    const mountedDeviceAccountId = await identity.verify(context.req.headers);
    if (mountedDeviceAccountId == null) {
      return context.res.json({ error: 'authentication_required' }, 401);
    }

    let code: string;
    try {
      code = normalizePairingCode(readCode(context.req.bodyJson));
    } catch (error) {
      if (error instanceof InvalidPairingCodeError || error instanceof TypeError) {
        return context.res.json({ error: 'invalid_pairing_code' }, 400);
      }
      throw error;
    }

    const result = await service.claimRobot({ code, mountedDeviceAccountId });
    if (result.status === 'accepted') {
      return context.res.json({ robotId: result.robotId });
    }
    return context.res.json(
      { error: result.reason },
      rejectionStatus[result.reason],
    );
  };
}

const rejectionStatus: Record<PairingClaimRejectionReason, number> = {
  invalid: 400,
  expired: 410,
  consumed: 409,
  attempts_exhausted: 429,
};

function readCode(body: unknown): string {
  if (body == null || typeof body !== 'object' || !('code' in body)) {
    throw new TypeError('Pairing code is required.');
  }
  const code = body.code;
  if (typeof code !== 'string') throw new TypeError('Pairing code must be text.');
  return code;
}
