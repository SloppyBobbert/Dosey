import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import {
  AppwriteHouseholdPersistence,
  type HouseholdRow,
  type HouseholdRowsApi,
  type HouseholdTable,
} from '../src/infrastructure/appwrite-household-persistence.js';

class FakeRows implements HouseholdRowsApi {
  events: string[] = [];
  rows = new Map<string, HouseholdRow>();
  commitFailures = 0;

  async beginTransaction() {
    this.events.push('begin');
    return `transaction-${this.events.filter((event) => event === 'begin').length}`;
  }
  async commitTransaction(id: string) {
    this.events.push(`commit:${id}`);
    if (this.commitFailures-- > 0) throw { code: 409 };
  }
  async rollbackTransaction(id: string) { this.events.push(`rollback:${id}`); }
  async getRow(table: HouseholdTable, id: string, transactionId: string) {
    this.events.push(`get:${table}:${id}:${transactionId}`);
    return this.rows.get(`${table}:${id}`) ?? null;
  }
  async createRow(table: HouseholdTable, row: HouseholdRow, transactionId: string) {
    this.events.push(`create:${table}:${row.$id}:${transactionId}`);
    this.rows.set(`${table}:${row.$id}`, row);
  }
  async upsertRow(table: HouseholdTable, row: HouseholdRow, transactionId: string) {
    this.events.push(`upsert:${table}:${row.$id}:${transactionId}`);
    this.rows.set(`${table}:${row.$id}`, row);
  }
  async updateRow(table: HouseholdTable, row: HouseholdRow, transactionId: string) {
    this.events.push(`update:${table}:${row.$id}:${transactionId}`);
    this.rows.set(`${table}:${row.$id}`, row);
  }
  async deleteRow(table: HouseholdTable, id: string, transactionId: string) {
    this.events.push(`delete:${table}:${id}:${transactionId}`);
    this.rows.delete(`${table}:${id}`);
  }
  async findInvitationsByDigest(digest: string, transactionId: string) {
    this.events.push(`digest:${digest}:${transactionId}`);
    return [...this.rows.entries()]
      .filter(([key, row]) => key.startsWith('invitations:') && row.codeDigest === digest)
      .map(([, row]) => row);
  }
}

describe('Appwrite household persistence', () => {
  test('maps nullable membership and invitation dates to Appwrite rows', async () => {
    const rows = new FakeRows();
    const persistence = new AppwriteHouseholdPersistence(rows);

    await persistence.transaction(async (transaction) => {
      await transaction.createLink({
        accountId: 'member-1', robotId: 'robot-1', role: 'member', membershipId: null,
        status: 'provisioning', createdAt: new Date('2026-07-26T12:00:00Z'),
        updatedAt: new Date('2026-07-26T12:00:00Z'),
      });
      await transaction.saveInvitation({
        id: 'invite-1', robotId: 'robot-1', invitedEmail: 'person@example.com',
        codeDigest: 'digest', expiresAt: new Date('2026-07-27T12:00:00Z'),
        createdByAccountId: 'owner-1', consumedAt: null, acceptedAccountId: null,
        revokedAt: null, createdAt: new Date('2026-07-26T12:00:00Z'),
        updatedAt: new Date('2026-07-26T12:00:00Z'),
      });
    });

    assert.equal(rows.rows.get('links:member-1')?.membershipId, null);
    assert.equal(rows.rows.get('invitations:invite-1')?.consumedAt, null);
    assert.equal(rows.rows.get('invitations:invite-1')?.expiresAt, '2026-07-27T12:00:00.000Z');
  });

  test('re-runs the whole transaction after a commit conflict', async () => {
    const rows = new FakeRows();
    rows.commitFailures = 1;
    const persistence = new AppwriteHouseholdPersistence(rows);
    let attempts = 0;

    await persistence.transaction(async () => { attempts += 1; });

    assert.equal(attempts, 2);
    assert.deepEqual(rows.events, [
      'begin', 'commit:transaction-1', 'rollback:transaction-1',
      'begin', 'commit:transaction-2',
    ]);
  });

  test('rejects duplicate invitation digests', async () => {
    const rows = new FakeRows();
    rows.rows.set('invitations:one', { $id: 'one', codeDigest: 'digest' });
    rows.rows.set('invitations:two', { $id: 'two', codeDigest: 'digest' });
    const persistence = new AppwriteHouseholdPersistence(rows);

    await assert.rejects(
      persistence.transaction((transaction) => transaction.findInvitationByDigest('digest')),
      /Multiple household invitations share one digest/,
    );
  });
});
