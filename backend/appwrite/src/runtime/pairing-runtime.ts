import { Client, ID, TablesDB, Teams } from 'node-appwrite';

import {
  ClaimRobotApplicationService,
  CreatePairingCodeApplicationService,
} from '../application/pairing-services.js';
import {
  AppwritePairingPersistence,
  AppwritePairingRowsApi,
} from '../infrastructure/appwrite-pairing-persistence.js';
import {
  AppwriteRobotAccessDirectory,
  AppwriteRobotTeamsApi,
} from '../infrastructure/appwrite-robot-access-directory.js';
import { TransactionalPairingStore } from '../infrastructure/transactional-pairing-store.js';

export function createPairingRuntime(environment = process.env) {
  const client = new Client()
    .setEndpoint(
      required(
        environment.APPWRITE_FUNCTION_API_ENDPOINT ?? environment.APPWRITE_ENDPOINT,
        'APPWRITE_FUNCTION_API_ENDPOINT',
      ),
    )
    .setProject(
      required(
        environment.APPWRITE_FUNCTION_PROJECT_ID ?? environment.APPWRITE_PROJECT_ID,
        'APPWRITE_FUNCTION_PROJECT_ID',
      ),
    )
    .setKey(required(environment.APPWRITE_FUNCTION_API_KEY, 'APPWRITE_FUNCTION_API_KEY'));

  const tables = new AppwritePairingRowsApi(new TablesDB(client), {
    databaseId: required(environment.DOSEY_DATABASE_ID, 'DOSEY_DATABASE_ID'),
    pairingClaimsTableId: required(
      environment.DOSEY_PAIRING_CLAIMS_TABLE_ID,
      'DOSEY_PAIRING_CLAIMS_TABLE_ID',
    ),
    pairingAttemptsTableId: required(
      environment.DOSEY_PAIRING_ATTEMPTS_TABLE_ID,
      'DOSEY_PAIRING_ATTEMPTS_TABLE_ID',
    ),
  });
  const store = new TransactionalPairingStore(
    new AppwritePairingPersistence(tables),
  );
  const robots = new AppwriteRobotAccessDirectory(
    new AppwriteRobotTeamsApi(new Teams(client)),
  );
  const secret = required(environment.DOSEY_PAIRING_HMAC_SECRET, 'DOSEY_PAIRING_HMAC_SECRET');

  return {
    createPairingCode: new CreatePairingCodeApplicationService({
      store,
      robots,
      secret,
      createId: ID.unique,
      now: () => new Date(),
    }),
    claimRobot: new ClaimRobotApplicationService({
      store,
      robots,
      secret,
      now: () => new Date(),
    }),
  };
}

function required(value: string | undefined, name: string): string {
  if (value == null || value.trim().length === 0) {
    throw new Error(`Missing required function environment variable: ${name}.`);
  }
  return value.trim();
}
