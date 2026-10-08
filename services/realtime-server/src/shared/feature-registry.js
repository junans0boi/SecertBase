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

// This is the compatibility catalog already used by the Play area. The
// registry is the single server authority; Flutter's catalog is presentation
// only. Removing a game from public use is now a one-file policy change.
export const PUBLIC_GAME_TYPES = Object.freeze([
  'yut',
  'marble',
  'rps',
  'zero',
  'uno',
  'dice',
  'telepathy',
  'pirate',
  'catch',
  'blackjack',
  'oldmaid',
  'penalty',
  'bowling',
  'tank',
  'gostop',
]);

const disabledSocketPrefixes = new Map([
  ['heart:', 'heart'],
]);

export const disabledResponse = (feature) => ({
  ok: false,
  error: { code: 'FEATURE_DISABLED', feature },
});

export const featureForRestPath = (requestPath) => {
  const path = String(requestPath ?? '').replace(/^\/api(?=\/|$)/, '') || '/';
  for (const [prefix, feature] of disabledRestPrefixes) {
    if (path === prefix || path.startsWith(`${prefix}/`)) return feature;
  }
  return null;
};

export const isRestEnabled = (requestPath, featureSet = 'mvp') =>
  featureSet !== 'mvp' || featureForRestPath(requestPath) == null;

export const isGameEnabled = (gameType, featureSet = 'mvp') =>
  featureSet !== 'mvp' || PUBLIC_GAME_TYPES.includes(String(gameType ?? ''));

export const featureForSocketPacket = ([event, payload] = []) => {
  const eventName = String(event ?? '');
  for (const [prefix, feature] of disabledSocketPrefixes) {
    if (eventName.startsWith(prefix)) return feature;
  }

  if (eventName.startsWith('game:lobby:')) {
    const gameType = String(payload?.gameType ?? payload?.type ?? '');
    if (gameType && !isGameEnabled(gameType, 'mvp')) return gameType;
  }
  if (eventName.startsWith('game:session:')) {
    const gameType = String(payload?.gameType ?? '');
    if (gameType && !isGameEnabled(gameType, 'mvp')) return gameType;
  }
  if (eventName === 'game:restart:respond') {
    const gameType = String(payload?.gameType ?? '');
    if (gameType && !isGameEnabled(gameType, 'mvp')) return gameType;
  }
  return null;
};
