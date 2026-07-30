import { Account, Client, TablesDB } from 'node-appwrite';

import {
  MedicationSyncPullService,
  MedicationSyncPushService,
} from '../application/medication-sync-services.js';
import {
  HouseholdAccessAuthorizer,
  MedicationSyncAccessAuthorizer,
} from '../application/household-access.js';
import { AppwriteFunctionIdentityVerifier } from '../functions/function-identity.js';
import type { MedicationSyncRequestParser } from '../functions/medication-sync-handlers.js';
import { medicationSyncContractParser } from '../functions/medication-sync-contract-adapter.js';
import {
  AppwriteHouseholdAccessRowsApi,
  AppwriteHouseholdLinkLookup,
} from '../infrastructure/appwrite-household-access.js';
import {
  AppwriteMedicationSyncPersistence,
  AppwriteMedicationSyncRowsApi,
} from '../infrastructure/appwrite-medication-sync-persistence.js';
import { TransactionalMedicationSyncStore } from '../infrastructure/transactional-medication-sync-store.js';
import { AppwriteMountedRobotAccessReader } from '../infrastructure/appwrite-mounted-robot-access.js';

export function createMedicationSyncRuntime(
  headers: Readonly<Record<string, string | undefined>>,
  parser: MedicationSyncRequestParser = medicationSyncContractParser,
  environment: Readonly<Record<string, string | undefined>> = process.env,
  reportError: (message: string) => void = () => {},
) {
  const endpoint = required(
    environment.APPWRITE_FUNCTION_API_ENDPOINT ?? environment.APPWRITE_ENDPOINT,
    'APPWRITE_FUNCTION_API_ENDPOINT',
  );
  const projectId = required(
    environment.APPWRITE_FUNCTION_PROJECT_ID ?? environment.APPWRITE_PROJECT_ID,
    'APPWRITE_FUNCTION_PROJECT_ID',
  );
  const databaseId = required(environment.DOSEY_DATABASE_ID, 'DOSEY_DATABASE_ID');
  const humanRobotLinksTableId = required(
    environment.DOSEY_HUMAN_ROBOT_LINKS_TABLE_ID,
    'DOSEY_HUMAN_ROBOT_LINKS_TABLE_ID',
  );
  const adminClient = new Client()
    .setEndpoint(endpoint)
    .setProject(projectId)
    .setKey(required(headers['x-appwrite-key'], 'x-appwrite-key'));
  const userJwt = headers['x-appwrite-user-jwt']?.trim();
  const currentAccount = () => {
    if (userJwt == null || userJwt.length === 0) {
      throw new Error('Missing Appwrite user JWT.');
    }
    return new Account(
      new Client().setEndpoint(endpoint).setProject(projectId).setJWT(userJwt),
    );
  };
  const identity = new AppwriteFunctionIdentityVerifier(
    {
      async getCurrentAccountId() {
        return (await currentAccount().get()).$id;
      },
      async getCurrentAnonymousAccount() {
        const account = currentAccount();
        const [user, session] = await Promise.all([
          account.get(),
          account.getSession({ sessionId: 'current' }),
        ]);
        return {
          accountId: user.$id,
          sessionUserId: session.userId,
          provider: session.provider,
        };
      },
      async getCurrentHumanAccount() {
        const account = currentAccount();
        const [user, session] = await Promise.all([
          account.get(),
          account.getSession({ sessionId: 'current' }),
        ]);
        return {
          id: user.$id,
          email: user.email,
          emailVerified: user.emailVerification,
          provider: session.provider,
        };
      },
    },
    configuredHumanProviders(environment.DOSEY_HUMAN_AUTH_PROVIDERS),
  );
  const tables = new TablesDB(adminClient);
  const access = new MedicationSyncAccessAuthorizer(
    new HouseholdAccessAuthorizer(
      new AppwriteHouseholdLinkLookup(
        new AppwriteHouseholdAccessRowsApi(tables, databaseId, humanRobotLinksTableId),
      ),
    ),
    new AppwriteMountedRobotAccessReader(tables, {
      databaseId,
      mountedRobotAccessTableId: required(
        environment.DOSEY_MOUNTED_ROBOT_ACCESS_TABLE_ID,
        'DOSEY_MOUNTED_ROBOT_ACCESS_TABLE_ID',
      ),
      robotInstallationsTableId: required(
        environment.DOSEY_ROBOT_INSTALLATIONS_TABLE_ID,
        'DOSEY_ROBOT_INSTALLATIONS_TABLE_ID',
      ),
    }),
  );
  const rows = new AppwriteMedicationSyncRowsApi(tables, {
    databaseId,
    documentsTableId: required(
      environment.DOSEY_MEDICATION_SYNC_DOCUMENTS_TABLE_ID,
      'DOSEY_MEDICATION_SYNC_DOCUMENTS_TABLE_ID',
    ),
    eventsTableId: required(
      environment.DOSEY_MEDICATION_SYNC_EVENTS_TABLE_ID,
      'DOSEY_MEDICATION_SYNC_EVENTS_TABLE_ID',
    ),
    helpRequestsTableId: required(
      environment.DOSEY_MEDICATION_SYNC_HELP_REQUESTS_TABLE_ID,
      'DOSEY_MEDICATION_SYNC_HELP_REQUESTS_TABLE_ID',
    ),
    receiptsTableId: required(
      environment.DOSEY_MEDICATION_SYNC_RECEIPTS_TABLE_ID,
      'DOSEY_MEDICATION_SYNC_RECEIPTS_TABLE_ID',
    ),
    stateTableId: required(
      environment.DOSEY_MEDICATION_SYNC_STATE_TABLE_ID,
      'DOSEY_MEDICATION_SYNC_STATE_TABLE_ID',
    ),
    changesTableId: required(
      environment.DOSEY_MEDICATION_SYNC_CHANGES_TABLE_ID,
      'DOSEY_MEDICATION_SYNC_CHANGES_TABLE_ID',
    ),
  });
  const store = new TransactionalMedicationSyncStore(
    new AppwriteMedicationSyncPersistence(rows, (error) => {
      const message = error instanceof Error ? error.message : String(error);
      reportError(`Medication sync transaction rollback failed: ${message}`);
    }),
  );

  return {
    identity,
    parser,
    push: new MedicationSyncPushService(access, store, () => new Date()),
    pull: new MedicationSyncPullService(access, store),
  };
}

export function configuredHumanProviders(value: string | undefined): readonly string[] {
  if (value == null) return ['google'];
  const providers = [...new Set(value.split(',').map((provider) => provider.trim()).filter(Boolean))];
  if (providers.length === 0) {
    throw new Error('At least one human provider must be configured.');
  }
  for (const provider of providers) {
    if (provider !== 'google' && provider !== 'email') {
      throw new Error(`Unsupported human provider: ${provider}.`);
    }
  }
  return providers;
}

function required(value: string | undefined, name: string): string {
  if (value == null || value.trim().length === 0) {
    throw new Error(`Missing required function environment variable: ${name}.`);
  }
  return value.trim();
}
