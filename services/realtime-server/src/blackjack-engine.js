// 블랙잭 2.0 엔진(순수 함수). 딜러 없는 1:1 21점 대결.
//
// - 한 판 = 먼저 2승(최대 5라운드). 무승부 라운드는 승수에 더하지 않는다. 5라운드 뒤에도
//   2승이 없으면 그 판은 무승부(winner 'tie').
// - 라운드마다 새 52장. 각자 2장: 0번 = 업카드(공개), 1번 = 홀카드(비공개). 히트 카드는 공개.
// - 차례대로 행동한다. 버스트하면 그 라운드가 즉시 끝나고 상대가 이긴다.
// - 블랙잭(처음 2장 21)은 일반 21보다 강하다. 블랙잭 여부는 라운드가 끝날 때까지 비공개이고,
//   보유자도 평소처럼 자기 차례에 스탠드한다(자동 진행으로 정보가 새지 않게).
// - 21이 되면 더 히트할 수 없다(스탠드만). 자동 스탠드는 하지 않는다(상대에게 21을 알리지 않게).
// - 선후공: 1라운드는 무작위. 이후 직전 라운드 패배자가 후공(상대가 먼저 행동),
//   무승부 라운드는 선후공을 바꾼다.
// - 시간: 결정마다 30초. 넘기면 서버가 자동 스탠드, 연속 3회면 기권.
//
// 모든 함수는 새 상태를 돌려주고 입력을 바꾸지 않는다. random·now는 주입한다.

export const TURN_MS = 30_000;
/** 라운드 시작 때 카드가 날아가는 연출 시간만큼 첫 결정 시간을 늘려 준다. */
export const DEAL_MS = 1_500;
export const WINS_NEEDED = 2;
export const MAX_ROUNDS = 5;
export const MAX_TIMEOUTS = 3;

const SUITS = ['♠', '♥', '♦', '♣'];
const RANKS = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'];
const HOLE_INDEX = 1;

export function createDeck(random = Math.random) {
  const deck = [];
  for (const suit of SUITS) {
    for (const rank of RANKS) {
      let value = parseInt(rank, 10);
      if (['J', 'Q', 'K'].includes(rank)) value = 10;
      if (rank === 'A') value = 11;
      deck.push({ suit, rank, value });
    }
  }
  for (let i = deck.length - 1; i > 0; i -= 1) {
    const j = Math.floor(random() * (i + 1));
    [deck[i], deck[j]] = [deck[j], deck[i]];
  }
  return deck;
}

export function calculateScore(hand) {
  let score = 0;
  let aces = 0;
  for (const card of hand ?? []) {
    if (!card || card.hidden) continue;
    if (card.rank === 'A') {
      aces += 1;
      score += 11;
    } else if (['J', 'Q', 'K'].includes(card.rank)) {
      score += 10;
    } else {
      score += parseInt(card.rank, 10);
    }
  }
  while (score > 21 && aces > 0) {
    score -= 10;
    aces -= 1;
  }
  return score;
}

export const isBust = (hand) => calculateScore(hand) > 21;
export const isBlackjack = (hand) => (hand?.length ?? 0) === 2 && calculateScore(hand) === 21;

/** 상대에게 보이는 카드(홀카드 제외). */
export const publicCards = (hand) => (hand ?? []).filter((_, i) => i !== HOLE_INDEX);
export const visibleScore = (hand) => calculateScore(publicCards(hand));

export const otherPlayer = (game, playerId) => game.players.find((p) => p !== playerId) ?? null;

/**
 * 다음 라운드의 선공. 직전 라운드 패배자가 후공(= 승자가 선공)이고, 무승부면 선후공을 바꾼다.
 */
export function nextFirstPlayer(game, roundWinner) {
  if (!roundWinner || roundWinner === 'tie') return otherPlayer(game, game.firstPlayer);
  return roundWinner;
}

function dealRound(game, { firstPlayer, round, random, now }) {
  const deck = createDeck(random);
  const second = otherPlayer(game, firstPlayer);
  // 실제 테이블처럼 선공 → 후공 → 선공 → 후공 순서로 한 장씩.
  const hands = { [firstPlayer]: [], [second]: [] };
  for (let i = 0; i < 2; i += 1) {
    hands[firstPlayer].push(deck.pop());
    hands[second].push(deck.pop());
  }
  return {
    ...game,
    status: 'playing',
    phase: 'player_turn',
    round,
    firstPlayer,
    currentTurn: firstPlayer,
    deck,
    hands,
    statuses: { [firstPlayer]: 'playing', [second]: 'playing' },
    ready: Object.fromEntries(game.players.map((p) => [p, false])),
    turnDeadline: now + DEAL_MS + TURN_MS,
  };
}

/**
 * 새 판. firstPlayer가 없으면 random으로 정한다. now는 첫 턴 마감시각의 기준(로비 카운트다운 끝).
 */
export function createMatch({
  players,
  gameId = null,
  firstPlayer = null,
  random = Math.random,
  now = Date.now(),
  series = null,
} = {}) {
  const ids = players.map(String);
  const opening = firstPlayer && ids.includes(String(firstPlayer))
    ? String(firstPlayer)
    : ids[Math.floor(random() * ids.length) % ids.length];
  const base = {
    gameId,
    status: 'playing',
    players: ids,
    winsNeeded: WINS_NEEDED,
    maxRounds: MAX_ROUNDS,
    wins: Object.fromEntries(ids.map((p) => [p, 0])),
    openingPlayer: opening,
    timeouts: Object.fromEntries(ids.map((p) => [p, 0])),
    rounds: [],
    lastRoundResult: null,
    result: null,
    series,
  };
  return dealRound(base, { firstPlayer: opening, round: 1, random, now });
}

function compareHands(game) {
  const [a, b] = game.players;
  const handA = game.hands[a] ?? [];
  const handB = game.hands[b] ?? [];
  const bjA = isBlackjack(handA);
  const bjB = isBlackjack(handB);
  if (bjA && !bjB) return { winner: a, reason: 'blackjack' };
  if (bjB && !bjA) return { winner: b, reason: 'blackjack' };
  const sA = calculateScore(handA);
  const sB = calculateScore(handB);
  if (sA > sB) return { winner: a, reason: 'score' };
  if (sB > sA) return { winner: b, reason: 'score' };
  return { winner: 'tie', reason: 'tie' };
}

function finishRound(game, { winner, reason }) {
  const scores = Object.fromEntries(game.players.map((p) => [p, calculateScore(game.hands[p])]));
  const naturals = Object.fromEntries(game.players.map((p) => [p, isBlackjack(game.hands[p])]));
  const wins = { ...game.wins };
  if (winner !== 'tie') wins[winner] = (wins[winner] ?? 0) + 1;
  const roundResult = {
    round: game.round,
    winner,
    reason,
    firstPlayer: game.firstPlayer,
    scores,
    naturals,
    statuses: { ...game.statuses },
    hands: Object.fromEntries(game.players.map((p) => [p, [...(game.hands[p] ?? [])]])),
    wins: { ...wins },
  };
  const next = {
    ...game,
    wins,
    currentTurn: null,
    turnDeadline: null,
    rounds: [...(game.rounds ?? []), { round: game.round, winner, reason, scores, naturals }],
    lastRoundResult: roundResult,
    ready: Object.fromEntries(game.players.map((p) => [p, false])),
  };
  if (winner !== 'tie' && wins[winner] >= game.winsNeeded) {
    return {
      ...next,
      status: 'finished',
      phase: 'finished',
      result: { winner, loser: otherPlayer(game, winner), reason: 'wins', wins },
    };
  }
  if (game.round >= game.maxRounds) {
    // 5라운드가 끝나면 라운드 승수가 많은 쪽이 이긴다(1 : 0도 승리). 같을 때만 무승부.
    const [p1, p2] = game.players;
    const leader = wins[p1] === wins[p2] ? 'tie' : (wins[p1] > wins[p2] ? p1 : p2);
    return {
      ...next,
      status: 'finished',
      phase: 'finished',
      result: {
        winner: leader,
        loser: leader === 'tie' ? null : otherPlayer(game, leader),
        reason: 'max_rounds',
        wins,
      },
    };
  }
  return { ...next, phase: 'round_result' };
}

function turnError(game, userId) {
  if (!game || game.status !== 'playing') return 'no_game';
  if (!game.players.includes(userId)) return 'not_a_player';
  if (game.phase !== 'player_turn') return 'wrong phase';
  if (game.currentTurn !== userId) return 'not_your_turn';
  if (game.statuses?.[userId] !== 'playing') return 'wrong phase';
  return null;
}

/** 카드 한 장 받기. 버스트면 즉시 라운드 종료(상대 승). → { ok, game } | { ok:false, reason } */
export function hit(game, playerId, { now = Date.now() } = {}) {
  const userId = String(playerId);
  const error = turnError(game, userId);
  if (error) return { ok: false, reason: error };
  if (calculateScore(game.hands[userId]) >= 21) return { ok: false, reason: 'already_21' };

  const deck = [...game.deck];
  const card = deck.pop();
  const hand = [...game.hands[userId], card];
  let next = {
    ...game,
    deck,
    hands: { ...game.hands, [userId]: hand },
    timeouts: { ...game.timeouts, [userId]: 0 },
    turnDeadline: now + TURN_MS,
  };
  if (isBust(hand)) {
    next = { ...next, statuses: { ...next.statuses, [userId]: 'bust' } };
    return { ok: true, game: finishRound(next, { winner: otherPlayer(game, userId), reason: 'bust' }), card };
  }
  return { ok: true, game: next, card };
}

function applyStand(game, userId, now) {
  const next = { ...game, statuses: { ...game.statuses, [userId]: 'stand' } };
  const other = otherPlayer(game, userId);
  if (next.statuses[other] === 'playing') {
    return { ...next, currentTurn: other, turnDeadline: now + TURN_MS };
  }
  return finishRound(next, compareHands(next));
}

/** 스탠드. 상대가 아직 행동 전이면 차례를 넘기고, 아니면 비교해 라운드를 끝낸다. */
export function stand(game, playerId, { now = Date.now() } = {}) {
  const userId = String(playerId);
  const error = turnError(game, userId);
  if (error) return { ok: false, reason: error };
  const reset = { ...game, timeouts: { ...game.timeouts, [userId]: 0 } };
  return { ok: true, game: applyStand(reset, userId, now) };
}

/** 라운드 결과 화면에서 "다음 라운드" 준비. 둘 다 준비되면 새 라운드를 돌린다. */
export function nextRound(game, playerId, { now = Date.now(), random = Math.random } = {}) {
  const userId = String(playerId);
  if (!game || game.status !== 'playing') return { ok: false, reason: 'no_game' };
  if (!game.players.includes(userId)) return { ok: false, reason: 'not_a_player' };
  if (game.phase !== 'round_result') return { ok: false, reason: 'wrong phase' };
  const ready = { ...game.ready, [userId]: true };
  if (!game.players.every((p) => ready[p])) return { ok: true, game: { ...game, ready } };
  const firstPlayer = nextFirstPlayer(game, game.lastRoundResult?.winner);
  return { ok: true, game: dealRound({ ...game, ready }, { firstPlayer, round: game.round + 1, random, now }) };
}

/**
 * 결정 시간이 지났을 때(서버 타이머). 차례인 사람을 자동 스탠드시키고, 연속 3회째면 기권패.
 * → { game, timedOut: userId|null }
 */
export function timeoutTurn(game, { now = Date.now() } = {}) {
  if (!game || game.status !== 'playing' || game.phase !== 'player_turn' || !game.currentTurn) {
    return { game, timedOut: null };
  }
  const userId = game.currentTurn;
  const count = (game.timeouts?.[userId] ?? 0) + 1;
  const counted = { ...game, timeouts: { ...game.timeouts, [userId]: count } };
  if (count >= MAX_TIMEOUTS) return { game: forfeit(counted, userId, 'timeout'), timedOut: userId };
  return { game: applyStand(counted, userId, now), timedOut: userId };
}

/** 기권패(시간 초과 3회, 잠수). */
export function forfeit(game, loserId, reason = 'forfeit') {
  const loser = String(loserId);
  const winner = otherPlayer(game, loser);
  return {
    ...game,
    status: 'finished',
    phase: 'finished',
    currentTurn: null,
    turnDeadline: null,
    result: { winner, loser, reason, wins: { ...game.wins } },
  };
}

/**
 * 보는 사람별 투영. 진행 중에는 상대의 홀카드를 {hidden:true}로 가리고 점수는 공개 카드 합만 준다.
 * 라운드가 끝나면(round_result/finished) 둘 다 공개한다. 덱은 보내지 않는다.
 */
export function serializeFor(game, viewerId, { now = Date.now() } = {}) {
  const userId = String(viewerId ?? '');
  const reveal = game.phase !== 'player_turn';
  const hands = {};
  const scores = {};
  const visibleScores = {};
  for (const p of game.players) {
    const hand = game.hands?.[p] ?? [];
    const open = reveal || p === userId;
    hands[p] = open ? hand.map((c) => ({ ...c })) : hand.map((c, i) => (i === HOLE_INDEX ? { hidden: true } : { ...c }));
    if (open) scores[p] = calculateScore(hand);
    visibleScores[p] = visibleScore(hand);
  }
  return {
    gameId: game.gameId ?? null,
    status: game.status,
    phase: game.phase,
    players: game.players,
    round: game.round,
    maxRounds: game.maxRounds,
    winsNeeded: game.winsNeeded,
    wins: game.wins,
    firstPlayer: game.firstPlayer,
    currentTurn: game.currentTurn,
    turnDeadline: game.turnDeadline ?? null,
    turnMs: TURN_MS,
    serverNow: now,
    hands,
    statuses: game.statuses,
    scores,
    visibleScores,
    timeouts: game.timeouts,
    ready: game.ready,
    rounds: game.rounds ?? [],
    lastRoundResult: game.lastRoundResult,
    result: game.result,
    series: game.series ?? null,
  };
}
