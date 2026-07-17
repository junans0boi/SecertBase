import jwt from 'jsonwebtoken';

const disabledRestPrefixes = new Map([
  ['/today', 'engagement'],
  ['/missions', 'missions'],
  ['/qa', 'qa'],
  ['/timeline', 'timeline'],
  ['/push', 'push'],
  ['/wish-tickets', 'wish_tickets'],
  ['/reports', 'reports'],
  ['/balance', 'balance'],
  ['/challenges', 'challenges'],
  ['/jukebox', 'jukebox'],
  ['/capsules', 'capsules'],
  ['/album', 'album'],
  ['/reflections', 'reflections'],
  ['/premium', 'premium'],
]);

// 공개된 게임 타입. 게임을 복구할 때는 여기에 추가하고
// disabledSocketPrefixes에서 해당 prefix를 제거한다 (epic #20).
export const PUBLIC_GAME_TYPES = ['yut', 'bomb', 'rps', 'zero', 'uno'];

const disabledSocketPrefixes = new Map([
  ['game:dice:', 'dice'],
  ['game:roulette:', 'roulette'],
  ['game:telepathy:', 'telepathy'],
  ['game:pirate:', 'pirate'],
  ['game:catch:', 'catch'],
  ['heart:', 'heart'],
]);

const disabledResponse = (feature) => ({
  ok: false,
  error: { code: 'FEATURE_DISABLED', feature },
});

const featureForRestPath = (requestPath) => {
  for (const [prefix, feature] of disabledRestPrefixes) {
    if (requestPath === prefix || requestPath.startsWith(`${prefix}/`)) return feature;
  }
  return null;
};

const featureForSocketPacket = ([event, payload]) => {
  for (const [prefix, feature] of disabledSocketPrefixes) {
    if (event.startsWith(prefix)) return feature;
  }

  if (event.startsWith('game:lobby:')) {
    const gameType = String(payload?.gameType ?? payload?.type ?? '');
    if (gameType && !PUBLIC_GAME_TYPES.includes(gameType)) return gameType;
  }
  if (event === 'game:restart:respond') {
    const gameType = String(payload?.gameType ?? '');
    if (gameType && !PUBLIC_GAME_TYPES.includes(gameType)) return gameType;
  }
  return null;
};

export const requireAuth = (secret) => (req, res, next) => {
  const match = (req.get('authorization') || '').match(/^Bearer\s+(.+)$/i);
  if (!match) {
    return res.status(401).json({
      ok: false,
      error: { code: 'AUTH_REQUIRED' },
    });
  }

  try {
    const payload = jwt.verify(match[1], secret);
    const userId = Number(payload.userId);
    if (!Number.isInteger(userId) || userId <= 0) throw new Error('invalid user');
    req.auth = {
      userId,
      userCode: typeof payload.userCode === 'string' ? payload.userCode : null,
    };
    next();
  } catch {
    return res.status(401).json({
      ok: false,
      error: { code: 'AUTH_INVALID' },
    });
  }
};

export const mvpRestFeatureGate = (featureSet) => (req, res, next) => {
  if (featureSet !== 'mvp') return next();
  const feature = featureForRestPath(req.path);
  if (!feature) return next();
  return res.status(403).json(disabledResponse(feature));
};

export const disabledFeature = (featureSet, feature) => (_, res, next) => {
  if (featureSet !== 'mvp') return next();
  return res.status(403).json(disabledResponse(feature));
};

export const installSocketFeatureGate = (socket, featureSet) => {
  if (featureSet !== 'mvp') return;
  socket.use((packet, next) => {
    const feature = featureForSocketPacket(packet);
    if (!feature) return next();

    const ack = packet.at(-1);
    const response = disabledResponse(feature);
    if (typeof ack === 'function') ack(response);
    else socket.emit('feature:error', response);
  });
};

export const installSocketAuthentication = (io, secret, resolveSession) => {
  io.use(async (socket, next) => {
    const authToken = socket.handshake.auth?.token;
    const header = socket.handshake.headers?.authorization;
    const token = authToken || (typeof header === 'string'
      ? header.match(/^Bearer\s+(.+)$/i)?.[1]
      : null);
    if (!token) return next(new Error('AUTH_REQUIRED'));
    try {
      const payload = jwt.verify(token, secret);
      const userId = Number(payload.userId);
      if (!Number.isInteger(userId) || userId <= 0) throw new Error('invalid user');
      const session = await resolveSession(userId);
      if (!session) return next(new Error('ACTIVE_COUPLE_REQUIRED'));
      Object.assign(socket.data, session);
      next();
    } catch (error) {
      if (error.message === 'ACTIVE_COUPLE_REQUIRED') return next(error);
      next(new Error('AUTH_INVALID'));
    }
  });
};
