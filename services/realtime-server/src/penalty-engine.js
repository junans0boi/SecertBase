const MAX_KICKS_PER_PLAYER = 5;

export function initPenaltyGame(player1Id, player2Id) {
  return {
    status: "playing",
    round: 1, // 1 ~ 10
    kicker: player1Id,
    keeper: player2Id,
    submissions: {},
    scores: { [player1Id]: 0, [player2Id]: 0 },
    rounds: [],
    result: null,
  };
}
function countKicks(rounds, playerId) {
  return rounds.reduce(
    (count, round) => count + (String(round.kicker) === String(playerId) ? 1 : 0),
    0,
  );
}

function findWinner(scores, rounds) {
  const playerIds = Object.keys(scores);
  if (playerIds.length !== 2) return null;

  const [player1, player2] = playerIds;
  const score1 = scores[player1] || 0;
  const score2 = scores[player2] || 0;

  if (rounds.length >= MAX_KICKS_PER_PLAYER * 2) {
    if (score1 > score2) return player1;
    if (score2 > score1) return player2;
    return "draw";
  }

  const remaining1 = MAX_KICKS_PER_PLAYER - countKicks(rounds, player1);
  const remaining2 = MAX_KICKS_PER_PLAYER - countKicks(rounds, player2);

  // A player wins as soon as the trailing player cannot even tie with all
  // their remaining kicks converted into goals.
  if (score1 > score2 && score2 + remaining2 < score1) return player1;
  if (score2 > score1 && score1 + remaining1 < score2) return player2;
  return null;
}

export function resolvePenaltyRound(game, kickerDir, keeperDir) {
  if (!game || game.status !== "playing") return game;

  const kickerId = String(game.kicker);
  const keeperId = String(game.keeper);
  const isGoal = kickerDir !== keeperDir;
  const scores = { ...game.scores };

  if (isGoal) scores[kickerId] = (scores[kickerId] || 0) + 1;

  const rounds = [
    ...(game.rounds || []),
    {
      round: game.round,
      kicker: kickerId,
      keeper: keeperId,
      kickerDir,
      keeperDir,
      isGoal,
    },
  ];
  const winner = findWinner(scores, rounds);

  if (winner) {
    return {
      ...game,
      status: "finished",
      scores,
      rounds,
      submissions: {},
      result: { winner, scores },
    };
  }

  return {
    ...game,
    round: game.round + 1,
    kicker: keeperId,
    keeper: kickerId,
    submissions: {},
    scores,
    rounds,
  };
}
