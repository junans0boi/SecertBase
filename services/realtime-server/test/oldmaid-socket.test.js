// 도둑잡기 2.0 소켓 계약: 실제 socket.js + games/oldmaid.js, 메모리 Redis/DB.
import assert from 'node:assert/strict';
import test from 'node:test';
import { fixture, flush } from './support/socket-harness.js';
import oldmaid, { OLDMAID_DRAW_FX_MS, OLDMAID_TURN_MS, oldmaidKey } from '../src/games/oldmaid.js';

const A = 'ALPHA-code';
const B = 'BETA-code';
const card = (id, rank, suit = '♠') => ({ id, rank, suit, isJoker: rank === 'JOKER' });
const joker = () => card('card_joker', 'JOKER', '🃏');

function listen(f) {
  const seen = [[], []].map(() => ({ state: [], drawn: [], started: [] }));
  f.clients.forEach((c, i) => {
    c.on('game:oldmaid:state', (v) => seen[i].state.push(v));
    c.on('game:oldmaid:drawn', (v) => seen[i].drawn.push(v));
    c.on('game:lobby:started', (v) => seen[i].started.push(v));
  });
  return seen;
}

async function startFromLobby(f) {
  assert.equal((await f.call(0, 'game:lobby:join', { gameType: 'oldmaid' })).ok, true);
  assert.equal((await f.call(1, 'game:lobby:join', { gameType: 'oldmaid' })).ok, true);
  assert.equal((await f.call(0, 'game:lobby:start', { gameType: 'oldmaid' })).ok, true);
  await flush();
}

const stored = async (f) => JSON.parse(await f.redis.get(oldmaidKey(f.roomCode)));
const put = (f, game) => f.redis.set(oldmaidKey(f.roomCode), JSON.stringify(game), 'EX', 3600);
const crafted = (hands, turn, extra = {}) => ({
  gameId: 'crafted-game', status: 'playing', players: [A, B], hands, turn, firstTurn: turn,
  discards: ['2', '3'], log: [], drawCount: 4, timeouts: { [A]: 0, [B]: 0 }, result: null,
  series: { wins: { [A]: 0, [B]: 0 }, draws: 0, games: 0 }, turnDeadline: Date.now() + 60_000, ...extra,
});
const idx = (who) => (who === A ? 0 : 1);

test('lobby start creates the game on the server with private hands, a turn deadline and the lobby gameId', async (t) => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 1_000_000 });
  const seen = listen(f);
  await startFromLobby(f);
  const gameId = seen[0].started[0].metadata.gameId;
  assert.equal(seen[0].started[0].metadata.serverStart, true);
  for (const [i, me, opp] of [[0, A, B], [1, B, A]]) {
    const s = seen[i].state.at(-1);
    assert.equal(s.gameId, gameId);
    assert.equal(s.status, 'playing');
    assert.ok([A, B].includes(s.turn));
    assert.ok(s.hands[me].every((c) => c.rank && c.suit), 'my own hand has real cards');
    assert.ok(s.hands[opp].every((c, n) => c.id === `slot-${n}` && c.rank === undefined), 'opponent hand is aliases only');
    assert.ok(!JSON.stringify(s.hands[opp]).includes('card_'));
    assert.equal(s.handCounts[opp], s.hands[opp].length);
    assert.equal(s.discardedPairsCount, s.discards.length);
    assert.deepEqual(s.log, []);
    assert.deepEqual(s.series, { wins: { [A]: 0, [B]: 0 }, draws: 0, games: 0 });
    assert.equal(s.turnMs, OLDMAID_TURN_MS);
    assert.equal(s.serverNow, 1_000_000);
    assert.ok(s.turnDeadline > 1_000_000 + OLDMAID_TURN_MS, 'first deadline starts after the lobby countdown');
  }
});

test('a draw sends each side its own drawn event: drawer sees the drawn card, victim sees their taken card', async (t) => {
  const f = await fixture(t);
  const seen = listen(f);
  await put(f, crafted({
    [A]: [card('a1', '7', '♦'), card('a2', 'K')],
    [B]: [card('b1', '9'), card('b2', '7', '♣'), joker()],
  }, A));
  assert.equal((await f.call(0, 'game:oldmaid:draw', { slot: 1, gameId: 'crafted-game' })).ok, true);
  await flush();
  const drawer = seen[0].drawn.at(-1);
  const victim = seen[1].drawn.at(-1);
  assert.equal(drawer.role, 'drawer');
  assert.deepEqual(drawer.card, card('b2', '7', '♣'));
  assert.equal(drawer.paired, true);
  assert.equal(drawer.pairedRank, '7');
  assert.equal(drawer.matched.id, 'a1');
  assert.equal(drawer.jokerMoved, false);
  assert.equal(drawer.handSize, 1);
  assert.equal(victim.role, 'victim');
  assert.deepEqual(victim.card, card('b2', '7', '♣'), 'the victim learns which of their own cards was taken');
  assert.equal(victim.matched, null);
  assert.equal(victim.handSize, 2);
  for (const view of [drawer, victim]) {
    assert.ok(!JSON.stringify(view).includes('b1') && !JSON.stringify(view).includes('card_joker'), 'no other real ids');
  }
  const stateA = seen[0].state.at(-1);
  assert.deepEqual(stateA.discards, ['2', '3', '7']);
  assert.deepEqual(stateA.log.map(({ by, paired, rank }) => ({ by, paired, rank })), [{ by: A, paired: true, rank: '7' }]);
  assert.equal(stateA.turn, B);
  assert.ok(stateA.turnDeadline >= stateA.serverNow + OLDMAID_TURN_MS);
});

test('the joker moving is flagged for both sides and the drawer keeps it', async (t) => {
  const f = await fixture(t);
  const seen = listen(f);
  await put(f, crafted({ [A]: [card('a1', '4')], [B]: [joker(), card('b1', '4', '♥')] }, A));
  assert.equal((await f.call(0, 'game:oldmaid:draw', { cardId: 'slot-0' })).ok, true);
  await flush();
  assert.equal(seen[0].drawn.at(-1).jokerMoved, true);
  assert.equal(seen[0].drawn.at(-1).card.isJoker, true);
  assert.equal(seen[1].drawn.at(-1).jokerMoved, true);
  assert.equal(seen[0].drawn.at(-1).paired, false);
  assert.ok(seen[0].state.at(-1).hands[A].some((c) => c.isJoker));
  assert.deepEqual(seen[1].state.at(-1).log.at(-1).rank, null);
});

test('draws are validated: aliases only, turn order, stale game ids and missing games', async (t) => {
  const f = await fixture(t);
  assert.equal((await f.call(0, 'game:oldmaid:draw', { slot: 0 })).reason, 'no_game');
  await put(f, crafted({ [A]: [card('a1', '4')], [B]: [joker(), card('b1', '4', '♥')] }, A));
  assert.equal((await f.call(0, 'game:oldmaid:draw', { cardId: 'card_joker' })).reason, 'invalid_payload');
  assert.equal((await f.call(0, 'game:oldmaid:draw', { cardId: 'b1' })).reason, 'invalid_payload');
  assert.equal((await f.call(1, 'game:oldmaid:draw', { slot: 0 })).reason, 'not_your_turn');
  assert.equal((await f.call(0, 'game:oldmaid:draw', { slot: 5 })).reason, 'invalid_slot');
  assert.equal((await f.call(0, 'game:oldmaid:draw', { slot: 0, gameId: 'older' })).reason, 'stale_game');
  assert.equal((await stored(f)).drawCount, 4, 'rejected draws change nothing');
});

test('the last joker holder loses; the result and series are recorded once with the gameId', async (t) => {
  const f = await fixture(t);
  const seen = listen(f);
  await put(f, crafted({ [A]: [card('a1', 'Q')], [B]: [card('b1', 'Q', '♥'), joker()] }, A));
  assert.equal((await f.call(0, 'game:oldmaid:draw', { slot: 0 })).ok, true);
  await flush();
  const end = seen[1].state.at(-1);
  assert.equal(end.status, 'finished');
  assert.deepEqual(end.result, { winner: A, loser: B, reason: 'joker' });
  assert.equal(end.turnDeadline, null);
  assert.equal(end.hands[B][0].isJoker, true, 'the remaining joker is revealed at the end');
  assert.deepEqual(end.series.wins, { [A]: 1, [B]: 0 });
  assert.equal(seen[1].drawn.at(-1).finished, true);
  assert.equal(f.results.length, 1);
  assert.equal(f.results[0][1], 'oldmaid');
  assert.equal(f.results[0][2], A);
  assert.equal(f.results[0][7], 'crafted-game');
  assert.equal((await f.call(1, 'game:oldmaid:draw', { slot: 0 })).reason, 'game_over');
  await flush();
  assert.equal(f.results.length, 1);
});

test('consented rematch starts a fresh game, keeps the series and swaps the first drawer', async (t) => {
  const f = await fixture(t);
  const seen = listen(f);
  await put(f, crafted({ [A]: [card('a1', 'Q')], [B]: [card('b1', 'Q', '♥'), joker()] }, A));
  await f.call(0, 'game:oldmaid:draw', { slot: 0 });
  await flush();
  assert.equal((await f.call(1, 'game:restart:request', { gameType: 'oldmaid' })).ok, true);
  assert.equal((await f.call(0, 'game:restart:respond', { accept: true, gameType: 'oldmaid' })).ok, true);
  await flush();
  const next = seen[0].state.at(-1);
  assert.equal(next.status, 'playing');
  assert.notEqual(next.gameId, 'crafted-game');
  assert.equal(next.firstTurn, B, 'the other player draws first after a rematch');
  assert.equal(next.turn, B);
  assert.deepEqual(next.series.wins, { [A]: 1, [B]: 0 });
  assert.ok(next.turnDeadline > next.serverNow);
});

test('sync re-sends the current state to the caller and restore covers a running game', async (t) => {
  const f = await fixture(t);
  assert.equal((await f.call(1, 'game:oldmaid:sync', {})).reason, 'no_game');
  const seen = listen(f);
  await startFromLobby(f);
  const before = seen[1].state.length;
  const ack = await f.call(1, 'game:oldmaid:sync', {});
  await flush();
  assert.equal(ack.ok, true);
  assert.equal(seen[1].state.length, before + 1);
  const restored = await f.call(1, 'session:restore', {});
  await flush();
  assert.ok(restored.restored.includes('oldmaid'));
  assert.equal(seen[1].state.length, before + 2);
});

test('turn timer auto-draws a random card at the deadline and three straight timeouts forfeit', async (t) => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 2_000_000 });
  const originalRandom = oldmaid.random;
  oldmaid.random = () => 0.3;
  t.after(() => { oldmaid.random = originalRandom; });
  const seen = listen(f);
  await startFromLobby(f);
  const first = seen[0].state.at(-1);
  const sleeper = first.turn;
  f.tick(first.turnDeadline - Date.now() - 1);
  await flush();
  assert.equal(seen[0].drawn.length, 0, 'nothing happens before the deadline');
  f.tick(1);
  await flush();
  const auto = seen[idx(sleeper)].drawn.at(-1);
  assert.equal(auto.auto, true);
  assert.equal(auto.by, sleeper);
  assert.equal(auto.role, 'drawer');
  assert.equal((await stored(f)).timeouts[sleeper], 1);
  // 다음 차례 마감은 뽑기 연출 시간을 포함한다.
  const second = seen[0].state.at(-1);
  assert.equal(second.turnDeadline, Date.now() + OLDMAID_DRAW_FX_MS + OLDMAID_TURN_MS);
  for (let i = 0; i < 4; i++) {
    const s = await stored(f);
    if (s.status !== 'playing') break;
    f.tick(s.turnDeadline - Date.now());
    await flush();
  }
  const end = await stored(f);
  assert.equal(end.status, 'finished');
  assert.equal(end.result.reason, 'timeout');
  assert.equal(end.result.loser, sleeper);
  assert.equal(f.results.length, 1);
  assert.equal(seen[0].state.at(-1).result.reason, 'timeout');
});

test('a manual draw resets the timeout streak', async (t) => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 3_000_000 });
  await put(f, crafted({
    [A]: [card('a1', '5'), card('a2', '6'), card('a3', '8')],
    [B]: [card('b1', '9'), card('b2', '10'), card('b3', 'J'), joker()],
  }, A, { timeouts: { [A]: 2, [B]: 0 } }));
  assert.equal((await f.call(0, 'game:oldmaid:draw', { slot: 0 })).ok, true);
  await flush();
  assert.equal((await stored(f)).timeouts[A], 0);
});
