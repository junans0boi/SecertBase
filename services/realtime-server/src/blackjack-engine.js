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

function sameGame(game, changes = {}) {
  return { ...game, ...changes };
}

function dealRound(deck, players, round) {
  const nextDeck = [...deck];
  const [player1Id, player2Id] = players;
  const hands = {
    [player1Id]: [nextDeck.pop(), nextDeck.pop()],
    [player2Id]: [nextDeck.pop(), nextDeck.pop()],
  };
  const statuses = {
    [player1Id]: isBlackjack(hands[player1Id]) ? 'blackjack' : 'playing',
    [player2Id]: isBlackjack(hands[player2Id]) ? 'blackjack' : 'playing',
  };

  // Turn order alternates between rounds so neither player always goes first.
  const preferredTurn = round % 2 === 1 ? player1Id : player2Id;
  const currentTurn = statuses[preferredTurn] === 'playing'
    ? preferredTurn
    : players.find((playerId) => statuses[playerId] === 'playing') ?? null;

  return {
    deck: nextDeck,
    round,
    hands,
    statuses,
    currentTurn,
    phase: currentTurn ? 'player_turn' : 'round_result',
  };
}

export function initGame(player1Id, player2Id) {
  const players = [String(player1Id), String(player2Id)];
  let game = {
    status: 'playing',
    players,
    ...dealRound(createDeck(), players, 1),
    rounds: [],
    lastRoundResult: null,
    result: null,
  };

  // Both players can receive a natural blackjack. Resolve that round
  // immediately because there is no action left to take.
  if (!game.currentTurn) game = finishRound(game);
  return game;
}

function draw(game, playerId) {
  if (game.deck.length === 0) return { game, hand: game.hands[playerId] };
  const deck = [...game.deck];
  const card = deck.pop();
  const hand = [...game.hands[playerId], card];
  return {
    game: { ...game, deck },
    hand,
  };
}

function determineRoundWinner(game) {
  const [player1Id, player2Id] = game.players;
  const player1Hand = game.hands[player1Id] ?? [];
  const player2Hand = game.hands[player2Id] ?? [];
  const player1Score = calculateScore(player1Hand);
  const player2Score = calculateScore(player2Hand);
  const player1Bust = isBust(player1Hand);
  const player2Bust = isBust(player2Hand);
  const player1Blackjack = isBlackjack(player1Hand);
  const player2Blackjack = isBlackjack(player2Hand);

  if (player1Bust && player2Bust) return 'tie';
  if (player1Bust) return player2Id;
  if (player2Bust) return player1Id;
  if (player1Blackjack && !player2Blackjack) return player1Id;
  if (!player1Blackjack && player2Blackjack) return player2Id;
  if (player1Score > player2Score) return player1Id;
  if (player1Score < player2Score) return player2Id;
  return 'tie';
}

function finishRound(game) {
  const [player1Id, player2Id] = game.players;
  const player1Hand = game.hands[player1Id] ?? [];
  const player2Hand = game.hands[player2Id] ?? [];
  const scores = {
    [player1Id]: calculateScore(player1Hand),
    [player2Id]: calculateScore(player2Hand),
  };
  const winner = determineRoundWinner(game);
  const roundResult = {
    round: game.round,
    players: game.players,
    hands: game.hands,
    scores,
    statuses: game.statuses,
    winner,
  };

  return sameGame(game, {
    phase: 'round_result',
    currentTurn: null,
    rounds: [...(game.rounds ?? []), roundResult],
    lastRoundResult: roundResult,
  });
}

function advanceTurn(game) {
  const nextPlayer = game.players.find(
    (playerId) => playerId !== game.currentTurn && game.statuses[playerId] === 'playing',
  );
  if (!nextPlayer) return finishRound(game);
  return sameGame(game, { currentTurn: nextPlayer, phase: 'player_turn' });
}

export function hit(game, playerId) {
  const userId = String(playerId);
  if (
    game.status !== 'playing' ||
    game.phase !== 'player_turn' ||
    game.currentTurn !== userId ||
    game.statuses[userId] !== 'playing'
  ) return game;

  const drawn = draw(game, userId);
  const nextGame = sameGame(drawn.game, {
    hands: { ...drawn.game.hands, [userId]: drawn.hand },
  });
  const score = calculateScore(drawn.hand);

  if (score > 21) {
    return advanceTurn(sameGame(nextGame, {
      statuses: { ...nextGame.statuses, [userId]: 'bust' },
    }));
  }
  if (score === 21) {
    return advanceTurn(sameGame(nextGame, {
      statuses: { ...nextGame.statuses, [userId]: 'stand' },
    }));
  }
  return nextGame;
}

export function stand(game, playerId) {
  const userId = String(playerId);
  if (
    game.status !== 'playing' ||
    game.phase !== 'player_turn' ||
    game.currentTurn !== userId ||
    game.statuses[userId] !== 'playing'
  ) return game;

  return advanceTurn(sameGame(game, {
    statuses: { ...game.statuses, [userId]: 'stand' },
  }));
}

function countRoundWins(rounds) {
  const wins = {};
  for (const round of rounds) {
    if (round.winner !== 'tie') wins[round.winner] = (wins[round.winner] ?? 0) + 1;
  }
  return wins;
}

export function nextRound(game, userId) {
  const playerId = String(userId);
  if (
    game.status !== 'playing' ||
    game.phase !== 'round_result' ||
    !game.players.includes(playerId)
  ) return game;

  if (game.round >= 2) {
    const wins = countRoundWins(game.rounds ?? []);
    const [player1Id, player2Id] = game.players;
    const winner = (wins[player1Id] ?? 0) > (wins[player2Id] ?? 0)
      ? player1Id
      : (wins[player2Id] ?? 0) > (wins[player1Id] ?? 0) ? player2Id : 'tie';
    return sameGame(game, {
      status: 'finished',
      phase: 'finished',
      result: { winner, rounds: game.rounds },
    });
  }

  const round = dealRound(game.deck, game.players, game.round + 1);
  let nextGame = sameGame(game, {
    ...round,
    lastRoundResult: game.lastRoundResult,
  });
  if (!nextGame.currentTurn) nextGame = finishRound(nextGame);
  return nextGame;
}

// Only the viewer's own hand and score are sent while a round is active.
// Keeping the redaction here also prevents the hidden cards from leaking via
// the socket payload or the browser's developer tools.
export function serializeFor(game, viewerId) {
  const userId = String(viewerId ?? '');
  const revealAll = game.status === 'finished' || game.phase === 'round_result';
  const hands = Object.fromEntries(
    game.players.map((playerId) => [
      playerId,
      (game.hands[playerId] ?? []).map((card) =>
        revealAll || playerId === userId ? card : { hidden: true },
      ),
    ]),
  );
  const statuses = Object.fromEntries(
    game.players.map((playerId) => [
      playerId,
      revealAll || playerId === userId ? game.statuses[playerId] : 'hidden',
    ]),
  );
  const scores = {};
  for (const playerId of game.players) {
    if (revealAll || playerId === userId) {
      scores[playerId] = calculateScore(game.hands[playerId] ?? []);
    }
  }

  return {
    status: game.status,
    players: game.players,
    round: game.round,
    phase: game.phase,
    currentTurn: game.currentTurn,
    hands,
    statuses,
    scores,
    rounds: game.rounds ?? [],
    lastRoundResult: game.lastRoundResult,
    result: game.result,
  };
}

// Kept as an explicit helper for callers/tests that need to compare a completed match.
export function determineWinner(rounds, player1Id, player2Id) {
  const wins = countRoundWins(rounds);
  if ((wins[player1Id] ?? 0) > (wins[player2Id] ?? 0)) return player1Id;
  if ((wins[player2Id] ?? 0) > (wins[player1Id] ?? 0)) return player2Id;
  return 'tie';
}
