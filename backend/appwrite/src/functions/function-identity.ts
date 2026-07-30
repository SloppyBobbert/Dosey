export interface FunctionIdentityVerifier {
  verify(
    headers: Readonly<Record<string, string | undefined>>,
  ): Promise<string | null>;
}

export type AnonymousIdentityVerification =
  | string
  | { readonly reason: 'provider' }
  | null;

export interface AnonymousFunctionIdentityVerifier {
  verifyAnonymous(
    headers: Readonly<Record<string, string | undefined>>,
  ): Promise<AnonymousIdentityVerification>;
}

export interface HumanFunctionIdentity {
  readonly accountId: string;
  readonly email: string;
}

export interface HumanFunctionIdentityVerifier {
  verifyHuman(
    headers: Readonly<Record<string, string | undefined>>,
  ): Promise<HumanFunctionIdentity | null>;
}

export interface FunctionAccountApi {
  getCurrentAccountId(): Promise<string>;
  getCurrentAnonymousAccount?(): Promise<{
    readonly accountId: string;
    readonly sessionUserId: string;
    readonly provider: string;
  }>;
  getCurrentHumanAccount?(): Promise<{
    readonly id: string;
    readonly email: string;
    readonly emailVerified: boolean;
    readonly provider: string;
  }>;
}

export class AppwriteFunctionIdentityVerifier
  implements
    FunctionIdentityVerifier,
    AnonymousFunctionIdentityVerifier,
    HumanFunctionIdentityVerifier
{
  private readonly humanProviders: ReadonlySet<string>;

  constructor(
    private readonly account: FunctionAccountApi,
    humanProviders: readonly string[] = ['google'],
  ) {
    this.humanProviders = new Set(humanProviders);
  }

  async verify(
    headers: Readonly<Record<string, string | undefined>>,
  ): Promise<string | null> {
    const claimedId = headers['x-appwrite-user-id'];
    const jwt = headers['x-appwrite-user-jwt'];
    if (!claimedId || !jwt) return null;

    try {
      const authenticatedId = await this.account.getCurrentAccountId();
      return authenticatedId === claimedId ? authenticatedId : null;
    } catch (_) {
      return null;
    }
  }

  async verifyAnonymous(
    headers: Readonly<Record<string, string | undefined>>,
  ): Promise<AnonymousIdentityVerification> {
    const claimedId = headers['x-appwrite-user-id'];
    const jwt = headers['x-appwrite-user-jwt'];
    if (!claimedId || !jwt || this.account.getCurrentAnonymousAccount == null) {
      return null;
    }

    try {
      const account = await this.account.getCurrentAnonymousAccount();
      if (account.accountId !== claimedId || account.sessionUserId !== claimedId) {
        return null;
      }
      return account.provider === 'anonymous' ? claimedId : { reason: 'provider' };
    } catch (_) {
      return null;
    }
  }

  async verifyHuman(
    headers: Readonly<Record<string, string | undefined>>,
  ): Promise<HumanFunctionIdentity | null> {
    const claimedId = headers['x-appwrite-user-id'];
    const jwt = headers['x-appwrite-user-jwt'];
    if (!claimedId || !jwt || this.account.getCurrentHumanAccount == null) {
      return null;
    }

    try {
      const account = await this.account.getCurrentHumanAccount();
      const email = account.email.trim().toLowerCase();
      if (
        account.id !== claimedId ||
        !this.humanProviders.has(account.provider) ||
        !account.emailVerified ||
        email.length === 0
      ) {
        return null;
      }
      return { accountId: account.id, email };
    } catch (_) {
      return null;
    }
  }
}
