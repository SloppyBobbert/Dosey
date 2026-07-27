import { randomInt } from 'node:crypto';

export const pairingCodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
export const pairingCodeLength = 10;

export class InvalidPairingCodeError extends Error {
  constructor() {
    super('Pairing code must contain 10 supported letters or numbers.');
    this.name = 'InvalidPairingCodeError';
  }
}

export function createPairingCode(
  selectIndex: (maximum: number) => number = randomInt,
): string {
  let code = '';
  for (let index = 0; index < pairingCodeLength; index += 1) {
    const selected = selectIndex(pairingCodeAlphabet.length);
    if (!Number.isInteger(selected) || selected < 0 || selected >= pairingCodeAlphabet.length) {
      throw new RangeError('Pairing code random index is outside the alphabet.');
    }
    code += pairingCodeAlphabet[selected];
  }
  return code;
}

export function normalizePairingCode(value: string): string {
  const normalized = value.trim().toUpperCase().replaceAll('-', '');
  const validCode = new RegExp(`^[${pairingCodeAlphabet}]{${pairingCodeLength}}$`);
  if (!validCode.test(normalized)) throw new InvalidPairingCodeError();
  return normalized;
}
