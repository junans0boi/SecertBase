export function calculateBowlingScore(rolls) {
  let score = 0;
  let rollIndex = 0;

  for (let frame = 0; frame < 10; frame++) {
    if (rollIndex >= rolls.length) break;

    if (isStrike(rolls, rollIndex)) {
      score += 10 + strikeBonus(rolls, rollIndex);
      rollIndex += 1;
    } else if (isSpare(rolls, rollIndex)) {
      score += 10 + spareBonus(rolls, rollIndex);
      rollIndex += 2;
    } else {
      const frameScore = (rolls[rollIndex] || 0) + (rolls[rollIndex + 1] || 0);
      score += frameScore;
      rollIndex += 2;
    }
  }

  return score;
}

function isStrike(rolls, rollIndex) {
  return (rolls[rollIndex] || 0) === 10;
}

function isSpare(rolls, rollIndex) {
  return (rolls[rollIndex] || 0) + (rolls[rollIndex + 1] || 0) === 10;
}

function strikeBonus(rolls, rollIndex) {
  return (rolls[rollIndex + 1] || 0) + (rolls[rollIndex + 2] || 0);
}

function spareBonus(rolls, rollIndex) {
  return rolls[rollIndex + 2] || 0;
}

export function buildFrameDisplayData(rolls) {
  // Returns array of 10 frame objects for score sheet rendering
  const frames = [];
  let rollIndex = 0;
  let runningScore = 0;

  for (let frame = 0; frame < 10; frame++) {
    if (rollIndex >= rolls.length) {
      frames.push({ frameIndex: frame + 1, r1: '', r2: '', r3: '', cumScore: '' });
      continue;
    }

    if (frame === 9) {
      // 10th frame
      const r1Num = rolls[rollIndex];
      const r2Num = rolls[rollIndex + 1];
      const r3Num = rolls[rollIndex + 2];

      let r1Str = r1Num === 10 ? 'X' : (r1Num !== undefined ? `${r1Num}` : '');
      let r2Str = '';
      if (r2Num !== undefined) {
        if (r1Num !== 10 && r1Num + r2Num === 10) r2Str = '/';
        else if (r2Num === 10) r2Str = 'X';
        else r2Str = r2Num === 0 ? '-' : `${r2Num}`;
      }

      let r3Str = '';
      if (r3Num !== undefined) {
        if (r3Num === 10) r3Str = 'X';
        else if (r2Num !== 10 && (r2Num || 0) + r3Num === 10) r3Str = '/';
        else r3Str = r3Num === 0 ? '-' : `${r3Num}`;
      }

      if (r1Num === 0) r1Str = '-';

      const isComplete = isPlayerFinished(rolls);
      const cum = isComplete ? calculateBowlingScore(rolls) : '';

      frames.push({ frameIndex: 10, r1: r1Str, r2: r2Str, r3: r3Str, cumScore: cum ? `${cum}` : '' });
      break;
    }

    if (isStrike(rolls, rollIndex)) {
      rollIndex += 1;
      const subRolls = rolls.slice(0, rollIndex);
      const currentCum = calculateBowlingScore(subRolls);
      frames.push({ frameIndex: frame + 1, r1: '', r2: 'X', r3: '', cumScore: `${currentCum}` });
    } else if (isSpare(rolls, rollIndex)) {
      const r1Val = rolls[rollIndex] === 0 ? '-' : `${rolls[rollIndex]}`;
      rollIndex += 2;
      const subRolls = rolls.slice(0, rollIndex);
      const currentCum = calculateBowlingScore(subRolls);
      frames.push({ frameIndex: frame + 1, r1: r1Val, r2: '/', r3: '', cumScore: `${currentCum}` });
    } else {
      const r1Val = rolls[rollIndex] === 0 ? '-' : `${rolls[rollIndex]}`;
      const r2Val = rolls[rollIndex + 1] === undefined ? '' : (rolls[rollIndex + 1] === 0 ? '-' : `${rolls[rollIndex + 1]}`);
      rollIndex += 2;
      const subRolls = rolls.slice(0, rollIndex);
      const currentCum = calculateBowlingScore(subRolls);
      frames.push({ frameIndex: frame + 1, r1: r1Val, r2: r2Val, r3: '', cumScore: `${currentCum}` });
    }
  }

  return frames;
}

export function initBowlingGame(player1Id, player2Id) {
  // Randomize initial starting turn
  const firstPlayer = Math.random() < 0.5 ? player1Id : player2Id;

  return {
    status: 'playing',
    turn: firstPlayer,
    seed: Math.floor(Math.random() * 1000000) + 1,
    rolls: {
      [player1Id]: [],
      [player2Id]: [],
    },
    scores: {
      [player1Id]: 0,
      [player2Id]: 0,
    },
    // Per-roll aim/curve history so a client can exactly reconstruct any
    // player's standing pins by re-simulating, even after missing an update.
    history: [],
    lastRoll: null,
    result: null,
  };
}

// Describes the next roll for a flat roll list: which frame it belongs to,
// whether it opens the frame, and how many pins are standing.
// Returns null when the player has no rolls left.
export function nextRollContext(rolls) {
  let i = 0;
  for (let f = 0; f < 9; f++) {
    if (i === rolls.length) return { frame: f, rollInFrame: 0, standing: 10 };
    if (rolls[i] === 10) {
      i += 1;
      continue;
    }
    if (i + 1 === rolls.length) return { frame: f, rollInFrame: 1, standing: 10 - rolls[i] };
    i += 2;
  }
  const r = rolls.slice(i);
  if (r.length === 0) return { frame: 9, rollInFrame: 0, standing: 10 };
  if (r.length === 1) {
    return { frame: 9, rollInFrame: 1, standing: r[0] === 10 ? 10 : 10 - r[0] };
  }
  if (r.length === 2) {
    if (r[0] === 10) return { frame: 9, rollInFrame: 2, standing: r[1] === 10 ? 10 : 10 - r[1] };
    if (r[0] + r[1] === 10) return { frame: 9, rollInFrame: 2, standing: 10 };
    return null;
  }
  return null;
}

export function rollFrame(game, playerId, pinsKnocked, meta = {}) {
  if (game.status !== 'playing' || game.turn !== playerId) return game;
  const playerRolls = game.rolls[playerId] || [];
  const ctx = nextRollContext(playerRolls);
  if (!ctx) return game;

  // A roll can never knock more pins than are standing (fixes 5+9 frames).
  const pins = Math.min(Math.max(0, pinsKnocked), ctx.standing);

  const nextRolls = [...playerRolls, pins];
  const nextScore = calculateBowlingScore(nextRolls);

  const pIds = Object.keys(game.rolls);
  const opponentId = pIds.find((id) => id !== playerId);

  // Pass the turn only when this roll closed a frame (10th-frame bonus rolls
  // keep the turn until the player is fully done).
  const afterCtx = nextRollContext(nextRolls);
  const frameClosed = afterCtx === null || afterCtx.rollInFrame === 0;
  let nextTurn = playerId;
  if (frameClosed && !isPlayerFinished(game.rolls[opponentId] || [])) {
    nextTurn = opponentId;
  }

  const isStrikeRoll = ctx.rollInFrame === 0 && pins === 10;
  const isSpareRoll = !isStrikeRoll && ctx.rollInFrame >= 1 && ctx.standing === pins && pins > 0;

  const aim = typeof meta.aim === 'number' ? meta.aim : 0;
  const curve = typeof meta.curve === 'number' ? meta.curve : 0;

  const updatedGame = {
    ...game,
    turn: nextTurn,
    rolls: {
      ...game.rolls,
      [playerId]: nextRolls,
    },
    scores: {
      ...game.scores,
      [playerId]: nextScore,
    },
    history: [
      ...(game.history || []),
      { playerId, rollIndex: nextRolls.length - 1, pins, aim, curve },
    ],
    lastRoll: {
      playerId,
      pinsKnocked: pins,
      rollIndex: nextRolls.length - 1,
      aim,
      curve,
      isStrike: isStrikeRoll,
      isSpare: isSpareRoll,
      isGutter: pins === 0,
    },
  };

  return checkGameFinished(updatedGame);
}

export function isPlayerFinished(rolls) {
  let rollIndex = 0;
  for (let frame = 0; frame < 10; frame++) {
    if (rollIndex >= rolls.length) return false;

    if (frame === 9) {
      // 10th frame
      const r1 = rolls[rollIndex];
      if (r1 === undefined) return false;
      const r2 = rolls[rollIndex + 1];
      if (r2 === undefined) return false;
      if (r1 === 10 || r1 + r2 === 10) {
        const r3 = rolls[rollIndex + 2];
        return r3 !== undefined;
      }
      return true;
    }

    if (isStrike(rolls, rollIndex)) {
      rollIndex += 1;
    } else {
      rollIndex += 2;
    }
  }
  return true;
}

export function isBowlingFinished(game) {
  const pIds = Object.keys(game.rolls);
  if (pIds.length < 2) return false;
  return isPlayerFinished(game.rolls[pIds[0]]) && isPlayerFinished(game.rolls[pIds[1]]);
}

function checkGameFinished(game) {
  if (isBowlingFinished(game)) {
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
