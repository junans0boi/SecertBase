const SUITS = ['♠', '♥', '♦', '♣'];
const RANKS = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'];

export function createDeck() {
  const deck = [];
  for (const suit of SUITS) {
    for (const rank of RANKS) {
      let value = parseInt(rank, 10);
      if (['J', 'Q', 'K'].includes(rank)) value = 10;
      if (rank === 'A') value = 11;
      deck.push({ suit, rank, value });
    }
  }
  return shuffle(deck);
}

function shuffle(array) {
  const deck = [...array];
  for (let i = deck.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [deck[i], deck[j]] = [deck[j], deck[i]];
  }
  return deck;
}

export function calculateScore(hand) {
  let score = 0;
  let aces = 0;
  for (const card of hand) {
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

export function isBust(hand) {
  return calculateScore(hand) > 21;
}

export function isBlackjack(hand) {
  return hand.length === 2 && calculateScore(hand) === 21;
}

export function initGame(player1Id, player2Id) {
  const deck = createDeck();

  const p1Hand = [deck.pop(), deck.pop()];
  const d1Hand = [deck.pop(), deck.pop()];
  const p2Hand = [deck.pop(), deck.pop()];
  const d2Hand = [deck.pop(), deck.pop()];

  const game = {
    status: 'playing',
    deck,
    players: {
      [player1Id]: {
        hand: p1Hand,
        status: isBlackjack(p1Hand) ? 'blackjack' : 'playing',
      },
      [player2Id]: {
        hand: p2Hand,
        status: isBlackjack(p2Hand) ? 'blackjack' : 'playing',
      },
    },
    dealers: {
      [player1Id]: { hand: d1Hand },
      [player2Id]: { hand: d2Hand },
    },
    result: null,
  };

  return checkAutoFinish(game);
}

function checkAutoFinish(game) {
  const playerIds = Object.keys(game.players);
  const p1Status = game.players[playerIds[0]].status;
  const p2Status = game.players[playerIds[1]].status;

  const p1Done = p1Status !== 'playing';
  const p2Done = p2Status !== 'playing';

  if (p1Done && p2Done) {
    return playDealersAndSettle(game);
  }
  return game;
}

export function playerHit(game, playerId) {
  if (game.status !== 'playing') return game;
  const player = game.players[playerId];
  if (!player || player.status !== 'playing') return game;

  const nextDeck = [...game.deck];
  const card = nextDeck.pop();
  const nextHand = [...player.hand, card];

  let nextStatus = 'playing';
  if (isBust(nextHand)) {
    nextStatus = 'bust';
  } else if (calculateScore(nextHand) === 21) {
    nextStatus = 'stand';
  }

  const updatedGame = {
    ...game,
    deck: nextDeck,
    players: {
      ...game.players,
      [playerId]: {
        ...player,
        hand: nextHand,
        status: nextStatus,
      },
    },
  };

  return checkAutoFinish(updatedGame);
}

export function playerStand(game, playerId) {
  if (game.status !== 'playing') return game;
  const player = game.players[playerId];
  if (!player || player.status !== 'playing') return game;

  const updatedGame = {
    ...game,
    players: {
      ...game.players,
      [playerId]: {
        ...player,
        status: 'stand',
      },
    },
  };

  return checkAutoFinish(updatedGame);
}

function playDealersAndSettle(game) {
  const nextDeck = [...game.deck];
  const nextDealers = { ...game.dealers };
  const playerIds = Object.keys(game.players);

  for (const pid of playerIds) {
    let dHand = [...nextDealers[pid].hand];
    while (calculateScore(dHand) < 17 && !isBust(dHand)) {
      if (nextDeck.length > 0) {
        dHand.push(nextDeck.pop());
      } else {
        break;
      }
    }
    nextDealers[pid] = { hand: dHand };
  }

  const evalPlayer = (pid) => {
    const pHand = game.players[pid].hand;
    const dHand = nextDealers[pid].hand;
    const pScore = calculateScore(pHand);
    const dScore = calculateScore(dHand);
    const pBust = isBust(pHand);
    const dBust = isBust(dHand);
    const pBJ = isBlackjack(pHand);
    const dBJ = isBlackjack(dHand);

    let outcome = 'tie';
    let scoreMargin = 0;

    if (pBust) {
      outcome = 'loss';
      scoreMargin = -1;
    } else if (dBust) {
      outcome = 'win';
      scoreMargin = pBJ ? 2 : 1;
    } else if (pBJ && !dBJ) {
      outcome = 'win';
      scoreMargin = 2;
    } else if (!pBJ && dBJ) {
      outcome = 'loss';
      scoreMargin = -2;
    } else if (pScore > dScore) {
      outcome = 'win';
      scoreMargin = 1;
    } else if (pScore < dScore) {
      outcome = 'loss';
      scoreMargin = -1;
    } else {
      outcome = 'tie';
      scoreMargin = 0;
    }

    return {
      playerId: pid,
      playerHand: pHand,
      dealerHand: dHand,
      playerScore: pScore,
      dealerScore: dScore,
      playerBust: pBust,
      dealerBust: dBust,
      isPlayerBJ: pBJ,
      isDealerBJ: dBJ,
      outcome,
      scoreMargin,
    };
  };

  const p1Id = playerIds[0];
  const p2Id = playerIds[1];
  const res1 = evalPlayer(p1Id);
  const res2 = evalPlayer(p2Id);

  const overallWinner = determineWinner(res1, res2, p1Id, p2Id);

  return {
    ...game,
    status: 'finished',
    deck: nextDeck,
    dealers: nextDealers,
    result: {
      outcomes: {
        [p1Id]: res1,
        [p2Id]: res2,
      },
      winner: overallWinner,
    },
  };
}

export function determineWinner(res1, res2, p1Id, p2Id) {
  if (res1.scoreMargin > res2.scoreMargin) return p1Id;
  if (res2.scoreMargin > res1.scoreMargin) return p2Id;
  return 'tie';
}
