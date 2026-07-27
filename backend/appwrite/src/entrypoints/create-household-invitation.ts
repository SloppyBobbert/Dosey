import { createHouseholdInvitationHandler } from '../functions/household-handlers.js';
import { createHouseholdRuntime } from '../runtime/household-runtime.js';

export default async function createHouseholdInvitation(
  context: Parameters<ReturnType<typeof createHouseholdInvitationHandler>>[0],
) {
  const runtime = createHouseholdRuntime(
    context.req.headers,
    process.env,
    context.error,
  );
  return createHouseholdInvitationHandler(
    runtime.createInvitation,
    runtime.identity,
  )(context);
}
