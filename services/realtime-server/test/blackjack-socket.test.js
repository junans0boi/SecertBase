// 블랙잭 2.0 소켓 회귀: 로비 시작 · 투영 · 히트/스탠드 · 준비 · 타이머 · 재대결 · 복원 · 잠수.
import test from 'node:test';
import assert from 'node:assert/strict';
import { fixture, flush } from './support/socket-harness.js';
import { setBlackjackRandom } from '../src/games/blackjack.js';
import { TURN_MS, DEAL_MS } from '../src/blackjack-engine.js';
// socket.js is loaded by the harness with its boundaries replaced; reuse that instance.
const { LOBBY_COUNTDOWN_MS } = await import('../src/socket.js');

const A = 'ALPHA-code';
const B = 'BETA-code';
const card = (rank, suit = '♠') => ({ rank, suit, value: rank === 'A' ? 11 : Number(rank) || 10 });
const key = (f) => `game:${f.roomCode}:blackjack`;
const read = async (f) => JSON.parse(await f.redis.get(key(f)));

/** random() → 0 picks the first player (ALPHA) to open. */
function openWith(t, who) {
  setBlackjackRandom(() => (who === A ? 0 : 0.99));
  t.after(() => setBlackjackRandom(null));
}

function collect(f) {
  const views = [[], []];
  f.clients[0].on('game:blackjack:updated', (v) => views[0].push(v));
  f.clients[1].on('game:blackjack:updated', (v) => views[1].push(v));
  return views;
}

async function startFromLobby(f) {
  assert.equal((await f.call(0, 'game:lobby:join', { gameType: 'blackjack' })).ok, true);
  assert.equal((await f.call(1, 'game:lobby:join', { gameType: 'blackjack' })).ok, true);
  const started = new Promise((resolve) => f.clients[1].once('game:lobby:started', resolve));
  assert.equal((await f.call(0, 'game:lobby:start', { gameType: 'blackjack' })).ok, true);
  const event = await started;
  await flush();
  return event;
}

/** Replace the running round's hands (deck pops from the end). */
async function rig(f, hands, deck = []) {
  const g = await read(f);
  g.hands = { [A]: hands[A].map((r) => card(r)), [B]: hands[B].map((r) => card(r)) };
  g.deck = deck.map((r) => card(r));
  await f.redis.set(key(f), JSON.stringify(g), 'EX', 3600);
}

test('blackjack: lobby start creates the match on the server with a hidden hole card', async (t) => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 10_000_000 });
  openWith(t, A);
  const views = collect(f);
  const started = await startFromLobby(f);
  assert.equal(started.metadata.serverStart, true, 'the screen has no start button');
  const g = await read(f);
  assert.equal(g.status, 'playing');
  assert.equal(g.currentTurn, A);
  assert.equal(g.round, 1);
  assert.ok(g.gameId);
  assert.equal(g.turnDeadline, 10_000_000 + LOBBY_COUNTDOWN_MS + DEAL_MS + TURN_MS);

  const forBeta = views[1].at(-1);
  assert.equal(forBeta.hands[A][1].hidden, true);
  assert.equal(forBeta.hands[A][1].rank, undefined, 'hole card never leaves the server');
  assert.equal(forBeta.hands[A][0].rank !== undefined, true, 'up card is public');
  assert.equal(forBeta.scores[A], undefined);
  assert.equal(typeof forBeta.visibleScores[A], 'number');
  assert.equal(forBeta.hands[B][1].hidden, undefined, 'my own hole card is visible to me');
  assert.equal(forBeta.serverNow, 10_000_000);
  assert.equal('deck' in forBeta, false);

  const synced = await f.call(1, 'game:blackjack:sync', {});
  assert.equal(synced.ok, true);
  assert.equal(synced.state.gameId, g.gameId);
  assert.equal(synced.state.hands[A][1].hidden, true);
});

test('blackjack: turns, a bust that ends the round, both-ready next round with the loser acting second', async (t) => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 11_000_000 });
  openWith(t, A);
  const views = collect(f);
  await startFromLobby(f);
  await rig(f, { [A]: ['10', '5'], [B]: ['9', '7'] }, ['2', '3']);

  assert.equal((await f.call(1, 'game:blackjack:hit', {})).reason, 'not_your_turn');
  assert.equal((await f.call(0, 'game:blackjack:hit', {})).ok, true);
  await flush();
  let seen = views[1].at(-1);
  assert.deepEqual(seen.hands[A].map((c) => c.rank ?? '?'), ['10', '?', '3'], 'hits are public');
  assert.equal(seen.visibleScores[A], 13);
  assert.equal((await f.call(0, 'game:blackjack:stand', {})).ok, true);
  await flush();
  seen = views[1].at(-1);
  assert.equal(seen.statuses[A], 'stand');
  assert.equal(seen.currentTurn, B);

  // B 16 + K → bust → A wins round 1 immediately.
  const g = await read(f);
  g.deck = [card('K')];
  await f.redis.set(key(f), JSON.stringify(g), 'EX', 3600);
  assert.equal((await f.call(1, 'game:blackjack:hit', {})).ok, true);
  await flush();
  seen = views[0].at(-1);
  assert.equal(seen.phase, 'round_result');
  assert.equal(seen.lastRoundResult.winner, A);
  assert.equal(seen.lastRoundResult.reason, 'bust');
  assert.equal(seen.hands[B][1].rank, '7', 'hole cards are revealed at the round result');
  assert.deepEqual(seen.wins, { [A]: 1, [B]: 0 });

  assert.equal((await f.call(0, 'game:blackjack:hit', {})).reason, 'wrong phase');
  assert.equal((await f.call(0, 'game:blackjack:next_round', {})).ok, true);
  await flush();
  assert.deepEqual(views[1].at(-1).ready, { [A]: true, [B]: false });
  assert.equal(views[1].at(-1).phase, 'round_result', 'waits for both');
  assert.equal((await f.call(1, 'game:blackjack:next_round', {})).ok, true);
  await flush();
  seen = views[1].at(-1);
  assert.equal(seen.phase, 'player_turn');
  assert.equal(seen.round, 2);
  assert.equal(seen.currentTurn, A, 'round winner opens; the loser (B) acts second');
  assert.equal(f.results.length, 0, 'nothing recorded mid-match');
});

test('blackjack: the server auto-stands after 30 s and three straight timeouts forfeit once', async (t) => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 12_000_000 });
  openWith(t, A);
  const views = collect(f);
  await startFromLobby(f);
  await rig(f, { [A]: ['10', '5'], [B]: ['9', '7'] });

  f.tick(LOBBY_COUNTDOWN_MS + DEAL_MS + TURN_MS - 1);
  await flush();
  assert.equal((await read(f)).currentTurn, A, 'not yet');
  f.tick(1);
  await flush();
  let g = await read(f);
  assert.equal(g.statuses[A], 'stand');
  assert.equal(g.timeouts[A], 1);
  assert.equal(g.currentTurn, B);
  assert.equal(views[0].at(-1).currentTurn, B);

  // B stands on 16 against A's 15 → B wins round 1 and opens round 2.
  assert.equal((await f.call(1, 'game:blackjack:stand', {})).ok, true);
  await flush();
  assert.equal((await read(f)).lastRoundResult.winner, B);
  await f.call(0, 'game:blackjack:next_round', {});
  await f.call(1, 'game:blackjack:next_round', {});
  await flush();
  g = await read(f);
  assert.equal(g.currentTurn, B);
  // Rig so B cannot finish the match: B stands on a low total and A idles.
  await rig(f, { [A]: ['10', '9'], [B]: ['2', '3'] });
  assert.equal((await f.call(1, 'game:blackjack:stand', {})).ok, true);
  await flush();
  f.tick(TURN_MS);
  await flush();
  g = await read(f);
  assert.equal(g.timeouts[A], 2);
  assert.equal(g.lastRoundResult.winner, A, 'the auto-stand still compares hands');
  await f.call(0, 'game:blackjack:next_round', {});
  await f.call(1, 'game:blackjack:next_round', {});
  await flush();
  g = await read(f);
  assert.equal(g.currentTurn, A, 'A won round 2, so A opens round 3');
  f.tick(DEAL_MS + TURN_MS);
  await flush();
  g = await read(f);
  assert.equal(g.status, 'finished');
  assert.deepEqual({ winner: g.result.winner, reason: g.result.reason }, { winner: B, reason: 'timeout' });
  assert.equal(g.series.wins[B], 1);
  assert.equal(views[1].at(-1).result.reason, 'timeout');
  assert.equal(f.results.length, 1, 'one recorded result');
  f.tick(TURN_MS * 3);
  await flush();
  assert.equal(f.results.length, 1, 'no timer keeps running after the end');
});

test('blackjack: rematch keeps the series and hands the opening turn to the other player', async (t) => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 13_000_000 });
  openWith(t, A);
  const views = collect(f);
  await startFromLobby(f);
  // A wins two rounds quickly: B busts twice.
  for (let r = 0; r < 2; r += 1) {
    const g = await read(f);
    const opener = g.currentTurn;
    await rig(f, { [A]: ['10', '9'], [B]: ['10', '6'] }, ['K']);
    if (opener === A) assert.equal((await f.call(0, 'game:blackjack:stand', {})).ok, true);
    assert.equal((await f.call(1, 'game:blackjack:hit', {})).ok, true);
    await flush();
    if (r === 0) {
      await f.call(0, 'game:blackjack:next_round', {});
      await f.call(1, 'game:blackjack:next_round', {});
      await flush();
    }
  }
  const done = await read(f);
  assert.equal(done.status, 'finished');
  assert.equal(done.result.winner, A);
  assert.deepEqual(done.series.wins, { [A]: 1, [B]: 0 });
  assert.equal(views[1].at(-1).series.games, 1);
  assert.equal(f.results.length, 1);

  assert.equal((await f.call(1, 'game:restart:request', { gameType: 'blackjack' })).ok, true);
  assert.equal((await f.call(0, 'game:restart:respond', { accept: true, gameType: 'blackjack' })).ok, true);
  await flush();
  const next = await read(f);
  assert.equal(next.status, 'playing');
  assert.notEqual(next.gameId, done.gameId);
  assert.equal(next.openingPlayer, B, 'the opener alternates on a rematch');
  assert.equal(next.currentTurn, B);
  assert.equal(next.round, 1);
  assert.deepEqual(next.series.wins, { [A]: 1, [B]: 0 }, 'series carries over');
  assert.equal(views[0].at(-1).gameId, next.gameId);
});

test('blackjack: session restore re-sends a running round to the reconnecting player', async (t) => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 14_000_000 });
  openWith(t, A);
  await startFromLobby(f);
  const views = [];
  f.clients[1].on('game:blackjack:updated', (v) => views.push(v));
  const restored = await f.call(1, 'session:restore', {});
  await flush();
  assert.ok(restored.restored.includes('blackjack'));
  assert.equal(views.length, 1);
  assert.equal(views[0].hands[A][1].hidden, true, 'restore uses the same private projection');
});

test('blackjack: an idle player at the round result is forfeited by the AFK watcher', async (t) => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 15_000_000 });
  openWith(t, A);
  const forfeits = [];
  f.clients[0].on('game:afk:forfeit', (e) => forfeits.push(e));
  await startFromLobby(f);
  await rig(f, { [A]: ['10', '6'], [B]: ['9', '7'] }, ['K']);
  assert.equal((await f.call(0, 'game:blackjack:hit', {})).ok, true); // A busts
  assert.equal((await f.call(1, 'game:blackjack:next_round', {})).ok, true);
  await flush();
  f.tick(90_000);
  await flush();
  assert.equal(forfeits.length, 1);
  assert.equal(forfeits[0].gameType, 'blackjack');
  assert.equal(forfeits[0].loser, A);
  const g = await read(f);
  assert.equal(g.status, 'finished');
  assert.equal(g.result.reason, 'afk');
  assert.equal(g.result.winner, B);
  assert.equal(f.results.length, 1);
});

test('blackjack: actions without a game or a room are rejected', async (t) => {
  const f = await fixture(t);
  assert.equal((await f.call(0, 'game:blackjack:hit', {})).reason, 'no_game');
  assert.equal((await f.call(0, 'game:blackjack:next_round', {})).reason, 'no_game');
  const synced = await f.call(0, 'game:blackjack:sync', {});
  assert.deepEqual(synced, { ok: true, state: null });
});
