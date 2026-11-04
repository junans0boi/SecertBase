import jwt from 'jsonwebtoken';
import {
  disabledResponse,
  featureForRestPath,
  featureForSocketPacket,
  isRestEnabled,
} from './shared/feature-registry.js';
import {
  AccessContextError,
  getAuthenticatedActor,
} from './shared/access-context.js';

export { PUBLIC_GAME_TYPES } from './shared/feature-registry.js';

// 탈퇴했거나 존재하지 않는 계정의 토큰을 거부하기 위한 계정 활성 확인기.
// 결과는 짧은 시간 캐시한다. DB 오류는 요청을 막지 않고(fail-open) 로그만 남긴다.
export const createAccountActiveChecker = ({
  queryFn,
  ttlMs = 30_000,
  now = Date.now,
  log = console,
  maxEntries = 5000,
} = {}) => {
  if (typeof queryFn !== 'function') throw new TypeError('queryFn is required');
  const cache = new Map();
  const check = async (userId) => {
    const t = now();
    const hit = cache.get(userId);
    if (hit && hit.expiresAt > t) return hit.active;
    try {
      const result = await queryFn('SELECT IsDeleted FROM Users WHERE UserId = ? LIMIT 1', [userId]);
      const row = result?.rows?.[0];
      const active = Boolean(row) && !row.IsDeleted;
      if (cache.size >= maxEntries) cache.delete(cache.keys().next().value);
      cache.set(userId, { active, expiresAt: t + ttlMs });
      return active;
    } catch (error) {
      log.error('[Auth] account status check failed', error?.message);
      return true;
    }
  };
  check.invalidate = (userId) => cache.delete(Number(userId));
  return check;
};

export const requireAuth = (secret, { isAccountActive } = {}) => (req, res, next) => {
  const match = (req.get('authorization') || '').match(/^Bearer\s+(.+)$/i);
  if (!match) {
    return res.status(401).json({
      ok: false,
      error: { code: 'AUTH_REQUIRED' },
    });
  }

  const reject = () => res.status(401).json({
    ok: false,
    error: { code: 'AUTH_INVALID' },
  });

  try {
    const payload = jwt.verify(match[1], secret);
    const userId = Number(payload.userId);
    if (!Number.isInteger(userId) || userId <= 0) throw new Error('invalid user');
    req.auth = {
      userId,
      userCode: typeof payload.userCode === 'string' ? payload.userCode : null,
    };
    try {
      getAuthenticatedActor(req);
    } catch (error) {
      if (error instanceof AccessContextError) {
        return res.status(403).json({
          ok: false,
          error: { code: error.code },
        });
      }
      throw error;
    }
    if (typeof isAccountActive !== 'function') return next();
    return Promise.resolve(isAccountActive(userId)).then(
      (active) => (active ? next() : reject()),
      () => next(),
    );
  } catch {
    return reject();
  }
};

export const mvpRestFeatureGate = (featureSet) => (req, res, next) => {
  const feature = featureForRestPath(req.path);
  if (isRestEnabled(req.path, featureSet) || !feature) return next();
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
