import assert from 'node:assert/strict';
import { test } from 'node:test';

import { createMountedRobotRuntime } from '../src/runtime/mounted-robot-runtime.js';

const environment = {
  APPWRITE_FUNCTION_API_ENDPOINT: 'https://cloud.example/v1',
  APPWRITE_FUNCTION_PROJECT_ID: 'project-1',
  DOSEY_DATABASE_ID: 'database-1',
  DOSEY_MOUNTED_ROBOT_ACCESS_TABLE_ID: 'mounted-access',
  DOSEY_ROBOT_INSTALLATIONS_TABLE_ID: 'robot-installations',
};

test('validates mounted robot runtime table configuration', () => {
  const runtime = createMountedRobotRuntime({ 'x-appwrite-key': 'dynamic-key' }, environment);
  assert.ok(runtime.identity);
  assert.ok(runtime.service);

  for (const variable of [
    'DOSEY_MOUNTED_ROBOT_ACCESS_TABLE_ID',
    'DOSEY_ROBOT_INSTALLATIONS_TABLE_ID',
  ]) {
    const missing = { ...environment };
    delete missing[variable as keyof typeof missing];
    assert.throws(
      () => createMountedRobotRuntime({ 'x-appwrite-key': 'dynamic-key' }, missing),
      new RegExp(variable),
    );
  }
});
