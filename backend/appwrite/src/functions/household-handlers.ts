import {
  HouseholdFailure,
  type HouseholdFailureCode,
} from '../application/household-services.js';
import type { HouseholdSnapshot } from '../domain/household.js';
import { normalizeHouseholdInvitationCode } from '../domain/household-invitation.js';
import type { FunctionContext } from './claim-robot.js';
import type { HumanFunctionIdentityVerifier } from './function-identity.js';

interface CreateRobotService {
  create(input: { accountId: string; displayName: string }): Promise<HouseholdSnapshot>;
}

interface CreateInvitationService {
  create(input: {
    robotId: string;
    ownerAccountId: string;
    invitedEmail: string;
  }): Promise<{ code: string; expiresAt: Date }>;
}

interface AcceptInvitationService {
  accept(input: {
    accountId: string;
    email: string;
    code: string;
  }): Promise<HouseholdSnapshot>;
}

interface RemoveMemberService {
  remove(input: {
    robotId: string;
    actorAccountId: string;
    targetAccountId: string;
  }): Promise<HouseholdSnapshot | null>;
}

export function createRobotHandler(
  service: CreateRobotService,
  identity: HumanFunctionIdentityVerifier,
) {
  return householdHandler(identity, async (context, human) => {
    const displayName = readRequiredString(context.req.bodyJson, 'displayName');
    if (displayName == null) return invalidRequest(context, 'invalid_display_name');
    const household = await service.create({
      accountId: human.accountId,
      displayName,
    });
    return context.res.json(household);
  });
}

export function createHouseholdInvitationHandler(
  service: CreateInvitationService,
  identity: HumanFunctionIdentityVerifier,
) {
  return householdHandler(identity, async (context, human) => {
    const robotId = readRequiredString(context.req.bodyJson, 'robotId');
    const invitedEmail = readRequiredString(context.req.bodyJson, 'email');
    if (robotId == null || invitedEmail == null || !invitedEmail.includes('@')) {
      return invalidRequest(context, 'invalid_invitation_request');
    }
    const credential = await service.create({
      robotId,
      ownerAccountId: human.accountId,
      invitedEmail,
    });
    return context.res.json({
      code: credential.code,
      expiresAt: credential.expiresAt.toISOString(),
    });
  });
}

export function acceptHouseholdInvitationHandler(
  service: AcceptInvitationService,
  identity: HumanFunctionIdentityVerifier,
) {
  return householdHandler(identity, async (context, human) => {
    const code = readRequiredString(context.req.bodyJson, 'code');
    if (code == null) return invalidRequest(context, 'invalid_invitation');
    try {
      normalizeHouseholdInvitationCode(code);
    } catch (_) {
      return invalidRequest(context, 'invalid_invitation');
    }
    const household = await service.accept({
      accountId: human.accountId,
      email: human.email,
      code,
    });
    return context.res.json(household);
  });
}

export function removeHouseholdMemberHandler(
  service: RemoveMemberService,
  identity: HumanFunctionIdentityVerifier,
) {
  return householdHandler(identity, async (context, human) => {
    const robotId = readRequiredString(context.req.bodyJson, 'robotId');
    const requestedTarget = readOptionalString(context.req.bodyJson, 'accountId');
    if (robotId == null || requestedTarget === undefined) {
      return invalidRequest(context, 'invalid_removal_request');
    }
    const household = await service.remove({
      robotId,
      actorAccountId: human.accountId,
      targetAccountId: requestedTarget ?? human.accountId,
    });
    return context.res.json(household ?? { removed: true });
  });
}

function householdHandler(
  identity: HumanFunctionIdentityVerifier,
  operation: (
    context: FunctionContext,
    human: { accountId: string; email: string },
  ) => Promise<unknown>,
) {
  return async (context: FunctionContext) => {
    if (context.req.method !== 'POST') {
      return context.res.json({ error: 'method_not_allowed' }, 405);
    }
    const human = await identity.verifyHuman(context.req.headers);
    if (human == null) {
      return context.res.json({ error: 'authentication_required' }, 401);
    }
    try {
      return await operation(context, human);
    } catch (error) {
      if (error instanceof HouseholdFailure) {
        return context.res.json(
          { error: error.code },
          householdFailureStatus[error.code],
        );
      }
      throw error;
    }
  };
}

const householdFailureStatus: Record<HouseholdFailureCode, number> = {
  already_linked: 409,
  household_full: 409,
  invalid_invitation: 400,
  invitation_expired: 410,
  email_mismatch: 403,
  owner_required: 403,
  owner_cannot_leave: 409,
  member_not_found: 404,
};

function invalidRequest(context: FunctionContext, error: string) {
  return context.res.json({ error }, 400);
}

function readRequiredString(body: unknown, field: string): string | null {
  if (body == null || typeof body !== 'object' || !(field in body)) return null;
  const value = (body as Record<string, unknown>)[field];
  return typeof value === 'string' && value.trim().length > 0
    ? value.trim()
    : null;
}

function readOptionalString(body: unknown, field: string): string | null | undefined {
  if (body == null || typeof body !== 'object' || !(field in body)) return null;
  const value = (body as Record<string, unknown>)[field];
  if (value == null) return null;
  return typeof value === 'string' && value.trim().length > 0
    ? value.trim()
    : undefined;
}
