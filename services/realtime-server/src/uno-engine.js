/**
 * 원카드(내부 식별자 uno) 엔진 — 순수 함수, 무작위는 `random`으로 주입한다.
 *
 * 규칙(01-grilling Q50):
 * - 손패 7장, 색이나 숫자/기호를 맞춰 낸다. 먼저 손패를 비우면 승리.
 * - 특수 카드: 스킵, 리버스, +2, 모두 버리기(고와일드), 색 바꾸기, +4.
 * - 고와일드 쌓기: +2 위에 +2/+4, +4 위에 +4. 클래식은 쌓기 없음.
 * - +2/+4 벌칙으로 뽑으면 차례가 끝난다(뽑은 카드 바로 내기 없음).
 * - 모두 버리기 묶음 안의 스킵·리버스는 한 번만 적용한다.
 * - +4 도전은 "낼 때"의 손패(hadColorAtDraw4)로 판정한다.
 * - 마지막 한 장이 되면 "원카드!"를 외친다. 상대가 먼저 "잡기!"하면 2장.
 */

export const COLORS = ['red', 'yellow', 'green', 'blue'];
export const NUMBERS = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
export const ACTIONS = ['skip', 'reverse', 'draw2', 'discard_all'];
export const WILDS = ['wild', 'wild_draw4'];
export const UNO_MODES = ['classic', 'go_wild'];
export const DEFAULT_UNO_MODE = 'go_wild';
export const ONE_CARD_CATCH_PENALTY = 2;
export const CHALLENGE_FAIL_PENALTY = 6;

/**
 * Create a standard deck
 */
export function createDeck({ mode = DEFAULT_UNO_MODE } = {}) {
  const cards = [];
  const actions = mode === 'classic'
    ? ACTIONS.filter((action) => action !== 'discard_all')
    : ACTIONS;

  // Number cards (2 each for 1-9, 1 each for 0)
  COLORS.forEach((color) => {
    cards.push({ color, value: '0', id: `${color}-0` });
    for (let i = 1; i <= 9; i++) {
      cards.push({ color, value: `${i}`, id: `${color}-${i}-a` });
      cards.push({ color, value: `${i}`, id: `${color}-${i}-b` });
    }
  });

  // Action cards (2 each per color)
  COLORS.forEach((color) => {
    actions.forEach((action) => {
      cards.push({ color, value: action, id: `${color}-${action}-a` });
      cards.push({ color, value: action, id: `${color}-${action}-b` });
    });
  });

  // Wild cards (4 each)
  for (let i = 0; i < 4; i++) {
    cards.push({ color: null, value: 'wild', id: `wild-${i}` });
    cards.push({ color: null, value: 'wild_draw4', id: `wild_draw4-${i}` });
  }

  return cards;
}

/**
 * Shuffle array in place
 */
export function shuffle(array, random = Math.random) {
  for (let i = array.length - 1; i > 0; i--) {
    const j = Math.floor(random() * (i + 1));
    [array[i], array[j]] = [array[j], array[i]];
  }
  return array;
}

export const isWildCard = (card) => card?.value === 'wild' || card?.value === 'wild_draw4';

/**
 * Check if a card can be played on top card.
 * When drawStack > 0, only valid defense cards are allowed.
 */
export function canPlayCard(
  card,
  topCard,
  declaredColor = null,
  drawStack = 0,
  drawStackType = null,
  { mode = DEFAULT_UNO_MODE } = {},
) {
  // Draw stack restriction: in go_wild mode, +4 can defend against +2,
  // while a pending +4 can only be defended by another +4.
  if (drawStack > 0 && drawStackType) {
    if (mode === 'classic') return false;
    if (drawStackType === 'wild_draw4') return card.value === 'wild_draw4';
    if (drawStackType === 'draw2') {
      return card.value === 'draw2' || card.value === 'wild_draw4';
    }
    return false;
  }

  if (mode === 'classic' && card.value === 'discard_all') {
    return false;
  }

  if (isWildCard(card)) {
    return true;
  }

  const effectiveColor = declaredColor || topCard.color;

  if (card.color === effectiveColor) {
    return true;
  }

  if (card.value === topCard.value) {
    return true;
  }

  return false;
}

/**
 * Check if the challenged player had a playable card of the given color
 * (used for +4 challenge resolution)
 */
export function hadPlayableCardOfColor(hand, color) {
  return hand.some((c) => c.color === color && !isWildCard(c));
}

/**
 * A +4 challenge is available only for a standalone +4 attack.
 * Once another +2/+4 has been stacked, the draw penalty is greater than 4
 * and the challenger must draw or defend instead.
 */
export function canChallengeDraw4(gameState, player) {
  return gameState?.drawStack === 4 &&
    gameState?.drawStackType === 'wild_draw4' &&
    gameState?.currentPlayer === player &&
    !gameState?.winner;
}

export function isDiscardAllCard(card) {
  return card?.value === 'discard_all' && COLORS.includes(card.color);
}

/**
 * Discard All is a colored action card. Playing a blue Discard All card also
 * discards every remaining blue card from that player's hand.
 */
export function collectDiscardAllBatch(hand, triggerCard) {
  if (!isDiscardAllCard(triggerCard)) return [triggerCard];

  const sameColor = [];
  const remaining = [];
  for (const card of hand) {
    if (card.color === triggerCard.color) {
      sameColor.push(card);
    } else {
      remaining.push(card);
    }
  }

  hand.splice(0, hand.length, ...remaining);
  // triggerCard last → it becomes the top of the discard pile
  return [...sameColor, triggerCard];
}

/**
 * Initialize a game. `starter` picks the first player (defaults to a random one).
 */
export function createUnoGameState(players, handSize = 7, options = {}) {
  const random = options.random ?? Math.random;
  const mode = UNO_MODES.includes(options.mode) ? options.mode : DEFAULT_UNO_MODE;
  const deck = shuffle(createDeck({ mode }), random);
  const hands = {};

  players.forEach((player) => {
    hands[player] = deck.splice(0, handSize);
  });

  const discardPile = [deck.pop()];

  // Ensure first card is not action/wild
  while (ACTIONS.includes(discardPile[0].value) || WILDS.includes(discardPile[0].value)) {
    deck.unshift(discardPile.pop());
    discardPile.push(deck.pop());
  }

  const starter = players.includes(options.starter)
    ? options.starter
    : players[Math.floor(random() * players.length) % players.length];

  return {
    mode,
    players,
    hands,
    deck,
    discardPile,
    starter,
    currentPlayer: starter,
    direction: 1, // 1: clockwise, -1: counterclockwise
    declaredColor: null,
    drawStack: 0,
    drawStackType: null,     // 'draw2' | 'wild_draw4' | null
    lastDraw4Player: null,   // who played the last wild_draw4 (for challenge check)
    colorBeforeDraw4: null,  // effective color before last draw4
    hadColorAtDraw4: null,   // did the +4 player hold that color when playing it?
    winner: null,
    unoCallNeeded: null,
    // A playable drawn card (normal draw only) requires an explicit play/pass decision.
    drawnCardId: null,
    autoStreak: {},
    seq: 0,
    lastAction: { type: 'deal', starter, seq: 0 },
  };
}

/**
 * Get next player in turn order
 */
export function getNextPlayer(gameState) {
  const { players, currentPlayer, direction } = gameState;
  const currentIndex = players.indexOf(currentPlayer);
  const nextIndex = (currentIndex + direction + players.length) % players.length;
  return players[nextIndex];
}

export const opponentOf = (gameState, player) => gameState.players.find((p) => p !== player) ?? null;

/**
 * Draw cards from deck
 */
export function drawCards(gameState, count, random = Math.random) {
  const cards = [];

  for (let i = 0; i < count; i++) {
    if (gameState.deck.length === 0 && gameState.discardPile.length > 1) {
      // Reshuffle discard pile into deck
      const topCard = gameState.discardPile.pop();
      gameState.deck = shuffle([...gameState.discardPile], random);
      gameState.discardPile = [topCard];
    }

    if (gameState.deck.length > 0) {
      cards.push(gameState.deck.pop());
    }
  }

  return cards;
}

/**
 * Apply card effect.
 * previousColor: the effective color before this card was played (needed for draw4 challenge tracking).
 */
export function applyCardEffect(gameState, card, previousColor = null) {
  if (card.value === 'skip') {
    gameState.currentPlayer = getNextPlayer(gameState);
  } else if (card.value === 'reverse') {
    gameState.direction *= -1;
    if (gameState.players.length === 2) {
      // In 2-player game, reverse acts as skip
      gameState.currentPlayer = getNextPlayer(gameState);
    }
  } else if (card.value === 'draw2') {
    gameState.drawStack = (gameState.drawStack || 0) + 2;
    gameState.drawStackType = 'draw2';
  } else if (card.value === 'wild_draw4') {
    gameState.drawStack = (gameState.drawStack || 0) + 4;
    gameState.drawStackType = 'wild_draw4';
    // Track for challenge resolution
    gameState.lastDraw4Player = gameState.currentPlayer;
    gameState.colorBeforeDraw4 = previousColor;
  }
}

/**
 * Apply effects from an All-card batch.
 * Cards swept up by All are discarded, so an included +2 is not an attack,
 * and the batch's skip/reverse cards take effect only once (Q50).
 */
export function applyDiscardAllBatchEffects(gameState, cards, previousColor = null) {
  let turnEffectApplied = false;
  for (const card of cards) {
    if (card.value === 'draw2') continue;
    if (card.value === 'skip' || card.value === 'reverse') {
      if (turnEffectApplied) continue;
      turnEffectApplied = true;
    }
    applyCardEffect(gameState, card, previousColor);
  }
}

/**
 * Reset draw stack state
 */
export function clearDrawStack(gameState) {
  gameState.drawStack = 0;
  gameState.drawStackType = null;
  gameState.lastDraw4Player = null;
  gameState.colorBeforeDraw4 = null;
  gameState.hadColorAtDraw4 = null;
}

/**
 * Check win condition
 */
export function checkWin(gameState, player) {
  return gameState.hands[player].length === 0;
}

export const topCardOf = (gameState) => gameState.discardPile[gameState.discardPile.length - 1] ?? null;

/** The color the next card must match: the declared wild color, else the top card's color. */
export const currentColorOf = (gameState) => gameState.declaredColor || topCardOf(gameState)?.color || null;

/** Ids of the cards `player` may play right now (empty when it is not their turn). */
export function playableCardIds(gameState, player) {
  if (gameState.winner || gameState.currentPlayer !== player) return [];
  const hand = gameState.hands[player] ?? [];
  const top = topCardOf(gameState);
  if (!top) return [];
  if (gameState.drawnCardId) {
    return hand.some((c) => c.id === gameState.drawnCardId) ? [gameState.drawnCardId] : [];
  }
  return hand
    .filter((c) => canPlayCard(c, top, gameState.declaredColor, gameState.drawStack ?? 0, gameState.drawStackType, { mode: gameState.mode }))
    .map((c) => c.id);
}

const statOf = (gameState, player, key) => Number(gameState.playerStats?.[player]?.[key] ?? 0) || 0;
const chance = (random, pct) => pct > 0 && random() * 100 < pct;

const recordAction = (gameState, action) => {
  gameState.seq = (gameState.seq ?? 0) + 1;
  gameState.lastAction = { ...action, seq: gameState.seq };
  return gameState.lastAction;
};

const fail = (reason) => ({ ok: false, reason });

/** Every turn action rejects once the game has a winner. */
const guardTurn = (gameState, player) => {
  if (gameState.winner) return fail('game_over');
  if (!gameState.players.includes(player)) return fail('not_in_game');
  if (gameState.currentPlayer !== player) return fail('not_your_turn');
  return null;
};

/**
 * Play a card (and, for Discard All, every same-color card).
 * Returns { ok, cards, won, itemEffects } or { ok: false, reason }.
 */
export function playCard(gameState, player, cardId, declaredColor = null, { random = Math.random } = {}) {
  const rejected = guardTurn(gameState, player);
  if (rejected) return rejected;
  const hand = gameState.hands[player];
  const cardIndex = hand.findIndex((c) => c.id === cardId);
  if (cardIndex === -1) return fail('card_not_found');
  if (gameState.drawnCardId && gameState.drawnCardId !== cardId) return fail('must_choose_drawn_card');

  const card = hand[cardIndex];
  const wild = isWildCard(card);
  if (wild && !COLORS.includes(declaredColor)) return fail('must_declare_color');

  const topCard = topCardOf(gameState);
  const hasStack = (gameState.drawStack || 0) > 0 && gameState.drawStackType;
  if (!canPlayCard(card, topCard, gameState.declaredColor, gameState.drawStack ?? 0, gameState.drawStackType, { mode: gameState.mode })) {
    return fail(hasStack ? 'must_draw_or_defend' : 'cannot_play_card');
  }

  const previousColor = currentColorOf(gameState);
  hand.splice(cardIndex, 1);
  gameState.drawnCardId = null;
  if (card.value === 'wild_draw4') {
    // 도전 판정은 낼 때의 손패로 한다(Q50).
    gameState.hadColorAtDraw4 = hadPlayableCardOfColor(hand, previousColor);
  }
  const playedCards = gameState.mode === 'go_wild' ? collectDiscardAllBatch(hand, card) : [card];
  gameState.discardPile.push(...playedCards);
  gameState.declaredColor = wild ? declaredColor : null;

  if (card.value === 'discard_all') {
    applyDiscardAllBatchEffects(gameState, playedCards, previousColor);
  } else {
    applyCardEffect(gameState, card, previousColor);
  }

  const itemEffects = [];
  let bonusDraw = null;
  // card_reverse_bonus: 리버스를 내면 일정 확률로 상대가 1장 더 받는다(최대 20%).
  if (card.value === 'reverse' && chance(random, Math.min(statOf(gameState, player, 'card_reverse_bonus'), 20))) {
    const opponent = opponentOf(gameState, player);
    if (opponent) {
      const bonus = drawCards(gameState, 1, random);
      gameState.hands[opponent].push(...bonus);
      bonusDraw = { player: opponent, count: bonus.length };
      itemEffects.push({ player, stat: 'card_reverse_bonus' });
    }
  }

  const won = checkWin(gameState, player);
  if (won) {
    gameState.winner = player;
  } else {
    gameState.currentPlayer = getNextPlayer(gameState);
  }

  // 상대의 원카드 외치기 기회는 내가 카드를 내면 사라진다.
  if (gameState.unoCallNeeded && gameState.unoCallNeeded !== player) gameState.unoCallNeeded = null;
  if (!won && hand.length === 1) gameState.unoCallNeeded = player;
  if (!won && hand.length !== 1 && gameState.unoCallNeeded === player) gameState.unoCallNeeded = null;

  const effect = card.value === 'discard_all'
    ? 'discard_all'
    : ({ skip: 'skip', reverse: 'reverse', draw2: 'draw2', wild_draw4: 'draw4', wild: 'wild' }[card.value] ?? null);
  recordAction(gameState, {
    type: 'play',
    by: player,
    card: playedCards[playedCards.length - 1],
    cards: playedCards,
    count: playedCards.length,
    effect,
    declaredColor: gameState.declaredColor,
    colorChanged: wild,
    previousColor,
    turnSkipped: !won && gameState.currentPlayer === player,
    bonusDraw,
  });
  return { ok: true, cards: playedCards, won, itemEffects };
}

/**
 * Draw for the turn: the pending +2/+4 penalty or one card.
 * After a penalty the turn ends; after a normal draw a playable card waits for play/pass.
 */
export function drawForTurn(gameState, player, { random = Math.random, auto = false } = {}) {
  const rejected = guardTurn(gameState, player);
  if (rejected) return rejected;
  if (gameState.drawnCardId) return fail('must_choose_drawn_card');

  const penalty = (gameState.drawStack || 0) > 0;
  let count = penalty ? gameState.drawStack : 1;
  const itemEffects = [];

  // card_shield_pct: 쌓인 벌칙을 통째로 막는다(최대 15%).
  if (penalty && chance(random, Math.min(statOf(gameState, player, 'card_shield_pct'), 15))) {
    count = 0;
    itemEffects.push({ player, stat: 'card_shield_pct' });
  }
  // card_lucky_draw_pct: 한 장 덜 받는다(최대 20%).
  if (count > 1 && chance(random, Math.min(statOf(gameState, player, 'card_lucky_draw_pct'), 20))) {
    count = Math.max(1, count - 1);
    itemEffects.push({ player, stat: 'card_lucky_draw_pct' });
  }
  // onecard_draw_reduce: 보장된 감소(최소 1장).
  const reduce = Math.floor(statOf(gameState, player, 'onecard_draw_reduce'));
  if (reduce > 0 && count > 1) count = Math.max(1, count - reduce);

  const drawn = drawCards(gameState, count, random);
  gameState.hands[player].push(...drawn);
  clearDrawStack(gameState);

  const drawnCard = drawn[drawn.length - 1] ?? null;
  const canPlayDrawn = !penalty && !auto && drawnCard != null &&
    canPlayCard(drawnCard, topCardOf(gameState), gameState.declaredColor, 0, null, { mode: gameState.mode });

  if (canPlayDrawn) {
    gameState.drawnCardId = drawnCard.id;
  } else {
    gameState.drawnCardId = null;
    gameState.currentPlayer = getNextPlayer(gameState);
  }

  // 손패가 늘었으니 내 외치기 의무는 사라지고, 차례가 넘어가면 상대를 잡을 기회도 끝난다.
  if (gameState.unoCallNeeded === player) gameState.unoCallNeeded = null;
  if (gameState.unoCallNeeded && !canPlayDrawn) gameState.unoCallNeeded = null;

  recordAction(gameState, {
    type: 'draw',
    by: player,
    count: drawn.length,
    penalty,
    canPlayDrawn,
    cardIds: drawn.map((c) => c.id),
    auto,
  });
  return { ok: true, count: drawn.length, cards: drawn, penalty, canPlayDrawn, itemEffects };
}

/** Keep the playable drawn card and end the turn. */
export function passDrawnCard(gameState, player, { auto = false } = {}) {
  const rejected = guardTurn(gameState, player);
  if (rejected) return rejected;
  if (!gameState.drawnCardId) return fail('no_draw_choice');
  gameState.drawnCardId = null;
  clearDrawStack(gameState);
  gameState.currentPlayer = getNextPlayer(gameState);
  if (gameState.unoCallNeeded && gameState.unoCallNeeded !== player) gameState.unoCallNeeded = null;
  recordAction(gameState, { type: 'pass', by: player, auto });
  return { ok: true };
}

/** "원카드!" — the player down to one card claims it before being caught. */
export function callOneCard(gameState, player) {
  if (gameState.winner) return fail('game_over');
  if (gameState.unoCallNeeded !== player) return fail('not_needed');
  gameState.unoCallNeeded = null;
  recordAction(gameState, { type: 'call', by: player });
  return { ok: true };
}

/** "잡기!" — catch the opponent who has one card and has not called. */
export function catchOneCard(gameState, player, { random = Math.random } = {}) {
  if (gameState.winner) return fail('game_over');
  if (!gameState.players.includes(player)) return fail('not_in_game');
  const target = gameState.unoCallNeeded;
  if (!target || target === player) return fail('no_target');
  gameState.unoCallNeeded = null;
  // card_uno_protect_pct: 잡혀도 일정 확률로 벌칙을 피한다(최대 15%).
  if (chance(random, Math.min(statOf(gameState, target, 'card_uno_protect_pct'), 15))) {
    recordAction(gameState, { type: 'catch', by: player, target, count: 0, protected: true });
    return { ok: true, target, count: 0, protected: true, itemEffects: [{ player: target, stat: 'card_uno_protect_pct' }] };
  }
  const drawn = drawCards(gameState, ONE_CARD_CATCH_PENALTY, random);
  gameState.hands[target].push(...drawn);
  recordAction(gameState, { type: 'catch', by: player, target, count: drawn.length, protected: false, cardIds: drawn.map((c) => c.id) });
  return { ok: true, target, count: drawn.length, protected: false, itemEffects: [] };
}

/**
 * Challenge a standalone +4. Success (the attacker held the previous color when playing it):
 * the attacker takes 4 and the challenger keeps the turn. Failure: the challenger takes 6 and
 * the turn returns to the attacker. The declared color stays either way.
 */
export function challengeDraw4(gameState, player, { random = Math.random } = {}) {
  if (gameState.winner) return fail('game_over');
  if (!canChallengeDraw4(gameState, player)) return fail('cannot_challenge_during_stack');
  const attacker = gameState.lastDraw4Player;
  if (!attacker || !gameState.colorBeforeDraw4) return fail('no_challenge_data');

  const success = gameState.hadColorAtDraw4 === true;
  const drawnPlayer = success ? attacker : player;
  const drawnCount = success ? 4 : CHALLENGE_FAIL_PENALTY;
  const nextPlayer = success ? player : attacker;
  const drawn = drawCards(gameState, drawnCount, random);
  gameState.hands[drawnPlayer].push(...drawn);
  clearDrawStack(gameState);
  gameState.currentPlayer = nextPlayer;
  gameState.drawnCardId = null;
  if (gameState.unoCallNeeded === drawnPlayer) gameState.unoCallNeeded = null;
  recordAction(gameState, {
    type: 'challenge',
    by: player,
    challenged: attacker,
    success,
    drawnPlayer,
    drawnCount: drawn.length,
    cardIds: drawn.map((c) => c.id),
  });
  return { ok: true, success, challenged: attacker, drawnPlayer, drawnCount: drawn.length, nextPlayer };
}

/**
 * Turn timer expiry: the safe action for the current player (Q52) — never a random card.
 * A pending drawn-card choice is passed; otherwise draw (the pending penalty, or one card) and pass.
 */
export function autoAction(gameState, { random = Math.random } = {}) {
  const player = gameState.currentPlayer;
  if (gameState.winner || !player) return fail('game_over');
  if (gameState.drawnCardId) return { ...passDrawnCard(gameState, player, { auto: true }), player, kind: 'pass' };
  return { ...drawForTurn(gameState, player, { random, auto: true }), player, kind: 'draw' };
}

const handCountOf = (game) => Object.fromEntries(
  (game.players ?? Object.keys(game.hands ?? {})).map((p) => [p, Array.isArray(game.hands?.[p]) ? game.hands[p].length : 0]),
);

/**
 * Per-user view. Never exposes the opponent's hand or the identity of cards the opponent drew.
 */
export function serializeOneCardFor(game, userId) {
  if (!game?.hands || !game?.discardPile) return null;
  const players = game.players ?? Object.keys(game.hands);
  const mine = game.currentPlayer === userId;
  let lastAction = game.lastAction ?? null;
  if (lastAction?.cardIds) {
    const owner = lastAction.type === 'draw'
      ? lastAction.by
      : lastAction.type === 'catch' ? lastAction.target : lastAction.drawnPlayer;
    if (owner !== userId) {
      const { cardIds: _hidden, ...rest } = lastAction;
      lastAction = rest;
    }
  }
  return {
    gameId: game.gameId ?? null,
    mode: game.mode ?? DEFAULT_UNO_MODE,
    players,
    starter: game.starter ?? null,
    currentPlayer: game.currentPlayer ?? null,
    turn: game.currentPlayer ?? null,
    direction: game.direction ?? 1,
    topCard: topCardOf(game),
    recentDiscards: game.discardPile.slice(-5),
    declaredColor: game.declaredColor ?? null,
    currentColor: currentColorOf(game),
    drawStack: game.drawStack ?? 0,
    drawStackType: game.drawStackType ?? null,
    handCount: handCountOf(game),
    hand: game.hands[userId] ?? [],
    deckCount: Array.isArray(game.deck) ? game.deck.length : 0,
    unoCallNeeded: game.unoCallNeeded ?? null,
    drawnCardId: mine ? (game.drawnCardId ?? null) : null,
    playable: game.players ? playableCardIds(game, userId) : [],
    canChallenge: game.players ? canChallengeDraw4(game, userId) : false,
    turnDeadline: game.turnDeadline ?? null,
    turnMs: game.turnMs ?? null,
    serverNow: Date.now(),
    autoStreak: game.autoStreak ?? {},
    equippedItems: game.equippedItems ?? {},
    stake: game.stake ?? 0,
    series: game.series ?? null,
    seq: game.seq ?? 0,
    lastAction,
    winner: game.winner ?? null,
  };
}
