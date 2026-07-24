export function initBasketballGame(player1Id, player2Id) {
  return {
    status: 'playing',
    seed: Math.floor(Math.random() * 1000000) + 1,
    shots: {
      [player1Id]: [],
      [player2Id]: [],
    },
    scores: {
      [player1Id]: 0,
      [player2Id]: 0,
    },
    result: null,
  };
}

export function submitShot(game, playerId, isMade, points = 2) {
  if (game.status !== 'playing') return game;
  const playerShots = game.shots[playerId] || [];
  if (playerShots.length >= 10) return game;

  const nextShots = [...playerShots, { isMade, points }];
  const addedPoints = isMade ? points : 0;
  const nextScores = {
    ...game.scores,
    [playerId]: (game.scores[playerId] || 0) + addedPoints,
  };

  const updatedGame = {
    ...game,
    shots: {
      ...game.shots,
      [playerId]: nextShots,
    },
    scores: nextScores,
  };

  return checkGameFinished(updatedGame);
}

export function isBasketballFinished(game) {
  const pIds = Object.keys(game.shots);
  if (pIds.length < 2) return false;
  return game.shots[pIds[0]].length >= 10 && game.shots[pIds[1]].length >= 10;
}

function checkGameFinished(game) {
  if (isBasketballFinished(game)) {
    const pIds = Object.keys(game.scores);
    const score1 = game.scores[pIds[0]];
    const score2 = game.scores[pIds[1]];

    let winner = 'draw';
    if (score1 > score2) winner = pIds[0];
    else if (score2 > score1) winner = pIds[1];

    return {
      ...game,
      status: 'finished',
      result: {
        winner,
        scores: game.scores,
      },
    };
  }
  return game;
}
