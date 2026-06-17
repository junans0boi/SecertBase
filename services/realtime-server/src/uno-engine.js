/**
 * UNO Card Game Engine
 * 
 * Rules:
 * - Each player starts with 7 cards
 * - Match card by color or number
 * - Special cards: Skip, Reverse, Draw2, Wild, Wild Draw4
 * - Shout "UNO" when down to 1 card
 * - Win: Empty hand first
 */

export const COLORS = ['red', 'yellow', 'green', 'blue'];
export const NUMBERS = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
export const ACTIONS = ['skip', 'reverse', 'draw2'];
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
 * Check if a card can be played on top card
 */
export function canPlayCard(card, topCard, declaredColor = null) {
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
 * Apply card effect
 */
export function applyCardEffect(gameState, card) {
  if (card.value === 'skip') {
    gameState.currentPlayer = getNextPlayer(gameState);
  } else if (card.value === 'reverse') {
    gameState.direction *= -1;
    if (gameState.players.length === 2) {
      // In 2-player game, reverse acts as skip
      gameState.currentPlayer = getNextPlayer(gameState);
    }
  } else if (card.value === 'draw2') {
    gameState.drawStack += 2;
  } else if (card.value === 'wild_draw4') {
    gameState.drawStack += 4;
  }
}

/**
 * Check win condition
 */
export function checkWin(gameState, player) {
  return gameState.hands[player].length === 0;
}
