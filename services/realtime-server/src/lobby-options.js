// 로비 옵션: 방장이 로비에서 고르고 상대도 실시간으로 보는 게임별 설정.
// 서버가 로비에 저장했다가 게임을 만들 때 이 값만 쓴다(판돈과 같은 원칙,
// 생성 이벤트 payload의 값은 신뢰하지 않는다). 클라이언트 목록은
// apps/secret_base_app/lib/screens/arcade/lobby_options.dart와 같아야 한다.

export const LOBBY_OPTIONS = Object.freeze({
  penalty: Object.freeze({
    cells: Object.freeze({ values: Object.freeze([3, 6]), default: 3 }),
  }),
  pirate: Object.freeze({
    holes: Object.freeze({ values: Object.freeze([6, 8, 12]), default: 8 }),
  }),
  uno: Object.freeze({
    mode: Object.freeze({ values: Object.freeze(["go_wild", "classic"]), default: "go_wild" }),
  }),
});

const specFor = (gameType) => LOBBY_OPTIONS[String(gameType).startsWith("uno") ? "uno" : gameType];

/** 게임의 기본 옵션. 옵션이 없는 게임은 빈 객체. */
export function defaultLobbyOptions(gameType) {
  const spec = specFor(gameType);
  if (!spec) return {};
  return Object.fromEntries(Object.entries(spec).map(([key, def]) => [key, def.default]));
}

/** 이 게임에서 key=value가 허용되는지. */
export function isValidLobbyOption(gameType, key, value) {
  const def = specFor(gameType)?.[key];
  return Boolean(def) && def.values.includes(value);
}

/** 저장된(또는 오래된) 옵션을 허용된 값만 남기고 빠진 값은 기본값으로 채운다. */
export function normalizeLobbyOptions(gameType, raw) {
  const options = defaultLobbyOptions(gameType);
  if (!raw || typeof raw !== "object") return options;
  for (const key of Object.keys(options)) {
    if (isValidLobbyOption(gameType, key, raw[key])) options[key] = raw[key];
  }
  return options;
}
