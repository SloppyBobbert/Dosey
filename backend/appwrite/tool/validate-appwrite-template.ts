import { readFileSync } from 'node:fs';

type Column = Record<string, unknown>;
const c = (key: string, type: string, extra: Record<string, unknown> = {}): Column => ({ key, type, ...extra, required: true, array: false, default: null });
const optional = (column: Column): Column => ({ ...column, required: false });
const v = (key: string, size: number) => c(key, 'varchar', { size });
const i = (key: string, min: number, max: number) => c(key, 'integer', { min, max });
const d = (key: string) => c(key, 'datetime');
const b = (key: string) => c(key, 'boolean');
const x = (key: string, type: string, columns: string[], orders: string[]) => ({ key, type, columns, orders });
const t = ($id: string, name: string, columns: Column[], indexes: object[]) => ({ $id, name, $permissions: [], rowSecurity: false, enabled: true, columns, indexes });

export const canonicalTemplate = {
  database: { name: 'Dosey pairing and household' },
  tables: [
    t('pairing_claims', 'Pairing claims', [v('robotId',128),v('codeDigest',128),d('expiresAt'),optional(d('consumedAt')),optional(v('mountedDeviceAccountId',128)),i('failedAttempts',0,9007199254740991),b('active')], [x('active_code_digest','key',['active','codeDigest'],['ASC','ASC']),x('robot_active','key',['robotId','active'],['ASC','ASC'])]),
    t('pairing_attempts', 'Pairing attempts', [v('deviceAccountId',128),i('failedAttempts',0,9007199254740991),optional(d('blockedUntil'))], []),
    t('mounted_robot_access', 'Mounted robot access', [v('robotId',128),v('mountedDeviceAccountId',128),optional(v('registeredPatientDeviceId',128)),v('pairingClaimId',128),d('createdAt'),d('updatedAt')], [x('mounted_device','key',['mountedDeviceAccountId'],['ASC'])]),
    t('robot_installations', 'Robot installations', [v('ownerAccountId',128),v('displayName',128),i('humanCount',0,7),v('status',16),d('createdAt'),d('updatedAt')], []),
    t('human_robot_links', 'Human robot links', [v('robotId',128),v('role',16),optional(v('membershipId',128)),v('status',16),d('createdAt'),d('updatedAt')], []),
    t('household_invitations', 'Household invitations', [v('robotId',128),v('invitedEmail',320),v('codeDigest',128),d('expiresAt'),v('createdByAccountId',128),optional(d('consumedAt')),optional(v('acceptedAccountId',128)),d('createdAt'),d('updatedAt')], [x('code_digest','key',['codeDigest'],['ASC'])]),
  ],
};

export function validateTemplate(value: unknown): boolean {
  return typeof value === 'object' && value !== null && JSON.stringify(value) === JSON.stringify(canonicalTemplate);
}

function main(path: string | URL = new URL('../appwrite.pairing-household.template.json', import.meta.url)): boolean {
  try { return validateTemplate(JSON.parse(readFileSync(path, 'utf8'))); } catch { return false; }
}

if (process.argv[1] === new URL(import.meta.url).pathname) {
  const valid = main(process.argv[2] ?? new URL('../appwrite.pairing-household.template.json', import.meta.url));
  process.stdout.write(valid ? 'APPWRITE_TEMPLATE_VALIDATION status=pass\n' : 'APPWRITE_TEMPLATE_VALIDATION status=fail reason=TEMPLATE_INVALID\n');
  if (!valid) process.exitCode = 1;
}
