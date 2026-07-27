import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import { AppwriteFunctionIdentityVerifier } from '../src/functions/function-identity.js';

describe('Appwrite function identity verification', () => {
  test('accepts only a JWT-authenticated account matching the user header', async () => {
    const verifier = new AppwriteFunctionIdentityVerifier({
      getCurrentAccountId: async () => 'account-1',
    });

    assert.equal(
      await verifier.verify({
        'x-appwrite-user-id': 'account-1',
        'x-appwrite-user-jwt': 'jwt',
      }),
      'account-1',
    );
    assert.equal(
      await verifier.verify({
        'x-appwrite-user-id': 'forged-account',
        'x-appwrite-user-jwt': 'jwt',
      }),
      null,
    );
    assert.equal(
      await verifier.verify({ 'x-appwrite-user-id': 'account-1' }),
      null,
    );
  });

  test('rejects invalid JWTs without exposing the SDK error', async () => {
    const verifier = new AppwriteFunctionIdentityVerifier({
      getCurrentAccountId: async () => {
        throw new Error('invalid jwt details');
      },
    });

    assert.equal(
      await verifier.verify({
        'x-appwrite-user-id': 'account-1',
        'x-appwrite-user-jwt': 'bad-jwt',
      }),
      null,
    );
  });
});
