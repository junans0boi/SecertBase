// 도둑잡기(Old Maid) 2.0 엔진 — 순수 함수. 무작위는 `random`으로 주입한다.
//
// 규칙(바꾸지 않음): 52장 + 조커 1장을 번갈아 나눠(27/26장) 각자 같은 숫자 짝을 버린다.
// 번갈아 상대 손패에서 한 장을 뽑고, 짝이 맞으면 버린다. 마지막에 조커를 든 사람이 진다.
//
// 상태 모양:
//   { gameId, status: 'playing'|'finished', players: [p1, p2], hands: { id: [card] },
//     turn, firstTurn, discards: [rank], log: [{by, paired, rank|null, at}], drawCount,
//     timeouts: { id: n }, result: { winner, loser, reason } | null }
// 카드: { id, rank, suit, isJoker }. 상대 손패는 위치 별칭(slot-N)으로만 내보낸다.

export const SUITS = ['♠', '♥', '♦', '♣'];
export const RANKS = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
export const LOG_LIMIT = 6;

export function shuffle(list, random = Math.random) {
  const out = [...list];
  for (let i = out.length - 1; i > 0; i--) {
    const j = Math.floor(random() * (i + 1));
    [out[i], out[j]] = [out[j], out[i]];
  }
  return out;
}

export function createDeck(random = Math.random) {
  const deck = [];
  let n = 1;
  for (const suit of SUITS) {
    for (const rank of RANKS) deck.push({ id: `card_${n++}`, rank, suit, isJoker: false });
  }
  deck.push({ id: 'card_joker', rank: 'JOKER', suit: '🃏', isJoker: true });
  return shuffle(deck, random);
}

/** 손패에서 같은 숫자 짝을 모두 버린다 → { hand, pairedRanks }. 조커는 짝이 없다. */
export function removePairs(hand) {
  const byRank = new Map();
  for (const card of hand) {
    if (card.isJoker) continue;
    if (!byRank.has(card.rank)) byRank.set(card.rank, []);
    byRank.get(card.rank).push(card);
  }
  const removed = new Set();
  const pairedRanks = [];
  for (const [rank, cards] of byRank) {
    for (let i = 0; i + 1 < cards.length; i += 2) {
      removed.add(cards[i].id);
      removed.add(cards[i + 1].id);
      pairedRanks.push(rank);
    }
  }
  return { hand: hand.filter((c) => !removed.has(c.id)), pairedRanks };
}

export function opponentOf(game, playerId) {
  return game.players.find((p) => p !== playerId) ?? null;
}

/** 남은 카드가 조커 한 장뿐이면 그 카드를 든 사람이 진다. */
export function checkEnd(game) {
  if (game.status !== 'playing') return game;
  const [a, b] = game.players;
  const total = game.hands[a].length + game.hands[b].length;
  if (total !== 1) return game;
  const loser = game.hands[a].length === 1 ? a : b;
  if (!game.hands[loser][0]?.isJoker) return game;
  return {
    ...game,
    status: 'finished',
    turn: null,
    result: { winner: opponentOf(game, loser), loser, reason: 'joker' },
  };
}

/**
 * 새 판. [firstTurn]을 주지 않으면 선공은 무작위.
 * players는 커플 순서(User1, User2) — 분배는 p1이 27장(조커 포함 가능)부터 받는다.
 */
export function initGame(p1, p2, { random = Math.random, gameId = null, firstTurn = null } = {}) {
  const deck = createDeck(random);
  const raw = { [p1]: [], [p2]: [] };
  deck.forEach((card, i) => raw[i % 2 === 0 ? p1 : p2].push(card));
  const discards = [];
  const hands = {};
  for (const id of [p1, p2]) {
    const { hand, pairedRanks } = removePairs(raw[id]);
    hands[id] = shuffle(hand, random);
    discards.push(...pairedRanks);
  }
  const turn = firstTurn === p1 || firstTurn === p2 ? firstTurn : random() < 0.5 ? p1 : p2;
  return checkEnd({
    gameId,
    status: 'playing',
    players: [p1, p2],
    hands,
    turn,
    firstTurn: turn,
    discards,
    log: [],
    drawCount: 0,
    timeouts: { [p1]: 0, [p2]: 0 },
    result: null,
  });
}

/** `slot-N` 별칭이나 숫자를 손패 위치로. 실제 카드 id(card_…)는 받지 않는다. */
export function parseSlot(value) {
  if (Number.isInteger(value)) return value;
  const m = /^slot-(\d{1,3})$/.exec(String(value ?? ''));
  return m ? Number(m[1]) : null;
}

/**
 * [playerId]가 상대 손패 [slot]번째 카드를 뽑는다.
 * → { game, draw } | { error }. draw는 비공개 정보를 포함하므로 사용자별로 걸러 보낸다.
 */
export function drawAt(game, playerId, slot, { random = Math.random, now = Date.now(), auto = false } = {}) {
  if (game.status !== 'playing') return { error: 'game_over' };
  if (!game.players.includes(playerId)) return { error: 'not_a_player' };
  if (game.turn !== playerId) return { error: 'not_your_turn' };
  const from = opponentOf(game, playerId);
  const victimHand = [...game.hands[from]];
  if (!Number.isInteger(slot) || slot < 0 || slot >= victimHand.length) return { error: 'invalid_slot' };

  const [card] = victimHand.splice(slot, 1);
  const mine = game.hands[playerId];
  const matched = card.isJoker ? null : mine.find((c) => c.rank === card.rank) ?? null;
  const kept = matched ? mine.filter((c) => c.id !== matched.id) : [...mine, card];
  // 뽑은 사람의 손패는 매번 다시 섞는다. 다음 차례에 상대가 고르는 위치(slot)가
  // 카드가 들어온 순서·조커 위치를 드러내지 않게 한다(화면은 각자 정렬해서 보여 준다).
  const hand = shuffle(kept, random);
  const paired = Boolean(matched);
  const timeouts = { ...game.timeouts, [playerId]: auto ? (game.timeouts?.[playerId] ?? 0) + 1 : 0 };
  const next = checkEnd({
    ...game,
    hands: { ...game.hands, [playerId]: hand, [from]: victimHand },
    turn: from,
    discards: paired ? [...game.discards, card.rank] : game.discards,
    log: [...game.log, { by: playerId, paired, rank: paired ? card.rank : null, at: now }].slice(-LOG_LIMIT),
    drawCount: game.drawCount + 1,
    timeouts,
  });
  return {
    game: next,
    draw: {
      by: playerId,
      from,
      slot,
      card,
      matched,
      paired,
      pairedRank: paired ? card.rank : null,
      jokerMoved: card.isJoker,
      auto,
      at: now,
    },
  };
}

/** 기권(잠수·연속 시간 초과). */
export function forfeit(game, loser, reason = 'forfeit') {
  if (game.status !== 'playing' || !game.players.includes(loser)) return game;
  return { ...game, status: 'finished', turn: null, result: { winner: opponentOf(game, loser), loser, reason } };
}

/** 한 사용자에게 보낼 상태. 내 손패는 카드 그대로, 상대 손패는 위치 별칭만. */
export function projectFor(game, viewerId) {
  const hands = {};
  const handCounts = {};
  for (const id of game.players) {
    const hand = game.hands[id] ?? [];
    handCounts[id] = hand.length;
    // 판이 끝나면 남은 카드(조커)는 모두에게 공개한다.
    hands[id] = id === viewerId || game.status === 'finished'
      ? hand.map((c) => ({ ...c }))
      : hand.map((_, i) => ({ id: `slot-${i}` }));
  }
  return {
    gameId: game.gameId,
    status: game.status,
    players: [...game.players],
    turn: game.turn,
    firstTurn: game.firstTurn,
    hands,
    handCounts,
    discards: [...game.discards],
    discardedPairsCount: game.discards.length,
    log: game.log.map((e) => ({ ...e })),
    drawCount: game.drawCount,
    timeouts: { ...game.timeouts },
    result: game.result ? { ...game.result } : null,
  };
}

/**
 * 뽑기 결과를 한 사용자에게 맞게 거른다.
 * - 뽑은 사람: 뽑은 카드 + 짝이 된 내 카드(matched).
 * - 뺏긴 사람: 뺏긴 자기 카드. 상대 손패의 실제 id는 어느 쪽에도 없다.
 * - 구경꾼: 짝이 된 경우의 랭크만(공개 정보).
 */
export function drawnFor(game, draw, viewerId) {
  const base = {
    gameId: game.gameId,
    by: draw.by,
    from: draw.from,
    slot: draw.slot,
    paired: draw.paired,
    pairedRank: draw.pairedRank,
    jokerMoved: draw.jokerMoved,
    auto: draw.auto,
    drawCount: game.drawCount,
    handSize: game.hands[viewerId]?.length ?? null,
    finished: game.status === 'finished',
    at: draw.at,
  };
  if (viewerId === draw.by) return { ...base, role: 'drawer', card: { ...draw.card }, matched: draw.matched ? { ...draw.matched } : null };
  if (viewerId === draw.from) return { ...base, role: 'victim', card: { ...draw.card }, matched: null };
  return { ...base, role: 'spectator', card: null, matched: null };
}
