import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import {
  AppwriteHouseholdTeams,
  type HouseholdTeam,
  type HouseholdTeamMembership,
  type HouseholdTeamsApi,
} from '../src/infrastructure/appwrite-household-teams.js';

class FakeTeams implements HouseholdTeamsApi {
  team: HouseholdTeam | null = null;
  memberships: HouseholdTeamMembership[] = [];
  events: string[] = [];
  createdMembershipConfirmed = true;

  async getTeam() { return this.team; }
  async createTeam(id: string, name: string) {
    this.events.push(`create-team:${id}:${name}`);
    this.team = { id, name, preferences: {} };
    return this.team;
  }
  async updateTeamName(_id: string, name: string) {
    this.events.push(`name:${name}`);
    this.team = { ...this.team!, name };
  }
  async updatePreferences(_id: string, preferences: Readonly<Record<string, unknown>>) {
    this.events.push('prefs');
    this.team = { ...this.team!, preferences };
  }
  async listMemberships() { return this.memberships; }
  async getMembership(_robotId: string, id: string) {
    return this.memberships.find((membership) => membership.id === id) ?? null;
  }
  async createMembership(_robotId: string, accountId: string, roles: readonly string[]) {
    const membership = {
      id: `membership-${accountId}`, accountId, roles,
      confirmed: this.createdMembershipConfirmed,
      userName: accountId === 'owner-1' ? 'Owner Name' : '', userEmail: `${accountId}@example.com`,
    };
    this.events.push(`membership:${accountId}:${roles.join(',')}`);
    this.memberships.push(membership);
    return membership;
  }
  async deleteMembership(_robotId: string, id: string) {
    this.events.push(`delete:${id}`);
    this.memberships = this.memberships.filter((membership) => membership.id !== id);
  }
}

describe('Appwrite household Teams projection', () => {
  test('creates and marks a robot before explicitly creating its owner membership', async () => {
    const api = new FakeTeams();
    const teams = new AppwriteHouseholdTeams(api);

    await teams.ensureRobot({ robotId: 'robot-1', displayName: 'Dosey', ownerAccountId: 'owner-1' });
    const membershipId = await teams.ensureHumanMembership({
      robotId: 'robot-1', accountId: 'owner-1', role: 'owner', membershipId: null,
    });

    assert.equal(membershipId, 'membership-owner-1');
    assert.deepEqual(api.events, [
      'create-team:robot-1:Dosey', 'prefs', 'membership:owner-1:owner',
    ]);
    assert.deepEqual(api.team?.preferences, {
      doseyRobot: true, householdSchemaVersion: 1,
      ownerAccountId: 'owner-1', mountedDeviceId: null,
    });
  });

  test('finishes marking a Team created before a failed preference write', async () => {
    const api = new FakeTeams();
    api.team = { id: 'robot-1', name: 'Dosey', preferences: {} };
    const teams = new AppwriteHouseholdTeams(api);

    await teams.ensureRobot({
      robotId: 'robot-1', displayName: 'Dosey', ownerAccountId: 'owner-1',
    });

    assert.deepEqual(api.events, ['prefs']);
    assert.deepEqual(api.team.preferences, {
      doseyRobot: true, householdSchemaVersion: 1,
      ownerAccountId: 'owner-1', mountedDeviceId: null,
    });
  });

  test('recovers an existing membership by account ID without duplicating it', async () => {
    const api = markedTeam();
    api.memberships.push({
      id: 'membership-1', accountId: 'member-1', roles: ['member'], confirmed: true,
      userName: 'Member', userEmail: 'member@example.com',
    });
    const teams = new AppwriteHouseholdTeams(api);

    const id = await teams.ensureHumanMembership({
      robotId: 'robot-1', accountId: 'member-1', role: 'member', membershipId: null,
    });

    assert.equal(id, 'membership-1');
    assert.equal(api.events.length, 0);
  });

  test('does not activate a newly created unconfirmed membership', async () => {
    const api = markedTeam();
    api.createdMembershipConfirmed = false;
    const teams = new AppwriteHouseholdTeams(api);

    await assert.rejects(
      teams.ensureHumanMembership({
        robotId: 'robot-1', accountId: 'member-1', role: 'member', membershipId: null,
      }),
      /does not match/,
    );
  });

  test('never deletes a robot-device membership through the human lifecycle', async () => {
    const api = markedTeam();
    api.memberships.push(
      {
        id: 'device-membership', accountId: 'device-1', roles: ['robot-device'],
        confirmed: true, userName: '', userEmail: '',
      },
      {
        id: 'mixed-membership', accountId: 'device-2', roles: ['member', 'robot-device'],
        confirmed: true, userName: '', userEmail: '',
      },
    );
    const teams = new AppwriteHouseholdTeams(api);

    for (const membershipId of ['device-membership', 'mixed-membership']) {
      await assert.rejects(
        teams.deleteHumanMembership({ robotId: 'robot-1', membershipId }),
        /robot-device/,
      );
    }
    assert.equal(api.events.length, 0);
  });

  test('builds a snapshot from confirmed human memberships only', async () => {
    const api = markedTeam();
    api.memberships.push(
      { id: 'owner-membership', accountId: 'owner-1', roles: ['owner'], confirmed: true, userName: 'Owner', userEmail: 'owner@example.com' },
      { id: 'member-membership', accountId: 'member-1', roles: ['member'], confirmed: true, userName: '', userEmail: 'member@example.com' },
      { id: 'device-membership', accountId: 'device-1', roles: ['robot-device'], confirmed: true, userName: '', userEmail: '' },
      { id: 'mixed-membership', accountId: 'device-2', roles: ['member', 'robot-device'], confirmed: true, userName: 'Mixed', userEmail: '' },
    );
    const teams = new AppwriteHouseholdTeams(api);

    const snapshot = await teams.snapshot('robot-1', 'member-1');

    assert.equal(snapshot.currentRole, 'member');
    assert.equal(snapshot.mountedDeviceId, 'device-1');
    assert.deepEqual(snapshot.members.map((member) => member.label), [
      'Owner', 'member@example.com', 'Mixed',
    ]);
  });
});

function markedTeam(): FakeTeams {
  const api = new FakeTeams();
  api.team = {
    id: 'robot-1', name: 'Dosey', preferences: {
      doseyRobot: true, householdSchemaVersion: 1,
      ownerAccountId: 'owner-1', mountedDeviceId: 'device-1',
    },
  };
  return api;
}
