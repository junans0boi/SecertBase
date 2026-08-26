/**
 * Resolve one Hanabagi (제로) round.
 * Both players reveal fingers and a target total at the same time. A player
 * scores only when they are the sole player who guessed the actual total.
 */
export function resolveHanabagiRound(player1Pick, player2Pick) {
  const total = player1Pick.fingers + player2Pick.fingers;
  const p1Hit = player1Pick.guess === total;
  const p2Hit = player2Pick.guess === total;
  let roundWinner = 'draw';
  if (p1Hit && !p2Hit) roundWinner = 'p1';
  if (p2Hit && !p1Hit) roundWinner = 'p2';

  return { total, p1Hit, p2Hit, roundWinner };
}
