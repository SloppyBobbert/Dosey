import { Account, Client, ID, TablesDB, Teams } from 'node-appwrite';

import {
  AcceptHouseholdInvitationService,
  CreateHouseholdInvitationService,
  CreateRobotService,
  RemoveHouseholdMemberService,
} from '../application/household-services.js';
import {
  AppwriteHouseholdPersistence,
  AppwriteHouseholdRowsApi,
} from '../infrastructure/appwrite-household-persistence.js';
import {
  AppwriteHouseholdTeams,
  AppwriteHouseholdTeamsApi,
} from '../infrastructure/appwrite-household-teams.js';
import { TransactionalHouseholdRegistry } from '../infrastructure/transactional-household-registry.js';
import { AppwriteFunctionIdentityVerifier } from '../functions/function-identity.js';

export function createHouseholdRuntime(
  headers: Readonly<Record<string, string | undefined>>,
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
  const identity = new AppwriteFunctionIdentityVerifier({
    async getCurrentAccountId() {
      return (await currentAccount().get()).$id;
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
  });
  const rows = new AppwriteHouseholdRowsApi(new TablesDB(adminClient), {
    databaseId: required(environment.DOSEY_DATABASE_ID, 'DOSEY_DATABASE_ID'),
    robotInstallationsTableId: required(
      environment.DOSEY_ROBOT_INSTALLATIONS_TABLE_ID,
      'DOSEY_ROBOT_INSTALLATIONS_TABLE_ID',
    ),
    humanRobotLinksTableId: required(
      environment.DOSEY_HUMAN_ROBOT_LINKS_TABLE_ID,
      'DOSEY_HUMAN_ROBOT_LINKS_TABLE_ID',
    ),
    householdInvitationsTableId: required(
      environment.DOSEY_HOUSEHOLD_INVITATIONS_TABLE_ID,
      'DOSEY_HOUSEHOLD_INVITATIONS_TABLE_ID',
    ),
  });
  const registry = new TransactionalHouseholdRegistry(
    new AppwriteHouseholdPersistence(rows, (error) => {
      const message = error instanceof Error ? error.message : String(error);
      reportError(`Household transaction rollback failed: ${message}`);
    }),
  );
  const teams = new AppwriteHouseholdTeams(
    new AppwriteHouseholdTeamsApi(new Teams(adminClient)),
  );
  const secret = required(
    environment.DOSEY_HOUSEHOLD_INVITATION_HMAC_SECRET,
    'DOSEY_HOUSEHOLD_INVITATION_HMAC_SECRET',
  );
  const now = () => new Date();

  return {
    identity,
    createRobot: new CreateRobotService({
      registry,
      teams,
      createId: () => ID.unique(),
      now,
    }),
    createInvitation: new CreateHouseholdInvitationService({
      registry,
      secret,
      now,
    }),
    acceptInvitation: new AcceptHouseholdInvitationService({
      registry,
      teams,
      secret,
      now,
    }),
    removeMember: new RemoveHouseholdMemberService({ registry, teams, now }),
  };
}

function required(value: string | undefined, name: string): string {
  if (value == null || value.trim().length === 0) {
    throw new Error(`Missing required function environment variable: ${name}.`);
  }
  return value.trim();
}
