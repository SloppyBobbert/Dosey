export interface FunctionIdentityVerifier {
  verify(
    headers: Readonly<Record<string, string | undefined>>,
  ): Promise<string | null>;
}

export interface FunctionAccountApi {
  getCurrentAccountId(): Promise<string>;
}

export class AppwriteFunctionIdentityVerifier
  implements FunctionIdentityVerifier
{
  constructor(private readonly account: FunctionAccountApi) {}

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
}
