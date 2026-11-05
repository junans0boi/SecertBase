// 공용 리액션: 게임 중 이모지 한 개를 상대에게 보낸다(게임 2.0, 티켓 05).
export const REACTION_EMOJIS = Object.freeze(["😏", "😅", "😱", "🤞", "😭", "😎"]);
export const REACTION_COOLDOWN_MS = 1500;

export function createReactionLimiter(now = Date.now) {
  const last = new Map();
  return (userId) => {
    const t = now();
    const prev = last.get(userId) ?? -Infinity;
    if (t - prev < REACTION_COOLDOWN_MS) return false;
    last.set(userId, t);
    if (last.size > 5000) last.clear();
    return true;
  };
}
