// 외부 의존성 없는 고정 윈도우 요청 제한기.
// keyFn이 null/undefined를 반환하면 해당 요청은 제한하지 않는다.
export const createRateLimiter = ({
  windowMs,
  max,
  keyFn,
  enabled = true,
  now = Date.now,
  maxKeys = 10000,
} = {}) => {
  if (!Number.isFinite(windowMs) || windowMs <= 0) throw new TypeError('windowMs must be positive');
  if (!Number.isInteger(max) || max <= 0) throw new TypeError('max must be a positive integer');
  if (typeof keyFn !== 'function') throw new TypeError('keyFn is required');
  const buckets = new Map();

  const prune = (t) => {
    for (const [key, bucket] of buckets) {
      if (bucket.resetAt <= t) buckets.delete(key);
    }
    // 만료되지 않은 항목이 너무 많으면 가장 오래된 것부터 버린다.
    while (buckets.size > maxKeys) buckets.delete(buckets.keys().next().value);
  };

  return (req, res, next) => {
    if (!enabled) return next();
    const key = keyFn(req);
    if (key == null) return next();
    const t = now();
    let bucket = buckets.get(key);
    if (!bucket || bucket.resetAt <= t) {
      bucket = { count: 0, resetAt: t + windowMs };
      buckets.set(key, bucket);
      if (buckets.size > maxKeys) prune(t);
    }
    bucket.count += 1;
    if (bucket.count > max) {
      res.set('Retry-After', String(Math.max(1, Math.ceil((bucket.resetAt - t) / 1000))));
      return res.status(429).json({ ok: false, reason: 'rate_limited' });
    }
    return next();
  };
};

const LOOPBACK = new Set(['127.0.0.1', '::1', '::ffff:127.0.0.1']);

// 프록시가 클라이언트 IP를 넘기지 않아 모두 루프백으로 보이면 IP 기준 제한은 건너뛴다
// (그렇지 않으면 모든 사용자가 하나의 버킷을 공유해 서로를 차단한다).
export const clientIpKey = (prefix) => (req) => {
  const ip = req.ip;
  if (!ip || LOOPBACK.has(ip)) return null;
  return `${prefix}:ip:${ip}`;
};

export const emailKey = (prefix) => (req) => {
  const email = String(req.body?.email ?? '').trim().toLowerCase();
  return email ? `${prefix}:email:${email}` : null;
};
