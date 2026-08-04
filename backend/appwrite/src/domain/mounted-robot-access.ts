export interface MountedRobotAccessRecord {
  readonly robotId: string;
  readonly mountedDeviceAccountId: string;
  readonly registeredPatientDeviceId?: string | null;
  readonly pairingClaimId: string;
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

export interface RobotInstallationRecord {
  readonly robotId: string;
  readonly displayName: string;
  readonly status: 'active' | 'provisioning';
}
