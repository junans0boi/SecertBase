/**
 * UNO Card Game Engine
 *
 * Rules:
 * - Each player starts with 7 cards
 * - Match card by color or number
 * - Special cards: Skip, Reverse, Draw2, Discard All, Wild, Wild Draw4
 * - Draw stack chaining: +2 defends against +2, +4 defends against +4
 * - +4 challenge: challenger can call bluff
 * - Shout "UNO" when down to 1 card
 * - Win: Empty hand first
 */

export const COLORS = ['red', 'yellow', 'green', 'blue'];
export const NUMBERS = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
export const ACTIONS = ['skip', 'reverse', 'draw2', 'discard_all'];
export const WILDS = ['wild', 'wild_draw4'];

/**
 * Create a standard UNO deck
 */
export function createDeck() {
  const cards = [];

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
    ACTIONS.forEach((action) => {
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
export function shuffle(array) {
  for (let i = array.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [array[i], array[j]] = [array[j], array[i]];
  }
  return array;
}

/**
 * Check if a card can be played on top card.
 * When drawStack > 0, only matching defense cards are allowed.
 */
export function canPlayCard(card, topCard, declaredColor = null, drawStack = 0, drawStackType = null) {
  // Draw stack restriction: must defend with same type or accept
  if (drawStack > 0 && drawStackType) {
    return card.value === drawStackType;
  }

  if (card.value === 'wild' || card.value === 'wild_draw4') {
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
  return hand.some((c) => c.color === color && c.value !== 'wild' && c.value !== 'wild_draw4');
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

  const batch = [triggerCard];
  const remaining = [];
  for (const card of hand) {
    if (card.color === triggerCard.color) {
      batch.push(card);
    } else {
      remaining.push(card);
    }
  }

  hand.splice(0, hand.length, ...remaining);
  return batch;
}

/**
 * Initialize UNO game
 */
export function createUnoGameState(players, handSize = 7) {
  const deck = shuffle(createDeck());
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

  return {
    players,
    hands,
    deck,
    discardPile,
    currentPlayer: players[0],
    direction: 1, // 1: clockwise, -1: counterclockwise
    declaredColor: null,
    drawStack: 0,
    drawStackType: null,     // 'draw2' | 'wild_draw4' | null
    lastDraw4Player: null,   // who played the last wild_draw4 (for challenge check)
    colorBeforeDraw4: null,  // effective color before last draw4 (for challenge check)
    winner: null,
    unoCallers: [],
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

/**
 * Draw cards from deck
 */
export function drawCards(gameState, count) {
  const cards = [];

  for (let i = 0; i < count; i++) {
    if (gameState.deck.length === 0) {
      // Reshuffle discard pile into deck
      const topCard = gameState.discardPile.pop();
      gameState.deck = shuffle([...gameState.discardPile]);
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
  } else if (card.value === 'discard_all') {
    // Batch collection is handled by the play action. The trigger card itself
    // does not add another turn effect.
  } else if (card.value === 'wild_draw4') {
    gameState.drawStack = (gameState.drawStack || 0) + 4;
    gameState.drawStackType = 'wild_draw4';
    // Track for challenge resolution
    gameState.lastDraw4Player = gameState.currentPlayer;
    gameState.colorBeforeDraw4 = previousColor;
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
}

/**
 * Check win condition
 */
export function checkWin(gameState, player) {
  return gameState.hands[player].length === 0;
}
