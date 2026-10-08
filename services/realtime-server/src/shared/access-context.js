export class AccessContextError extends Error {
  constructor(code) {
    super(code);
    this.name = 'AccessContextError';
    this.code = code;
  }
}

export const getAuthenticatedActor = (req) => {
  const actor = req?.auth;
  const userId = Number(actor?.userId);
  if (!Number.isInteger(userId) || userId <= 0) {
    throw new AccessContextError('AUTH_REQUIRED');
  }

  const clientScopes = [
    req?.query?.user_id,
    req?.body?.user_id,
    req?.params?.user_id,
  ];
  for (const value of clientScopes) {
    if (value === undefined || value === null || value === '') continue;
    if (Number(value) !== userId) {
      throw new AccessContextError('CLIENT_SCOPE_OVERRIDE');
    }
  }

  return {
    userId,
    userCode: typeof actor.userCode === 'string' ? actor.userCode : null,
  };
};

export async function resolveActiveCouple(userId, queryFn) {
  const numericUserId = Number(userId);
  if (!Number.isInteger(numericUserId) || numericUserId <= 0) return null;
  const query = queryFn ?? (await import('../db.js')).query;
  const result = await query(
    `SELECT c.CoupleId, c.User1Id, c.User2Id, c.RoomCode,
            u.UserCode, COALESCE(u.Nickname, u.UserName, u.UserCode) AS Nickname
     FROM Couples c
     JOIN Users u ON u.UserId = ?
     WHERE c.Status = 'active' AND (c.User1Id = ? OR c.User2Id = ?)
     LIMIT 1`,
    [numericUserId, numericUserId, numericUserId],
  );
  return result?.rows?.[0] ?? null;
}
