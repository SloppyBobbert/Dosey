import { acceptHouseholdInvitationHandler } from '../functions/household-handlers.js';
import { createHouseholdRuntime } from '../runtime/household-runtime.js';

export default async function acceptHouseholdInvitation(
  context: Parameters<ReturnType<typeof acceptHouseholdInvitationHandler>>[0],
) {
  const runtime = createHouseholdRuntime(
    context.req.headers,
    process.env,
    context.error,
  );
  return acceptHouseholdInvitationHandler(
    runtime.acceptInvitation,
    runtime.identity,
  )(context);
}
