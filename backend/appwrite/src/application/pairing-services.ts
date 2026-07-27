import {
  digestPairingCode,
  issuePairingCredential,
  type IssuedPairingCredential,
} from './pairing-credential.js';
import type {
  PairingClaimRecord,
  PairingClaimRejectionReason,
} from '../domain/pairing-claim.js';

export interface PairingCredentialStore {
  replaceActive(record: PairingClaimRecord): Promise<void>;
}

export interface PairingClaimStore {
  claimAtomically(input: {
    codeDigest: string;
    mountedDeviceAccountId: string;
    now: Date;
  }): Promise<
    | { status: 'accepted'; robotId: string }
    | { status: 'rejected'; reason: PairingClaimRejectionReason }
  >;
}

export interface RobotAccessDirectory {
  isOwner(input: { robotId: string; accountId: string }): Promise<boolean>;

  mountDevice(input: {
    robotId: string;
    mountedDeviceAccountId: string;
  }): Promise<void>;
}

export class RobotOwnerRequiredError extends Error {
  constructor() {
    super('Only the robot owner can create a pairing code.');
    this.name = 'RobotOwnerRequiredError';
  }
}

export class CreatePairingCodeApplicationService {
  constructor(
    private readonly dependencies: {
      store: PairingCredentialStore;
      robots: RobotAccessDirectory;
      secret: string;
      createId: () => string;
      now: () => Date;
      selectIndex?: (maximum: number) => number;
    },
  ) {}

  async create(input: {
    robotId: string;
    ownerAccountId: string;
  }): Promise<IssuedPairingCredential> {
    const owner = await this.dependencies.robots.isOwner({
      robotId: input.robotId,
      accountId: input.ownerAccountId,
    });
    if (!owner) throw new RobotOwnerRequiredError();

    const issuanceInput = {
      robotId: input.robotId,
      claimId: this.dependencies.createId(),
      secret: this.dependencies.secret,
      now: this.dependencies.now(),
    };
    const credential =
      this.dependencies.selectIndex == null
        ? issuePairingCredential(issuanceInput)
        : issuePairingCredential({
            ...issuanceInput,
            selectIndex: this.dependencies.selectIndex,
          });
    await this.dependencies.store.replaceActive(credential.record);
    return credential;
  }
}

export class ClaimRobotApplicationService {
  constructor(
    private readonly dependencies: {
      store: PairingClaimStore;
      robots: RobotAccessDirectory;
      secret: string;
      now: () => Date;
    },
  ) {}

  async claimRobot(input: {
    code: string;
    mountedDeviceAccountId: string;
  }): Promise<
    | { status: 'accepted'; robotId: string }
    | { status: 'rejected'; reason: PairingClaimRejectionReason }
  > {
    const result = await this.dependencies.store.claimAtomically({
      codeDigest: digestPairingCode(input.code, this.dependencies.secret),
      mountedDeviceAccountId: input.mountedDeviceAccountId,
      now: this.dependencies.now(),
    });
    if (result.status === 'rejected') return result;

    // A retry by the same device is intentional: a function may have consumed
    // the token before a transient Teams membership request failed.
    await this.dependencies.robots.mountDevice({
      robotId: result.robotId,
      mountedDeviceAccountId: input.mountedDeviceAccountId,
    });
    return result;
  }
}
