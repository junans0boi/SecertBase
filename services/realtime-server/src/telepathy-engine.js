// The response deadline and storage lifetime serve different purposes: expiry
// must reveal the available answers without discarding a slow partner's round.
export const TELEPATHY_RESPONSE_TIMEOUT_MS = 60_000;
export const TELEPATHY_SESSION_TTL_SEC = 3600;

export function telepathyResult(session, now = Date.now()) {
  const choices = { ...session.choices };
  const values = Object.values(choices);
  const success = values.length === 2 && values[0] === values[1];
  return {
    sessionId: session.id,
    choices,
    success,
    selected: success ? values[0] : null,
    at: now,
  };
}
