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

  test('accepts only a verified Google account as a human identity', async () => {
    const verifier = new AppwriteFunctionIdentityVerifier({
      getCurrentAccountId: async () => 'account-1',
      getCurrentHumanAccount: async () => ({
        id: 'account-1',
        email: ' Person@Example.com ',
        emailVerified: true,
        provider: 'google',
      }),
    });

    assert.deepEqual(
      await verifier.verifyHuman({
        'x-appwrite-user-id': 'account-1',
        'x-appwrite-user-jwt': 'jwt',
      }),
      { accountId: 'account-1', email: 'person@example.com' },
    );
  });

  test('rejects anonymous, unverified, non-Google, and mismatched humans', async () => {
    for (const account of [
      {
        id: 'account-1',
        email: '',
        emailVerified: true,
        provider: 'google',
      },
      {
        id: 'account-1',
        email: 'person@example.com',
        emailVerified: false,
        provider: 'google',
      },
      {
        id: 'account-1',
        email: 'person@example.com',
        emailVerified: true,
        provider: 'anonymous',
      },
      {
        id: 'different-account',
        email: 'person@example.com',
        emailVerified: true,
        provider: 'google',
      },
    ]) {
      const verifier = new AppwriteFunctionIdentityVerifier({
        getCurrentAccountId: async () => account.id,
        getCurrentHumanAccount: async () => account,
      });

      assert.equal(
        await verifier.verifyHuman({
          'x-appwrite-user-id': 'account-1',
          'x-appwrite-user-jwt': 'jwt',
        }),
        null,
      );
    }
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
