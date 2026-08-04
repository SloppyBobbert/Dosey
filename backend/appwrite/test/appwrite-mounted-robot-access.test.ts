import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  AppwriteMountedRobotAccessReader,
} from '../src/infrastructure/appwrite-mounted-robot-access.js';
import type { TablesDB } from 'node-appwrite';

test('maps mounted access and active robot installation rows without Teams access', async () => {
  const calls: Array<{ tableId: string; queries?: readonly string[] }> = [];
  const tables = {
    listRows: async (input: any) => {
      calls.push({ tableId: input.tableId, queries: input.queries });
      return {
        rows: [{
          $id: 'robot-1',
          robotId: 'robot-1',
          mountedDeviceAccountId: 'device-1',
          registeredPatientDeviceId: 'patient-device-1',
          pairingClaimId: 'claim-1',
          createdAt: '2026-07-26T12:00:00.000Z',
          updatedAt: '2026-07-26T12:01:00.000Z',
        }],
      };
    },
    getRow: async () => ({
      $id: 'robot-1',
      displayName: 'Kitchen Dosey',
      status: 'active',
    }),
  } as unknown as TablesDB;
  const reader = new AppwriteMountedRobotAccessReader(tables, {
    databaseId: 'database-1',
    mountedRobotAccessTableId: 'mounted-access',
    robotInstallationsTableId: 'robot-installations',
  });

  assert.deepEqual(await reader.findByDevice('device-1'), [{
    robotId: 'robot-1',
    mountedDeviceAccountId: 'device-1',
    registeredPatientDeviceId: 'patient-device-1',
    pairingClaimId: 'claim-1',
    createdAt: new Date('2026-07-26T12:00:00.000Z'),
    updatedAt: new Date('2026-07-26T12:01:00.000Z'),
  }]);
  assert.deepEqual(await reader.getRobotInstallation('robot-1'), {
    robotId: 'robot-1', displayName: 'Kitchen Dosey', status: 'active',
  });
  assert.deepEqual(calls, [{
    tableId: 'mounted-access',
    queries: [
      '{"method":"equal","attribute":"mountedDeviceAccountId","values":["device-1"]}',
      '{"method":"limit","values":[2]}',
    ],
  }]);
});

test('maps legacy mounted access rows without a registered patient device ID to null', async () => {
  const reader = new AppwriteMountedRobotAccessReader({
    listRows: async () => ({ rows: [{
      $id: 'robot-1', robotId: 'robot-1', mountedDeviceAccountId: 'device-1',
      pairingClaimId: 'claim-1', createdAt: '2026-07-26T12:00:00.000Z',
      updatedAt: '2026-07-26T12:00:00.000Z',
    }] }),
  } as unknown as TablesDB, {
    databaseId: 'database-1', mountedRobotAccessTableId: 'mounted-access',
    robotInstallationsTableId: 'robot-installations',
  });

  assert.equal((await reader.findByDevice('device-1'))[0]?.registeredPatientDeviceId, null);
});

test('does not turn malformed installation rows into an absent robot', async () => {
  const tables = {
    getRow: async () => ({ $id: 'robot-1', displayName: '', status: 'active' }),
  } as unknown as TablesDB;
  const reader = new AppwriteMountedRobotAccessReader(tables, {
    databaseId: 'database-1',
    mountedRobotAccessTableId: 'mounted-access',
    robotInstallationsTableId: 'robot-installations',
  });

  await assert.rejects(reader.getRobotInstallation('robot-1'), /displayName/);

  const mismatched = new AppwriteMountedRobotAccessReader({
    getRow: async () => ({ $id: 'robot-2', displayName: 'Dosey', status: 'active' }),
  } as unknown as TablesDB, {
    databaseId: 'database-1',
    mountedRobotAccessTableId: 'mounted-access',
    robotInstallationsTableId: 'robot-installations',
  });
  await assert.rejects(mismatched.getRobotInstallation('robot-1'), /row ID/);
});

test('rejects mounted rows whose row ID disagrees with robotId or requested device', async () => {
  const tables = {
    listRows: async () => ({ rows: [{
      $id: 'robot-2', robotId: 'robot-1', mountedDeviceAccountId: 'other-device',
      pairingClaimId: 'claim-1', createdAt: '2026-07-26T12:00:00.000Z',
      updatedAt: '2026-07-26T12:00:00.000Z',
    }] }),
  } as unknown as TablesDB;
  const reader = new AppwriteMountedRobotAccessReader(tables, {
    databaseId: 'database-1',
    mountedRobotAccessTableId: 'mounted-access',
    robotInstallationsTableId: 'robot-installations',
  });

  await assert.rejects(reader.findByDevice('device-1'), /row ID|device/);
});
