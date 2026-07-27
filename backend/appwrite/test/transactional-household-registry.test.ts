import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import { HouseholdFailure } from '../src/application/household-services.js';
import {
  TransactionalHouseholdRegistry,
  type HouseholdInvitationRecord,
  type HouseholdLinkRecord,
  type HouseholdPersistence,
  type HouseholdRobotRecord,
  type HouseholdTransaction,
} from '../src/infrastructure/transactional-household-registry.js';

class MemoryPersistence implements HouseholdPersistence {
  robots = new Map<string, HouseholdRobotRecord>();
  links = new Map<string, HouseholdLinkRecord>();
  invitations = new Map<string, HouseholdInvitationRecord>();

  async transaction<T>(operation: (transaction: HouseholdTransaction) => Promise<T>) {
    const transaction: HouseholdTransaction = {
      getRobot: async (id) => this.robots.get(id) ?? null,
      createRobot: async (record) => void this.robots.set(record.id, record),
      saveRobot: async (record) => void this.robots.set(record.id, record),
      getLink: async (id) => this.links.get(id) ?? null,
      createLink: async (record) => void this.links.set(record.accountId, record),
      saveLink: async (record) => void this.links.set(record.accountId, record),
      deleteLink: async (id) => void this.links.delete(id),
      getInvitation: async (id) => this.invitations.get(id) ?? null,
      findInvitationByDigest: async (digest) =>
        [...this.invitations.values()].find((record) => record.codeDigest === digest) ?? null,
      saveInvitation: async (record) => void this.invitations.set(record.id, record),
    };
    return operation(transaction);
  }
}

const now = new Date('2026-07-26T12:00:00.000Z');

describe('TransactionalHouseholdRegistry', () => {
  test('resumes an owner provisioning reservation without creating another robot', async () => {
    const persistence = new MemoryPersistence();
    const registry = new TransactionalHouseholdRegistry(persistence);

    await registry.reserveOwner({
      robotId: 'robot-1', accountId: 'owner-1', displayName: 'Dosey', now,
    });
    const resumed = await registry.reserveOwner({
      robotId: 'unused-new-id', accountId: 'owner-1', displayName: 'Dosey', now,
    });

    assert.deepEqual(resumed, {
      status: 'resume', robotId: 'robot-1', membershipId: null,
    });
    assert.equal(persistence.robots.size, 1);
  });

  test('atomically consumes an invitation and reserves the seventh human slot', async () => {
    const persistence = seededHousehold(6);
    persistence.invitations.set('invite-1', invitation());
    const registry = new TransactionalHouseholdRegistry(persistence);

    const result = await registry.reserveAcceptance({
      codeDigest: 'digest', accountId: 'member-7', email: 'person@example.com', now,
    });

    assert.equal(result.status, 'reserved');
    assert.equal(persistence.robots.get('robot-1')?.humanCount, 7);
    assert.equal(persistence.links.get('member-7')?.status, 'provisioning');
    assert.equal(persistence.invitations.get('invite-1')?.acceptedAccountId, 'member-7');
  });

  test('rejects an eighth human without consuming the invitation', async () => {
    const persistence = seededHousehold(7);
    persistence.invitations.set('invite-1', invitation());
    const registry = new TransactionalHouseholdRegistry(persistence);

    const result = await registry.reserveAcceptance({
      codeDigest: 'digest', accountId: 'member-8', email: 'person@example.com', now,
    });

    assert.deepEqual(result, { status: 'rejected', reason: 'household_full' });
    assert.equal(persistence.links.has('member-8'), false);
    assert.equal(persistence.invitations.get('invite-1')?.consumedAt, null);
  });

  test('resumes a consumed invitation only for its accepted account without recounting', async () => {
    const persistence = seededHousehold(2);
    persistence.links.set('member-1', {
      accountId: 'member-1', robotId: 'robot-1', role: 'member',
      membershipId: null, status: 'provisioning', createdAt: now, updatedAt: now,
    });
    persistence.invitations.set('invite-1', {
      ...invitation(), consumedAt: now, acceptedAccountId: 'member-1',
    });
    const registry = new TransactionalHouseholdRegistry(persistence);

    const result = await registry.reserveAcceptance({
      codeDigest: 'digest', accountId: 'member-1', email: 'person@example.com',
      now: new Date('2026-07-28T12:00:00.000Z'),
    });

    assert.equal(result.status, 'resume');
    assert.equal(persistence.robots.get('robot-1')?.humanCount, 2);
  });

  test('does not replace the credential needed to resume a consumed acceptance', async () => {
    const persistence = seededHousehold(2);
    persistence.links.set('member-1', {
      accountId: 'member-1', robotId: 'robot-1', role: 'member',
      membershipId: null, status: 'provisioning', createdAt: now, updatedAt: now,
    });
    persistence.invitations.set('invite-1', {
      ...invitation(), consumedAt: now, acceptedAccountId: 'member-1',
    });
    const registry = new TransactionalHouseholdRegistry(persistence);

    await assert.rejects(
      registry.replaceInvitation({
        id: 'invite-1', robotId: 'robot-1', ownerAccountId: 'owner-1',
        invitedEmail: 'person@example.com', codeDigest: 'replacement-digest',
        expiresAt: new Date('2026-07-27T18:00:00.000Z'), now,
      }),
      (error: unknown) => error instanceof HouseholdFailure && error.code === 'already_linked',
    );
    assert.equal(persistence.invitations.get('invite-1')?.codeDigest, 'digest');
  });

  test('decrements once after membership revocation and treats finalization as idempotent', async () => {
    const persistence = seededHousehold(2);
    persistence.links.set('member-1', {
      accountId: 'member-1', robotId: 'robot-1', role: 'member',
      membershipId: 'membership-1', status: 'active', createdAt: now, updatedAt: now,
    });
    const registry = new TransactionalHouseholdRegistry(persistence);

    assert.deepEqual(await registry.beginRevocation({
      robotId: 'robot-1', actorAccountId: 'owner-1', targetAccountId: 'member-1', now,
    }), { status: 'ready', membershipId: 'membership-1' });
    await registry.finalizeRevocation({ robotId: 'robot-1', targetAccountId: 'member-1', now });
    await registry.finalizeRevocation({ robotId: 'robot-1', targetAccountId: 'member-1', now });

    assert.equal(persistence.robots.get('robot-1')?.humanCount, 1);
    assert.equal(persistence.links.has('member-1'), false);
  });
});

function seededHousehold(humanCount: number): MemoryPersistence {
  const persistence = new MemoryPersistence();
  persistence.robots.set('robot-1', {
    id: 'robot-1', ownerAccountId: 'owner-1', displayName: 'Dosey', humanCount,
    status: 'active', createdAt: now, updatedAt: now,
  });
  persistence.links.set('owner-1', {
    accountId: 'owner-1', robotId: 'robot-1', role: 'owner',
    membershipId: 'owner-membership', status: 'active', createdAt: now, updatedAt: now,
  });
  return persistence;
}

function invitation(): HouseholdInvitationRecord {
  return {
    id: 'invite-1', robotId: 'robot-1', invitedEmail: 'person@example.com',
    codeDigest: 'digest', expiresAt: new Date('2026-07-27T12:00:00.000Z'),
    createdByAccountId: 'owner-1', consumedAt: null, acceptedAccountId: null,
    revokedAt: null, createdAt: now, updatedAt: now,
  };
}
