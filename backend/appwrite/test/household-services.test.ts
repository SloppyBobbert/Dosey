import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import {
  AcceptHouseholdInvitationService,
  CreateHouseholdInvitationService,
  CreateRobotService,
  HouseholdFailure,
  RemoveHouseholdMemberService,
  type HouseholdRegistry,
  type HouseholdTeams,
} from '../src/application/household-services.js';
import { digestHouseholdInvitationCode } from '../src/domain/household-invitation.js';

const now = new Date('2026-07-26T12:00:00.000Z');
const secret = 'household-secret-at-least-32-bytes';

class FakeRegistry implements HouseholdRegistry {
  ownerReservation: Awaited<ReturnType<HouseholdRegistry['reserveOwner']>> = {
    status: 'reserved',
    robotId: 'robot-1',
    membershipId: null,
  };
  acceptance: Awaited<ReturnType<HouseholdRegistry['reserveAcceptance']>> = {
    status: 'reserved',
    robotId: 'robot-1',
    membershipId: null,
  };
  revocation: Awaited<ReturnType<HouseholdRegistry['beginRevocation']>> = {
    status: 'ready',
    membershipId: 'membership-2',
  };
  events: string[] = [];
  revocationTimes: Date[] = [];

  async reserveOwner(input: Parameters<HouseholdRegistry['reserveOwner']>[0]) {
    this.events.push(`reserve-owner:${input.accountId}`);
    return this.ownerReservation;
  }
  async activateLink(input: Parameters<HouseholdRegistry['activateLink']>[0]) {
    this.events.push(`activate:${input.accountId}:${input.membershipId}`);
  }
  async replaceInvitation(input: Parameters<HouseholdRegistry['replaceInvitation']>[0]) {
    this.events.push(`invite:${input.invitedEmail}:${input.codeDigest}`);
  }
  async reserveAcceptance(input: Parameters<HouseholdRegistry['reserveAcceptance']>[0]) {
    this.events.push(`accept:${input.accountId}:${input.email}`);
    return this.acceptance;
  }
  async beginRevocation(input: Parameters<HouseholdRegistry['beginRevocation']>[0]) {
    this.events.push(`revoke:${input.actorAccountId}:${input.targetAccountId}`);
    this.revocationTimes.push(input.now);
    return this.revocation;
  }
  async finalizeRevocation(input: Parameters<HouseholdRegistry['finalizeRevocation']>[0]) {
    this.events.push(`finalize:${input.targetAccountId}`);
    this.revocationTimes.push(input.now);
  }
}

class FakeTeams implements HouseholdTeams {
  events: string[] = [];
  membershipId = 'membership-1';
  async ensureRobot(input: Parameters<HouseholdTeams['ensureRobot']>[0]) {
    this.events.push(
      `robot:${input.robotId}:${input.ownerAccountId}:${input.resumeProvisioning}`,
    );
  }
  async ensureHumanMembership(
    input: Parameters<HouseholdTeams['ensureHumanMembership']>[0],
  ) {
    this.events.push(`member:${input.accountId}:${input.role}`);
    return input.membershipId ?? this.membershipId;
  }
  async deleteHumanMembership(
    input: Parameters<HouseholdTeams['deleteHumanMembership']>[0],
  ) {
    this.events.push(`delete:${input.accountId}:${input.membershipId ?? 'lookup'}`);
  }
  async snapshot(robotId: string, currentAccountId: string) {
    return {
      robotId,
      displayName: 'Kitchen Dosey',
      ownerAccountId: 'owner-1',
      mountedDeviceId: null,
      currentRole: currentAccountId === 'owner-1' ? ('owner' as const) : ('member' as const),
      members: [{ accountId: 'owner-1', label: 'Owner', role: 'owner' as const }],
    };
  }
}

describe('household application services', () => {
  test('creates a robot only after explicit owner Team membership succeeds', async () => {
    const registry = new FakeRegistry();
    const teams = new FakeTeams();
    const service = new CreateRobotService({
      registry,
      teams,
      createId: () => 'robot-1',
      now: () => now,
    });

    const result = await service.create({
      accountId: 'owner-1',
      displayName: ' Kitchen Dosey ',
    });

    assert.equal(result.robotId, 'robot-1');
    assert.deepEqual(registry.events, [
      'reserve-owner:owner-1',
      'activate:owner-1:membership-1',
    ]);
    assert.deepEqual(teams.events, [
      'robot:robot-1:owner-1:false',
      'member:owner-1:owner',
    ]);
  });

  test('authorizes unmarked Team recovery only for a resumed owner reservation', async () => {
    const registry = new FakeRegistry();
    registry.ownerReservation = {
      status: 'resume',
      robotId: 'robot-1',
      membershipId: null,
    };
    const teams = new FakeTeams();
    const service = new CreateRobotService({
      registry,
      teams,
      createId: () => 'unused',
      now: () => now,
    });

    await service.create({ accountId: 'owner-1', displayName: 'Dosey' });

    assert.equal(teams.events[0], 'robot:robot-1:owner-1:true');
  });

  test('rejects overlong Team names before reserving an owner link', async () => {
    const registry = new FakeRegistry();
    const service = new CreateRobotService({
      registry,
      teams: new FakeTeams(),
      createId: () => 'robot-1',
      now: () => now,
    });

    await assert.rejects(
      service.create({ accountId: 'owner-1', displayName: 'D'.repeat(129) }),
      /128 characters or fewer/,
    );
    assert.deepEqual(registry.events, []);
  });

  test('does not activate a robot when owner membership provisioning fails', async () => {
    const registry = new FakeRegistry();
    const teams = new FakeTeams();
    teams.ensureHumanMembership = async () => {
      throw new Error('Teams unavailable');
    };
    const service = new CreateRobotService({
      registry,
      teams,
      createId: () => 'robot-1',
      now: () => now,
    });

    await assert.rejects(
      service.create({ accountId: 'owner-1', displayName: 'Dosey' }),
      /Teams unavailable/,
    );
    assert.deepEqual(registry.events, ['reserve-owner:owner-1']);
  });

  test('rejects an owner already linked to another robot', async () => {
    const registry = new FakeRegistry();
    registry.ownerReservation = { status: 'already_linked' };
    const service = new CreateRobotService({
      registry,
      teams: new FakeTeams(),
      createId: () => 'robot-1',
      now: () => now,
    });
    await assert.rejects(
      service.create({ accountId: 'owner-1', displayName: 'Dosey' }),
      (error: unknown) => error instanceof HouseholdFailure && error.code === 'already_linked',
    );
  });

  test('replaces an owner invitation without reserving a human slot', async () => {
    const registry = new FakeRegistry();
    const service = new CreateHouseholdInvitationService({
      registry,
      secret,
      now: () => now,
      randomBytes: () => Buffer.alloc(12),
    });

    const credential = await service.create({
      robotId: 'robot-1',
      ownerAccountId: 'owner-1',
      invitedEmail: ' Person@Example.com ',
    });

    assert.equal(credential.code, 'AAAAAAAAAAAAAAAA');
    assert.equal(credential.expiresAt.toISOString(), '2026-07-27T12:00:00.000Z');
    assert.match(registry.events[0]!, /^invite:person@example\.com:/);
    assert.ok(!registry.events[0]!.includes(credential.code));
  });

  test('resumes consumed acceptance without recounting and activates membership', async () => {
    const registry = new FakeRegistry();
    registry.acceptance = {
      status: 'resume',
      robotId: 'robot-1',
      membershipId: null,
    };
    const teams = new FakeTeams();
    const service = new AcceptHouseholdInvitationService({ registry, teams, secret, now: () => now });

    await service.accept({
      accountId: 'member-1',
      email: 'person@example.com',
      code: 'ABCD2EFGH3JKMNPQ',
    });

    assert.deepEqual(registry.events, [
      'accept:member-1:person@example.com',
      'activate:member-1:membership-1',
    ]);
  });

  test('does not create Team membership when the household is full', async () => {
    const registry = new FakeRegistry();
    registry.acceptance = { status: 'rejected', reason: 'household_full' };
    const teams = new FakeTeams();
    const service = new AcceptHouseholdInvitationService({ registry, teams, secret, now: () => now });

    await assert.rejects(
      service.accept({
        accountId: 'member-8',
        email: 'person@example.com',
        code: 'ABCD2EFGH3JKMNPQ',
      }),
      (error: unknown) => error instanceof HouseholdFailure && error.code === 'household_full',
    );
    assert.deepEqual(teams.events, []);
  });

  test('revokes the exact human membership before freeing the slot', async () => {
    const registry = new FakeRegistry();
    const teams = new FakeTeams();
    const service = new RemoveHouseholdMemberService({ registry, teams, now: () => now });

    const snapshot = await service.remove({
      robotId: 'robot-1',
      actorAccountId: 'owner-1',
      targetAccountId: 'member-1',
    });

    assert.equal(snapshot?.robotId, 'robot-1');
    assert.deepEqual(teams.events, ['delete:member-1:membership-2']);
    assert.deepEqual(registry.events, [
      'revoke:owner-1:member-1',
      'finalize:member-1',
    ]);
    assert.deepEqual(registry.revocationTimes, [now, now]);
  });

  test('resolves a provisioning member by account before freeing its slot', async () => {
    const registry = new FakeRegistry();
    registry.revocation = { status: 'ready', membershipId: null };
    const teams = new FakeTeams();
    const service = new RemoveHouseholdMemberService({ registry, teams, now: () => now });

    await service.remove({
      robotId: 'robot-1',
      actorAccountId: 'owner-1',
      targetAccountId: 'member-1',
    });

    assert.deepEqual(teams.events, ['delete:member-1:lookup']);
    assert.ok(registry.events.includes('finalize:member-1'));
  });

  test('treats finalized removal retries as success without another deletion', async () => {
    const registry = new FakeRegistry();
    registry.revocation = { status: 'already_removed' };
    const teams = new FakeTeams();
    const service = new RemoveHouseholdMemberService({ registry, teams, now: () => now });
    await service.remove({
      robotId: 'robot-1',
      actorAccountId: 'member-1',
      targetAccountId: 'member-1',
    });
    assert.deepEqual(teams.events, []);
    assert.ok(!registry.events.some((event) => event.startsWith('finalize:')));
  });

  test('returns the owner snapshot when a finalized member removal is retried', async () => {
    const registry = new FakeRegistry();
    registry.revocation = { status: 'already_removed' };
    const teams = new FakeTeams();
    const service = new RemoveHouseholdMemberService({ registry, teams, now: () => now });

    const snapshot = await service.remove({
      robotId: 'robot-1',
      actorAccountId: 'owner-1',
      targetAccountId: 'member-1',
    });

    assert.equal(snapshot?.robotId, 'robot-1');
    assert.deepEqual(teams.events, []);
    assert.ok(!registry.events.some((event) => event.startsWith('finalize:')));
  });

  test('digests normalized invitation codes without exposing plaintext', () => {
    assert.equal(
      digestHouseholdInvitationCode('abcd2-efgh3-jkmnpq', secret),
      digestHouseholdInvitationCode('ABCD2EFGH3JKMNPQ', secret),
    );
  });
});
