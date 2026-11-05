// 같은 방에서 이어지는 판의 전적(시리즈). 재대결을 해도 이어지고 6시간 동안 유지된다.
export const SERIES_TTL_SEC = 6 * 3600;
const seriesKey = (roomCode, gameType) => `series:${roomCode}:${gameType}`;

export function emptySeries(players = []) {
  return { wins: Object.fromEntries(players.map((p) => [p, 0])), draws: 0, games: 0 };
}

export function applySeriesResult(series, players, winner) {
  const next = {
    wins: { ...emptySeries(players).wins, ...(series?.wins ?? {}) },
    draws: series?.draws ?? 0,
    games: (series?.games ?? 0) + 1,
  };
  if (winner && winner !== "draw" && Object.prototype.hasOwnProperty.call(next.wins, winner)) next.wins[winner] += 1;
  else next.draws += 1;
  return next;
}

export function createSeriesStore(redis) {
  return {
    async get(roomCode, gameType, players = []) {
      const raw = await redis.get(seriesKey(roomCode, gameType));
      if (!raw) return emptySeries(players);
      try {
        const parsed = JSON.parse(raw);
        return { ...emptySeries(players), ...parsed, wins: { ...emptySeries(players).wins, ...(parsed.wins ?? {}) } };
      } catch {
        return emptySeries(players);
      }
    },
    /** 한 판의 결과를 더하고 갱신된 전적을 돌려준다. winner가 null/'draw'면 무승부. */
    async record(roomCode, gameType, players, winner) {
      const next = applySeriesResult(await this.get(roomCode, gameType, players), players, winner);
      await redis.set(seriesKey(roomCode, gameType), JSON.stringify(next), "EX", SERIES_TTL_SEC);
      return next;
    },
  };
}
