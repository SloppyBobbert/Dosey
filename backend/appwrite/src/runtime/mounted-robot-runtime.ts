import { Account, Client, TablesDB } from 'node-appwrite';

import { GetMountedRobotService } from '../application/mounted-robot-services.js';
import { AppwriteMountedRobotAccessReader } from '../infrastructure/appwrite-mounted-robot-access.js';
import { AppwriteFunctionIdentityVerifier } from '../functions/function-identity.js';

interface MountedRobotUserAccount {
  get(): Promise<{ readonly $id: string }>;
  getSession(input: { readonly sessionId: string }): Promise<{
    readonly userId: string;
    readonly provider: string;
  }>;
}

export function createMountedRobotRuntime(
  headers: Readonly<Record<string, string | undefined>>,
  environment: Readonly<Record<string, string | undefined>> = process.env,
) {
  const endpoint = required(
    environment.APPWRITE_FUNCTION_API_ENDPOINT ?? environment.APPWRITE_ENDPOINT,
    'APPWRITE_FUNCTION_API_ENDPOINT',
  );
  const projectId = required(
    environment.APPWRITE_FUNCTION_PROJECT_ID ?? environment.APPWRITE_PROJECT_ID,
    'APPWRITE_FUNCTION_PROJECT_ID',
  );
  const userJwt = headers['x-appwrite-user-jwt'];
  const identity = new AppwriteFunctionIdentityVerifier({
    getCurrentAccountId: async () => {
      if (!userJwt) throw new Error('Authenticated user JWT is required.');
      return (await createUserAccount(endpoint, projectId, userJwt).get()).$id;
    },
    getCurrentAnonymousAccount: async () => {
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
  const reader = new AppwriteMountedRobotAccessReader(new TablesDB(
    new Client()
      .setEndpoint(endpoint)
      .setProject(projectId)
      .setKey(required(headers['x-appwrite-key'], 'x-appwrite-key')),
  ), {
    databaseId: required(environment.DOSEY_DATABASE_ID, 'DOSEY_DATABASE_ID'),
    mountedRobotAccessTableId: required(
      environment.DOSEY_MOUNTED_ROBOT_ACCESS_TABLE_ID,
      'DOSEY_MOUNTED_ROBOT_ACCESS_TABLE_ID',
    ),
    robotInstallationsTableId: required(
      environment.DOSEY_ROBOT_INSTALLATIONS_TABLE_ID,
      'DOSEY_ROBOT_INSTALLATIONS_TABLE_ID',
    ),
  });
  return { identity, service: new GetMountedRobotService(reader) };
}

function createUserAccount(
  endpoint: string,
  projectId: string,
  userJwt: string,
): MountedRobotUserAccount {
  return new Account(new Client().setEndpoint(endpoint).setProject(projectId).setJWT(userJwt));
}

function required(value: string | undefined, name: string): string {
  if (value == null || value.trim().length === 0) {
    throw new Error(`Missing required function environment variable: ${name}.`);
  }
  return value.trim();
}
