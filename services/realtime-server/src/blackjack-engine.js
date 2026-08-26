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
  for (let i = deck.length - 1; i > 0; i -= 1) {
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

function dealRound(deck, dealerId, playerId, round) {
  const nextDeck = [...deck];
  const playerHand = [nextDeck.pop(), nextDeck.pop()];
  const dealerHand = [nextDeck.pop(), nextDeck.pop()];
  const playerStatus = isBlackjack(playerHand) ? 'blackjack' : 'playing';

  return {
    deck: nextDeck,
    round,
    dealerId,
    playerId,
    playerHand,
    dealerHand,
    playerStatus,
    dealerStatus: 'playing',
    phase: playerStatus === 'blackjack' ? 'dealer_turn' : 'player_turn',
  };
}

export function initGame(player1Id, player2Id) {
  const round = dealRound(createDeck(), player1Id, player2Id, 1);
  return {
    status: 'playing',
    players: [player1Id, player2Id],
    ...round,
    rounds: [],
    lastRoundResult: null,
    result: null,
  };
}

function sameGame(game, changes = {}) {
  return { ...game, ...changes };
}

function draw(game, handKey) {
  if (game.deck.length === 0) return { game, hand: game[handKey] };
  const deck = [...game.deck];
  const card = deck.pop();
  return {
    game: { ...game, deck },
    hand: [...game[handKey], card],
  };
}

function finishRound(game, forcedOutcome = null) {
  const playerScore = calculateScore(game.playerHand);
  const dealerScore = calculateScore(game.dealerHand);
  const playerBust = isBust(game.playerHand);
  const dealerBust = isBust(game.dealerHand);
  const playerBlackjack = isBlackjack(game.playerHand);
  const dealerBlackjack = isBlackjack(game.dealerHand);

  let outcome = forcedOutcome;
  if (!outcome) {
    if (playerBust) outcome = 'loss';
    else if (dealerBust) outcome = 'win';
    else if (playerBlackjack && !dealerBlackjack) outcome = 'win';
    else if (!playerBlackjack && dealerBlackjack) outcome = 'loss';
    else if (playerScore > dealerScore) outcome = 'win';
    else if (playerScore < dealerScore) outcome = 'loss';
    else outcome = 'tie';
  }

  const roundResult = {
    round: game.round,
    dealerId: game.dealerId,
    playerId: game.playerId,
    playerHand: game.playerHand,
    dealerHand: game.dealerHand,
    playerScore,
    dealerScore,
    playerBust,
    dealerBust,
    isPlayerBJ: playerBlackjack,
    isDealerBJ: dealerBlackjack,
    outcome,
    winner: outcome === 'win' ? game.playerId : outcome === 'loss' ? game.dealerId : 'tie',
  };

  return sameGame(game, {
    phase: 'round_result',
    playerStatus: playerBust ? 'bust' : game.playerStatus,
    dealerStatus: dealerBust ? 'bust' : game.dealerStatus,
    rounds: [...(game.rounds ?? []), roundResult],
    lastRoundResult: roundResult,
  });
}

export function playerHit(game, playerId) {
  if (
    game.status !== 'playing' ||
    game.phase !== 'player_turn' ||
    game.playerId !== playerId ||
    game.playerStatus !== 'playing'
  ) return game;

  const drawn = draw(game, 'playerHand');
  const playerHand = drawn.hand;
  const nextGame = sameGame(drawn.game, { playerHand });
  const score = calculateScore(playerHand);

  if (score > 21) return finishRound(nextGame, 'loss');
  if (score === 21) {
    return sameGame(nextGame, {
      playerStatus: 'stand',
      phase: 'dealer_turn',
    });
  }
  return nextGame;
}

export function playerStand(game, playerId) {
  if (
    game.status !== 'playing' ||
    game.phase !== 'player_turn' ||
    game.playerId !== playerId ||
    game.playerStatus !== 'playing'
  ) return game;

  return sameGame(game, {
    playerStatus: 'stand',
    phase: 'dealer_turn',
  });
}

export function dealerHit(game, dealerId) {
  if (
    game.status !== 'playing' ||
    game.phase !== 'dealer_turn' ||
    game.dealerId !== dealerId ||
    game.dealerStatus !== 'playing'
  ) return game;

  // Standard blackjack dealer rule: a dealer must stand on 17 or higher.
  if (calculateScore(game.dealerHand) >= 17) return game;

  const drawn = draw(game, 'dealerHand');
  const dealerHand = drawn.hand;
  const nextGame = sameGame(drawn.game, { dealerHand });
  const score = calculateScore(dealerHand);

  if (score > 21) return finishRound(nextGame, 'win');
  if (score >= 17) {
    return finishRound(sameGame(nextGame, { dealerStatus: 'stand' }));
  }
  return nextGame;
}

export function dealerStand(game, dealerId) {
  if (
    game.status !== 'playing' ||
    game.phase !== 'dealer_turn' ||
    game.dealerId !== dealerId ||
    game.dealerStatus !== 'playing'
  ) return game;

  return finishRound(sameGame(game, { dealerStatus: 'stand' }));
}

function countRoundWins(rounds) {
  const wins = {};
  for (const round of rounds) {
    if (round.winner !== 'tie') wins[round.winner] = (wins[round.winner] ?? 0) + 1;
  }
  return wins;
}

export function nextRound(game, userId) {
  if (
    game.status !== 'playing' ||
    game.phase !== 'round_result' ||
    !game.players.includes(userId)
  ) return game;

  if (game.round >= 2) {
    const wins = countRoundWins(game.rounds ?? []);
    const [p1, p2] = game.players;
    const winner = (wins[p1] ?? 0) > (wins[p2] ?? 0)
      ? p1
      : (wins[p2] ?? 0) > (wins[p1] ?? 0) ? p2 : 'tie';
    return sameGame(game, {
      status: 'finished',
      phase: 'finished',
      result: { winner, rounds: game.rounds },
    });
  }

  const round = dealRound(game.deck, game.playerId, game.dealerId, game.round + 1);
  return sameGame(game, {
    ...round,
    lastRoundResult: game.lastRoundResult,
  });
}

// Kept as an explicit helper for callers/tests that need to compare a completed match.
export function determineWinner(rounds, player1Id, player2Id) {
  const wins = countRoundWins(rounds);
  if ((wins[player1Id] ?? 0) > (wins[player2Id] ?? 0)) return player1Id;
  if ((wins[player2Id] ?? 0) > (wins[player1Id] ?? 0)) return player2Id;
  return 'tie';
}
