import { removeHouseholdMemberHandler } from '../functions/household-handlers.js';
import { createHouseholdRuntime } from '../runtime/household-runtime.js';

export default async function removeHouseholdMember(
  context: Parameters<ReturnType<typeof removeHouseholdMemberHandler>>[0],
) {
  const runtime = createHouseholdRuntime(
    context.req.headers,
    process.env,
    context.error,
  );
  return removeHouseholdMemberHandler(runtime.removeMember, runtime.identity)(
    context,
  );
}
