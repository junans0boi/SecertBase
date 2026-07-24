const SUITS = ['♠', '♥', '♦', '♣'];
const RANKS = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];

export function createDeck() {
  const deck = [];
  let idCounter = 1;

  for (const suit of SUITS) {
    for (const rank of RANKS) {
      deck.push({
        id: `card_${idCounter++}`,
        rank,
        suit,
        isJoker: false,
      });
    }
  }

  // Add 1 Joker card
  deck.push({
    id: `card_joker`,
    rank: 'JOKER',
    suit: '🃏',
    isJoker: true,
  });

  return shuffle(deck);
}

function shuffle(array) {
  const list = [...array];
  for (let i = list.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [list[i], list[j]] = [list[j], list[i]];
  }
  return list;
}

export function removePairs(hand) {
  const rankMap = new Map();
  for (const card of hand) {
    if (card.isJoker) continue;
    if (!rankMap.has(card.rank)) {
      rankMap.set(card.rank, []);
    }
    rankMap.get(card.rank).push(card);
  }

  const removedCardIds = new Set();
  let removedCount = 0;

  for (const [rank, cards] of rankMap.entries()) {
    while (cards.length >= 2) {
      const c1 = cards.pop();
      const c2 = cards.pop();
      removedCardIds.add(c1.id);
      removedCardIds.add(c2.id);
      removedCount += 2;
    }
  }

  const updatedHand = hand.filter((card) => !removedCardIds.has(card.id));
  return { updatedHand, removedCount };
}

export function initGame(player1Id, player2Id) {
  const deck = createDeck();
  const p1RawHand = [];
  const p2RawHand = [];

  for (let i = 0; i < deck.length; i++) {
    if (i % 2 === 0) {
      p1RawHand.push(deck[i]);
    } else {
      p2RawHand.push(deck[i]);
    }
  }

  const { updatedHand: p1Hand, removedCount: p1Removed } = removePairs(p1RawHand);
  const { updatedHand: p2Hand, removedCount: p2Removed } = removePairs(p2RawHand);

  const startingTurn = Math.random() < 0.5 ? player1Id : player2Id;

  const game = {
    status: 'playing',
    turn: startingTurn,
    players: {
      [player1Id]: { hand: p1Hand },
      [player2Id]: { hand: p2Hand },
    },
    discardedPairsCount: (p1Removed + p2Removed) / 2,
    lastDrawnCard: null,
    result: null,
  };

  return checkGameEnd(game);
}

function getOpponentId(game, playerId) {
  const playerIds = Object.keys(game.players);
  return playerIds.find((id) => id !== playerId);
}

export function drawCard(game, playerId, targetCardId) {
  if (game.status !== 'playing' || game.turn !== playerId) {
    return game;
  }

  const opponentId = getOpponentId(game, playerId);
  const opponentHand = [...game.players[opponentId].hand];
  const targetCardIndex = opponentHand.findIndex((c) => c.id === targetCardId);

  if (targetCardIndex === -1) {
    return game; // Invalid card selection
  }

  const drawnCard = opponentHand.splice(targetCardIndex, 1)[0];
  const myHand = [...game.players[playerId].hand, drawnCard];

  const { updatedHand: newMyHand, removedCount } = removePairs(myHand);

  const updatedGame = {
    ...game,
    turn: opponentId,
    players: {
      ...game.players,
      [playerId]: { hand: newMyHand },
      [opponentId]: { hand: opponentHand },
    },
    discardedPairsCount: game.discardedPairsCount + removedCount / 2,
    lastDrawnCard: {
      by: playerId,
      from: opponentId,
      card: drawnCard,
      wasPairRemoved: removedCount > 0,
    },
  };

  return checkGameEnd(updatedGame);
}

function checkGameEnd(game) {
  const playerIds = Object.keys(game.players);
  const p1Hand = game.players[playerIds[0]].hand;
  const p2Hand = game.players[playerIds[1]].hand;

  const totalRemainingCards = p1Hand.length + p2Hand.length;

  if (totalRemainingCards === 1) {
    let loser = null;
    let winner = null;

    if (p1Hand.length === 1 && p1Hand[0].isJoker) {
      loser = playerIds[0];
      winner = playerIds[1];
    } else if (p2Hand.length === 1 && p2Hand[0].isJoker) {
      loser = playerIds[1];
      winner = playerIds[0];
    }

    if (loser && winner) {
      return {
        ...game,
        status: 'finished',
        result: {
          winner,
          loser,
        },
      };
    }
  }

  return game;
}

export function determineWinner(game) {
  return game.result?.winner ?? null;
}
