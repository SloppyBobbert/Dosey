import { createHmac } from 'node:crypto';

import { createPairingCode } from '../domain/pairing-code.js';
import type { PairingClaimRecord } from '../domain/pairing-claim.js';

export const pairingCodeLifetimeMs = 10 * 60 * 1000;

export interface IssuedPairingCredential {
  readonly code: string;
  readonly record: PairingClaimRecord;
}

export function issuePairingCredential(input: {
  robotId: string;
  claimId: string;
  secret: string;
  now: Date;
  selectIndex?: (maximum: number) => number;
}): IssuedPairingCredential {
  if (input.secret.length < 32) {
    throw new Error('Pairing digest secret must contain at least 32 characters.');
  }
  const code = createPairingCode(input.selectIndex);
  return {
    code,
    record: {
      id: input.claimId,
      robotId: input.robotId,
      codeDigest: digestPairingCode(code, input.secret),
      expiresAt: new Date(input.now.getTime() + pairingCodeLifetimeMs),
      consumedAt: null,
    },
  };
}

export function digestPairingCode(code: string, secret: string): string {
  return createHmac('sha256', secret).update(code).digest('hex');
}
