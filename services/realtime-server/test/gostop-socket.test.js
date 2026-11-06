// 고스톱 2.0 소켓 흐름(티켓 24): 서버 시작·두 장 선택·마감 자동 스톱·기권 지불·정산 한 번·재대결 선.
// 코인은 메모리 지갑으로 대신해 영수증 합계가 실제 이동 코인과 같은지 확인한다.
import assert from 'node:assert/strict';
import test from 'node:test';
import { boundary, fixture, flush } from './support/socket-harness.js';
import * as E from '../src/gostop-engine.js';
// Loaded after the harness so the module shares its memory DB/Redis boundaries.
const { gostopRuntime, TURN_MS } = await import('../src/games/gostop.js');

const A = 'ALPHA-code';
const B = 'BETA-code';
const COUNTDOWN_MS = 5300;
const gameKey = f => `gostop:${f.roomCode}:game`;
const readGame = async f => JSON.parse(await f.redis.get(gameKey(f)));
const writeGame = (f, g) => f.redis.set(gameKey(f), JSON.stringify(g), 'EX', 3600);
const indexOf = p => (p === A ? 0 : 1);
const card = id => E.cardById(id);
const cards = ids => ids.map(card);
const SEVEN = ['m1_bright', 'm3_bright', 'm8_bright', 'm1_animal', 'm2_ribbon', 'm3_ribbon', 'm6_ribbon', 'm9_ribbon'];

/** 메모리 지갑: transferGameReward가 쓰는 SQL만 흉내 낸다. */
function installWallet(t, { balances = { 11: 10000, 22: 10000 }, failTransfer = false } = {}) {
  const baseQuery = boundary.query;
  const baseTx = boundary.transaction;
  const wallet = { balances: { ...balances }, transfers: [], refs: new Set() };
  boundary.query = async (sql, params) => {
    if (sql.includes('SELECT UserId FROM Users WHERE UserCode')) return { rows: [{ UserId: params[0] === A ? 11 : 22 }] };
    return baseQuery(sql, params);
  };
  boundary.transaction = async run => baseTx(conn => run({
    execute: async (sql, params) => {
      if (failTransfer && sql.includes('wallets')) throw new Error('wallet down');
      if (sql.includes('INSERT IGNORE INTO wallets')) return [[]];
      if (sql.includes('FROM wallet_transactions')) return [wallet.refs.has(params[0]) ? [{ id: 1 }] : []];
      if (sql.includes('SELECT balance FROM wallets')) return [[{ balance: wallet.balances[params[0]] }]];
      if (sql.includes('UPDATE wallets SET balance')) { wallet.balances[params[1]] = params[0]; return [[]]; }
      if (sql.includes('INSERT INTO wallet_transactions')) {
        wallet.transfers.push({ user: params[0], delta: params[1], ref: params[4] });
        wallet.refs.add(params[4]);
        return [[]];
      }
      return conn.execute(sql, params);
    },
  }));
  t.after(() => { boundary.query = baseQuery; boundary.transaction = baseTx; });
  return wallet;
}

async function startFromLobby(f, { stake = 0 } = {}) {
  await f.call(0, 'game:lobby:join', { gameType: 'gostop' });
  await f.call(1, 'game:lobby:join', { gameType: 'gostop' });
  if (stake) {
    assert.equal((await f.call(0, 'game:lobby:set_stake', { gameType: 'gostop', stake })).ok, true);
    assert.equal((await f.call(1, 'game:lobby:ready', { gameType: 'gostop', ready: true })).ok, true);
  }
  assert.equal((await f.call(0, 'game:lobby:start', { gameType: 'gostop' })).ok, true);
  await flush();
  return readGame(f);
}

/** 판을 시나리오에 맞게 고쳐 쓴다(gameId·마감시각·타이머는 그대로). */
async function arrange(f, fn) {
  const g = await readGame(f);
  g.phase = 'playing';
  g.chongtong = null;
  g.pending = null;
  g.field = [];
  g.captures = { [A]: [], [B]: [] };
  g.hands = { [A]: cards(['m10_junk_1', 'm11_junk_1']), [B]: cards(['m10_junk_2', 'm11_junk_2']) };
  g.deck = cards(['m7_junk_1', 'm7_junk_2']);
  g.goCount = { [A]: 0, [B]: 0 };
  g.goScore = { [A]: 0, [B]: 0 };
  g.dotan = { [A]: 0, [B]: 0 };
  g.shakes = { [A]: [], [B]: [] };
  g.bombs = { [A]: 0, [B]: 0 };
  g.ppeok = {};
  g.current = A;
  fn(g);
  const next = E.rescore(g);
  await writeGame(f, next);
  return next;
}

function collect(f, event) {
  const seen = [[], []];
  f.clients.forEach((c, i) => c.on(event, e => seen[i].push(e)));
  return seen;
}

test('lobby start creates the game on the server; sync returns a private view with a 25 s deadline', async t => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 1_000_000 });
  const g = await startFromLobby(f, { stake: 500 });
  assert.equal(g.version, 2);
  assert.equal(g.perPointBet, 500);
  assert.equal(g.turnDeadline, 1_000_000 + COUNTDOWN_MS + TURN_MS);
  assert.equal(TURN_MS, 25_000);
  const sync = await f.call(1, 'game:gostop:sync', {});
  assert.equal(sync.ok, true);
  const view = sync.state;
  assert.deepEqual(view.players, [A, B]);
  assert.equal(view.hand.length, 10);
  assert.deepEqual(view.hand, g.hands[B], 'the caller sees only its own hand');
  assert.equal(view.hands, undefined);
  assert.equal(view.deck, undefined);
  assert.deepEqual(view.handCount, { [A]: 10, [B]: 10 });
  assert.equal(view.deckCount, 20);
  assert.equal(view.serverNow, 1_000_000);
  assert.equal(view.turnDeadline, g.turnDeadline);
  assert.ok(!JSON.stringify(view).includes(g.hands[A][0].id) || view.field.concat(view.captures[A], view.captures[B]).some(c => c.id === g.hands[A][0].id));
});

test('an invalid per-point stake is refused by the lobby', async t => {
  const f = await fixture(t);
  await f.call(0, 'game:lobby:join', { gameType: 'gostop' });
  assert.equal((await f.call(0, 'game:lobby:set_stake', { gameType: 'gostop', stake: 250 })).reason, 'invalid_stake');
});

test('sync without a game reports no_game; actions on a missing game are refused', async t => {
  const f = await fixture(t);
  assert.equal((await f.call(0, 'game:gostop:sync', {})).reason, 'no_game');
  assert.equal((await f.call(0, 'game:gostop:play', { cardId: 'm1_bright' })).reason, 'no_game');
});

test('hand_choice: a card matching two different field cards waits for the player, then continues', async t => {
  const f = await fixture(t);
  await startFromLobby(f);
  await arrange(f, g => {
    g.field = cards(['m8_bright', 'm8_junk_1', 'm2_junk_1']);
    g.hands[A] = cards(['m8_junk_2', 'm1_junk_1']);
  });
  const states = collect(f, 'game:gostop:state');
  const played = await f.call(0, 'game:gostop:play', { cardId: 'm8_junk_2' });
  assert.equal(played.ok, true);
  assert.equal(played.phase, 'choice');
  await flush();
  assert.equal(states[0].at(-1).pending.kind, 'hand');
  assert.deepEqual(states[1].at(-1).pending.options.map(c => c.id).sort(), ['m8_bright', 'm8_junk_1']);
  assert.equal((await f.call(1, 'game:gostop:choose', { cardId: 'm8_junk_1' })).reason, 'not_your_turn');
  assert.equal((await f.call(0, 'game:gostop:choose', { cardId: 'm2_junk_1' })).reason, 'invalid_choice');
  assert.equal((await f.call(0, 'game:gostop:play', { cardId: 'm1_junk_1' })).reason, 'invalid_phase');
  assert.equal((await f.call(0, 'game:gostop:choose', { cardId: 'm8_junk_1' })).ok, true);
  const g = await readGame(f);
  assert.equal(g.phase, 'playing');
  assert.equal(g.current, B);
  assert.deepEqual(g.captures[A].map(c => c.id).sort(), ['m8_junk_1', 'm8_junk_2']);
});

test('rejections are codes, wrong-turn and wrong-card actions change nothing, payloads are validated', async t => {
  const f = await fixture(t);
  await startFromLobby(f);
  const before = await arrange(f, () => {});
  assert.equal((await f.call(1, 'game:gostop:play', { cardId: 'm10_junk_2' })).reason, 'not_your_turn');
  assert.equal((await f.call(0, 'game:gostop:play', { cardId: 'm9_bright' })).reason, 'card_not_in_hand');
  assert.equal((await f.call(0, 'game:gostop:play', {})).reason, 'invalid_payload');
  assert.equal((await f.call(0, 'game:gostop:bomb', { month: 13 })).reason, 'invalid_payload');
  assert.equal((await f.call(0, 'game:gostop:bomb', { month: 5 })).reason, 'cannot_bomb');
  assert.equal((await f.call(0, 'game:gostop:dotan', {})).reason, 'no_dotan');
  assert.equal((await f.call(0, 'game:gostop:decide', { decision: 'go' })).reason, 'invalid_phase');
  assert.equal((await f.call(0, 'game:gostop:decide', { decision: 'maybe' })).reason, 'invalid_payload');
  assert.equal((await f.call(0, 'game:gostop:play', { cardId: 'm10_junk_1', shake: true })).reason, 'cannot_shake');
  const after = await readGame(f);
  assert.deepEqual(after.hands, before.hands);
  assert.equal(after.current, A);
});

test('deadline passes at go/stop → the server stops: one settlement, receipt total equals the real transfer', async t => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 2_000_000 });
  const wallet = installWallet(t);
  const ended = collect(f, 'game:gostop:ended');
  const wallets = collect(f, 'wallet:updated');
  const g0 = await startFromLobby(f, { stake: 100 });
  await arrange(f, g => {
    g.phase = 'go_stop';
    g.current = A;
    g.captures[A] = cards(SEVEN);
    g.captures[B] = cards(['m11_bright']);
    g.goCount[B] = 0;
  });
  f.tick(COUNTDOWN_MS + TURN_MS - 1);
  await flush();
  assert.equal((await readGame(f)).phase, 'go_stop', 'nothing before the deadline');
  f.tick(1);
  await flush();
  assert.equal(ended[0].length, 1);
  assert.equal(ended[1].length, 1);
  const e = ended[0][0];
  assert.equal(e.winner, A, 'the one who was thinking about go/stop wins, never loses to the timer');
  assert.equal(e.reason, 'stop');
  const r = e.receipt;
  assert.equal(r.auto, true, 'the receipt says the server stopped for them');
  assert.equal(r.points.total, 7);
  assert.equal(r.multiplier, 1, 'B holds a 광, so no 광박');
  assert.equal(r.amount, 700);
  assert.equal(r.transferred, 700);
  assert.equal(r.settlement, 'settled');
  assert.equal(wallet.balances[11], 10700);
  assert.equal(wallet.balances[22], 9300);
  assert.equal(wallet.transfers.length, 2, 'one winner row and one loser row');
  assert.ok(wallet.transfers.every(x => x.ref === `gostop:${g0.gameId}`));
  assert.equal(wallets[0].length, 1);
  assert.equal(f.results.length, 1, 'recorded once');
  assert.equal(await f.redis.get(gameKey(f)), null);
  assert.equal((await f.call(1, 'game:gostop:play', { cardId: 'm10_junk_2' })).reason, 'no_game');
  assert.equal(e.series.wins[A], 1);
  assert.ok(await f.redis.get(`gostop:${f.roomCode}:last`));
});

test('the receipt is capped by what the loser can pay: transferred < amount', async t => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 2_000_000 });
  const wallet = installWallet(t, { balances: { 11: 10000, 22: 300 } });
  const ended = collect(f, 'game:gostop:ended');
  await startFromLobby(f, { stake: 100 });
  await arrange(f, g => {
    g.phase = 'go_stop';
    g.current = A;
    g.captures[A] = cards(SEVEN);
    g.captures[B] = cards(['m11_bright']);
  });
  f.tick(COUNTDOWN_MS + TURN_MS);
  await flush();
  const r = ended[0][0].receipt;
  assert.equal(r.amount, 700);
  assert.equal(r.transferred, 300);
  assert.equal(r.settlement, 'capped');
  assert.equal(wallet.balances[22], 0);
});

test('three automatic turns in a row forfeit, paid by the real score and multipliers (not a flat 7)', async t => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 3_000_000 });
  const wallet = installWallet(t);
  const ended = collect(f, 'game:gostop:ended');
  await startFromLobby(f, { stake: 100 });
  await arrange(f, g => {
    g.current = B;
    g.captures[A] = cards(['m1_bright', 'm3_bright', 'm8_bright']);
    g.captures[B] = [];
    g.autoStreak = { [A]: 0, [B]: 2 };
  });
  f.tick(COUNTDOWN_MS + TURN_MS);
  await flush();
  assert.equal(ended[0].length, 1);
  const e = ended[0][0];
  assert.equal(e.reason, 'forfeit');
  assert.equal(e.winner, A);
  assert.equal(e.receipt.points.total, 3);
  assert.deepEqual(e.receipt.multipliers.map(m => m.code), ['gwangbak']);
  assert.equal(e.receipt.amount, 3 * 2 * 100);
  assert.equal(e.receipt.transferred, 600);
  assert.equal(wallet.balances[11], 10600);
  assert.equal(f.results.length, 1);
});

test('an automatic turn plays the coach card without shaking, keeps the game going, and restarts the 25 s clock', async t => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 4_000_000 });
  await startFromLobby(f);
  await arrange(f, g => {
    g.current = A;
    g.field = cards(['m3_bright']);
    g.hands[A] = cards(['m4_animal', 'm4_ribbon', 'm4_junk_1', 'm3_junk_1']);
    g.hands[B] = cards(['m10_junk_2', 'm11_junk_2']);
  });
  f.tick(COUNTDOWN_MS + TURN_MS);
  await flush();
  const g = await readGame(f);
  assert.equal(g.lastTurn.auto, true);
  assert.equal(g.lastTurn.played.id, 'm3_junk_1', 'takes the 광');
  assert.deepEqual(g.shakes[A], []);
  assert.equal(g.autoStreak[A], 1);
  assert.equal(g.current, B);
  assert.equal(g.turnDeadline, Date.now() + TURN_MS);
});

test('a hand action resets the automatic streak', async t => {
  const f = await fixture(t);
  await startFromLobby(f);
  await arrange(f, g => { g.autoStreak = { [A]: 2, [B]: 0 }; });
  assert.equal((await f.call(0, 'game:gostop:play', { cardId: 'm10_junk_1' })).ok, true);
  assert.equal((await readGame(f)).autoStreak[A], 0);
});

test('go is not forfeited by the idle watcher: waitingOn is null while a player decides go/stop', async t => {
  const f = await fixture(t);
  await startFromLobby(f);
  const mod = (await import('../src/games/gostop.js')).default;
  const adapter = mod.afk({});
  const g = await arrange(f, x => { x.phase = 'go_stop'; });
  assert.equal(adapter.waitingOn(g), null);
  const p = await arrange(f, x => { x.phase = 'playing'; x.current = B; });
  assert.equal(adapter.waitingOn(p), B);
});

test('AFK watcher: an idle game whose own timer is gone forfeits through the same finish path', async t => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 5_000_000 });
  installWallet(t);
  const ended = collect(f, 'game:gostop:ended');
  const warnings = [];
  f.clients[1].on('game:afk:warning', e => warnings.push(e));
  await startFromLobby(f, { stake: 100 });
  const g = await arrange(f, x => { x.current = B; x.turnDeadline = Date.now() + 3_600_000; });
  await f.call(0, 'game:gostop:sync', {});
  await flush();
  f.tick(60_000);
  await flush();
  assert.equal(warnings.length, 1);
  f.tick(30_000);
  await flush();
  assert.equal(ended[0].length, 1);
  assert.equal(ended[0][0].reason, 'forfeit');
  assert.equal(ended[0][0].winner, A);
  assert.equal(g.current, B);
  assert.equal(f.results.length, 1);
  assert.equal(await f.redis.get(gameKey(f)), null);
});

test('stop by hand: ended once, the finished game refuses every later action', async t => {
  const f = await fixture(t);
  installWallet(t);
  const ended = collect(f, 'game:gostop:ended');
  await startFromLobby(f, { stake: 100 });
  await arrange(f, g => {
    g.phase = 'go_stop';
    g.current = B;
    g.captures[B] = cards(SEVEN);
    g.captures[A] = cards(['m11_bright']);
    g.goCount[B] = 2;
  });
  assert.equal((await f.call(0, 'game:gostop:decide', { decision: 'stop' })).reason, 'not_your_turn');
  assert.equal((await f.call(1, 'game:gostop:decide', { decision: 'stop' })).ok, true);
  await flush();
  assert.equal(ended[0].length, 1);
  const r = ended[0][0].receipt;
  assert.equal(r.points.go, 2);
  assert.equal(r.points.total, 9, '7 + 2고');
  assert.equal(r.amount, 900);
  assert.equal(ended[0][0].goCount[B], 2);
  for (const [event, payload] of [
    ['game:gostop:play', { cardId: 'm10_junk_2' }],
    ['game:gostop:decide', { decision: 'stop' }],
    ['game:gostop:choose', { cardId: 'x' }],
    ['game:gostop:bomb', { month: 3 }],
    ['game:gostop:dotan', {}],
    ['game:gostop:chongtong', { declare: true }],
    ['game:gostop:sync', {}],
  ]) {
    const reason = (await f.call(0, event, payload)).reason;
    assert.ok(['no_game', 'game_over'].includes(reason), `${event}: ${reason}`);
  }
  assert.equal(f.results.length, 1);
});

test('나가리 ends the game with no coin movement and a receipt', async t => {
  const f = await fixture(t);
  const wallet = installWallet(t);
  const ended = collect(f, 'game:gostop:ended');
  await startFromLobby(f, { stake: 100 });
  await arrange(f, g => {
    g.current = A;
    g.field = cards(['m12_junk_d']);
    g.hands[A] = cards(['m4_junk_1']);
    g.hands[B] = [];
    g.deck = cards(['m7_junk_1']);
  });
  assert.equal((await f.call(0, 'game:gostop:play', { cardId: 'm4_junk_1' })).ok, true);
  await flush();
  assert.equal(ended[0][0].reason, 'nagari');
  assert.equal(ended[0][0].winner, null);
  assert.equal(ended[0][0].receipt.amount, 0);
  assert.equal(wallet.transfers.length, 0);
  assert.equal(f.results.length, 1, 'a draw is recorded once');
  assert.equal(await f.redis.get(gameKey(f)), null);
});

test('a wallet failure still ends the game, announces it, and reports transferred 0', async t => {
  const f = await fixture(t);
  installWallet(t, { failTransfer: true });
  const ended = collect(f, 'game:gostop:ended');
  const failed = collect(f, 'wallet:settle_failed');
  await startFromLobby(f, { stake: 100 });
  await arrange(f, g => {
    g.phase = 'go_stop';
    g.current = A;
    g.captures[A] = cards(SEVEN);
  });
  assert.equal((await f.call(0, 'game:gostop:decide', { decision: 'stop' })).ok, true);
  await flush();
  assert.equal(ended[0].length, 1);
  assert.equal(ended[0][0].receipt.transferred, 0);
  assert.equal(ended[0][0].receipt.settlement, 'failed');
  assert.equal(failed[0].length >= 1, true);
  assert.equal(await f.redis.get(gameKey(f)), null, 'the finished state never blocks a new game');
  assert.ok(await f.redis.get(`gostop:${f.roomCode}:last`));
});

test('consent rematch: the winner leads, stake and series carry over, a new game id is used', async t => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 6_000_000 });
  installWallet(t);
  const original = gostopRuntime.random;
  gostopRuntime.random = () => 0;
  t.after(() => { gostopRuntime.random = original; });
  const ended = collect(f, 'game:gostop:ended');
  const first = await startFromLobby(f, { stake: 100 });
  assert.equal(first.starter, A, 'random() = 0 picks the first player');
  gostopRuntime.random = original;

  // B wins the first game → B leads the rematch.
  await arrange(f, g => {
    g.phase = 'go_stop';
    g.current = B;
    g.captures[B] = cards(SEVEN);
    g.captures[A] = cards(['m11_bright']);
  });
  assert.equal((await f.call(1, 'game:gostop:decide', { decision: 'stop' })).ok, true);
  await flush();
  assert.equal(ended[0].length, 1);

  assert.equal((await f.call(0, 'game:restart:request', { gameType: 'gostop' })).ok, true);
  assert.equal((await f.call(1, 'game:restart:respond', { gameType: 'gostop', accept: true })).ok, true);
  await flush();
  const second = await readGame(f);
  assert.equal(second.starter, B);
  assert.notEqual(second.gameId, first.gameId);
  assert.equal(second.perPointBet, 100);
  assert.equal(second.series.games, 1);
  assert.equal(second.series.wins[B], 1);
  assert.ok(second.turnDeadline > Date.now());
});

test('a staked game in progress cannot be overwritten by a rematch (no stake escape)', async t => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 7_000_000 });
  const before = await startFromLobby(f, { stake: 500 });
  const declined = collect(f, 'game:restart:declined');
  assert.equal((await f.call(1, 'game:restart:request', { gameType: 'gostop' })).ok, true);
  const answer = await f.call(0, 'game:restart:respond', { gameType: 'gostop', accept: true });
  assert.equal(answer.ok, false);
  assert.equal(answer.reason, 'game_in_progress');
  await flush();
  assert.equal(declined[1][0]?.reason, 'game_in_progress');
  assert.equal((await readGame(f)).gameId, before.gameId);
});

test('restore re-sends the private view and joins the viewer room', async t => {
  const f = await fixture(t);
  await startFromLobby(f);
  await arrange(f, g => { delete g.turnDeadline; });
  const states = collect(f, 'game:gostop:state');
  const restored = await f.call(1, 'session:restore', {});
  await flush();
  assert.ok(restored.restored.includes('gostop'));
  const view = states[1].at(-1);
  assert.deepEqual(view.players, [A, B]);
  assert.equal(view.hand.length, 2);
  assert.ok(view.turnDeadline > 0, 'a restored game without a deadline gets a fresh one');
});

test('an old 1.x state in Redis is discarded instead of crashing the new engine', async t => {
  const f = await fixture(t);
  await f.redis.set(gameKey(f), JSON.stringify({ phase: 'playing', players: [A, B], currentPlayerIdx: 0 }), 'EX', 3600);
  assert.equal((await f.call(0, 'game:gostop:sync', {})).reason, 'no_game');
  assert.equal(await f.redis.get(gameKey(f)), null);
});
