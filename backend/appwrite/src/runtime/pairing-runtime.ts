import { Account, Client, ID, TablesDB, Teams } from 'node-appwrite';

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
import { AppwriteFunctionIdentityVerifier } from '../functions/function-identity.js';

interface PairingUserAccount {
  get(): Promise<{ readonly $id: string }>;
  getSession(input: { readonly sessionId: string }): Promise<{
    readonly userId: string;
    readonly provider: string;
  }>;
}

export function createPairingRuntime(
  headers: Readonly<Record<string, string | undefined>>,
  environment = process.env,
  reportError: (message: string) => void = () => {},
  createUserAccount: (
    endpoint: string,
    projectId: string,
    userJwt: string,
  ) => PairingUserAccount = (endpoint, projectId, userJwt) =>
    new Account(new Client().setEndpoint(endpoint).setProject(projectId).setJWT(userJwt)),
  requireMountedRobotAccess = true,
) {
  const endpoint = required(
    environment.APPWRITE_FUNCTION_API_ENDPOINT ?? environment.APPWRITE_ENDPOINT,
    'APPWRITE_FUNCTION_API_ENDPOINT',
  );
  const projectId = required(
    environment.APPWRITE_FUNCTION_PROJECT_ID ?? environment.APPWRITE_PROJECT_ID,
    'APPWRITE_FUNCTION_PROJECT_ID',
  );
  const client = new Client()
    .setEndpoint(
      endpoint,
    )
    .setProject(projectId)
    .setKey(required(headers['x-appwrite-key'], 'x-appwrite-key'));

  const userJwt = headers['x-appwrite-user-jwt'];
  const identity = new AppwriteFunctionIdentityVerifier({
    async getCurrentAccountId() {
      if (!userJwt) throw new Error('Authenticated user JWT is required.');
      const user = await createUserAccount(endpoint, projectId, userJwt).get();
      return user.$id;
    },
    async getCurrentAnonymousAccount() {
      if (!userJwt) throw new Error('Authenticated user JWT is required.');
      const account = createUserAccount(endpoint, projectId, userJwt);
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
  });

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
    ...(requireMountedRobotAccess
      ? {
          mountedRobotAccessTableId: required(
            environment.DOSEY_MOUNTED_ROBOT_ACCESS_TABLE_ID,
            'DOSEY_MOUNTED_ROBOT_ACCESS_TABLE_ID',
          ),
        }
      : {}),
  });
  const store = new TransactionalPairingStore(
    new AppwritePairingPersistence(tables, () => {
      reportError('Pairing transaction rollback failed.');
    }),
  );
  const robots = new AppwriteRobotAccessDirectory(
    new AppwriteRobotTeamsApi(new Teams(client)),
  );
  const secret = required(environment.DOSEY_PAIRING_HMAC_SECRET, 'DOSEY_PAIRING_HMAC_SECRET');

  return {
    identity,
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
