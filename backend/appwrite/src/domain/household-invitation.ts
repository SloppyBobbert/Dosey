import { createHmac, createHash } from 'node:crypto';

const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
export const householdInvitationLifetimeMs = 24 * 60 * 60 * 1000;

export function issueHouseholdInvitationCode(bytes: Buffer): string {
  if (bytes.length !== 12) throw new RangeError('Twelve random bytes are required.');
  let bits = 0;
  let value = 0;
  let output = '';
  for (const byte of bytes) {
    value = (value << 8) | byte;
    bits += 8;
    while (bits >= 5 && output.length < 16) {
      output += alphabet[(value >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }
  return output;
}

export function normalizeHouseholdInvitationCode(value: string): string {
  const normalized = value.toUpperCase().replace(/[\s-]/g, '');
  if (normalized.length !== 16 || [...normalized].some((character) => !alphabet.includes(character))) {
    throw new Error('Invalid household invitation code.');
  }
  return normalized;
}

export function digestHouseholdInvitationCode(code: string, secret: string): string {
  return createHmac('sha256', secret)
    .update(normalizeHouseholdInvitationCode(code), 'utf8')
    .digest('hex');
}

export function householdInvitationId(robotId: string, normalizedEmail: string): string {
  return createHash('sha256').update(`${robotId}\n${normalizedEmail}`, 'utf8').digest('hex');
}
