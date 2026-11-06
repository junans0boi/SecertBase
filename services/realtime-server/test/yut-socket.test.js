// 윷놀이 2.0 소켓 흐름(티켓 21): 서버 시작·캐릭터 유지·30초 마감 자동 행동·끝난 판 거부·정산 예외·재대결·복원.
import assert from 'node:assert/strict';
import test from 'node:test';
import { boundary, fixture, flush } from './support/socket-harness.js';
// Loaded after the harness so the module shares its memory DB/Redis boundaries.
const { yutRuntime, TURN_MS } = await import('../src/games/yut.js');

const A = 'ALPHA-code';
const B = 'BETA-code';
const COUNTDOWN_MS = 5300;
const gameKey = f => `yut:${f.roomCode}:game`;
const lastKey = f => `yut:${f.roomCode}:last`;
const readGame = async f => JSON.parse(await f.redis.get(gameKey(f)));
const writeGame = (f, g) => f.redis.set(gameKey(f), JSON.stringify(g), 'EX', 3600);
const queue = values => { let i = 0; return () => values[i++] ?? 0.99; };

async function startFromLobby(f, { stake = 0, pieces = null, characters = null } = {}) {
  await f.call(0, 'game:lobby:join', { gameType: 'yut' });
  await f.call(1, 'game:lobby:join', { gameType: 'yut' });
  if (characters) {
    assert.equal((await f.call(0, 'game:lobby:select_character', { gameType: 'yut', character: characters[0] })).ok, true);
    assert.equal((await f.call(1, 'game:lobby:select_character', { gameType: 'yut', character: characters[1] })).ok, true);
  }
  if (stake) assert.equal((await f.call(0, 'game:lobby:set_stake', { gameType: 'yut', stake })).ok, true);
  if (pieces) assert.equal((await f.call(0, 'game:lobby:set_option', { gameType: 'yut', key: 'pieces', value: pieces })).ok, true);
  if (stake) assert.equal((await f.call(1, 'game:lobby:ready', { gameType: 'yut', ready: true })).ok, true);
  assert.equal((await f.call(0, 'game:lobby:start', { gameType: 'yut' })).ok, true);
  await flush();
  return readGame(f);
}

async function arrange(f, fn) {
  const g = await readGame(f);
  fn(g);
  await writeGame(f, g);
  return g;
}

function collect(f, event) {
  const seen = [[], []];
  f.clients.forEach((c, i) => c.on(event, e => seen[i].push(e)));
  return seen;
}

const indexOf = player => (player === A ? 0 : 1);

test('lobby start creates the game on the server with lobby characters, bgm, pieces and a first deadline', async t => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 1_000_000 });
  const g = await startFromLobby(f, { pieces: 3, characters: ['nolbu', 'miho'] });
  assert.equal(g.pieceCount, 3);
  assert.equal(g.players[A].pieces.length, 3);
  assert.deepEqual(g.characters, { [A]: 'nolbu', [B]: 'miho' });
  assert.match(g.bgm, /^yut[123]\.mp3$/);
  assert.ok([A, B].includes(g.currentTurn));
  assert.equal(g.phase, 'throwing');
  assert.equal(g.turnDeadline, 1_000_000 + COUNTDOWN_MS + TURN_MS);
  const sync = await f.call(1, 'game:yut:sync', {});
  assert.equal(sync.ok, true);
  assert.equal(sync.state.serverNow, 1_000_000);
  assert.deepEqual(sync.state.players, [A, B]);
  assert.equal(sync.state.canThrow, true);
  assert.deepEqual(sync.state.legalMoves, []);
  assert.equal(sync.state.characters[B], 'miho');
});

test('the first player is random', async t => {
  const seen = new Set();
  for (let i = 0; i < 2; i++) {
    const f = await fixture(t);
    yutRuntime.random = () => i; // 0 → player 1, 1 → player 2
    t.after(() => { yutRuntime.random = Math.random; });
    seen.add((await startFromLobby(f)).currentTurn);
  }
  assert.deepEqual([...seen].sort(), [A, B]);
});

test('throw and move: only the current player, server legal moves, sticks match the result', async t => {
  const f = await fixture(t);
  const g0 = await startFromLobby(f);
  const me = g0.currentTurn;
  const other = me === A ? B : A;
  assert.equal((await f.call(indexOf(other), 'game:yut:throw', {})).reason, 'not_your_turn');
  assert.equal((await f.call(indexOf(me), 'game:yut:move', { pieceId: 0 })).reason, 'must_throw_first');
  const sticks = collect(f, 'game:yut:state');
  const thrown = await f.call(indexOf(me), 'game:yut:throw', {});
  assert.equal(thrown.ok, true);
  const names = { 1: '도', 2: '개', 3: '걸', 4: '윷', 5: '모', '-1': '빽도' };
  assert.equal(thrown.throw.resultName, names[thrown.throw.result]);
  assert.equal(thrown.throw.sticks.length, 4);
  await flush();
  const view = sticks[indexOf(other)].at(-1);
  assert.equal(view.lastAction.type === 'throw' || view.lastAction.type === 'start', true);
  const afterThrow = await readGame(f);
  if (afterThrow.currentTurn === me && afterThrow.pendingMoves.length) {
    assert.equal((await f.call(indexOf(me), 'game:yut:throw', {})).ok, afterThrow.hasBonusThrow);
    assert.equal((await f.call(indexOf(me), 'game:yut:move', { pieceId: 9 })).reason, 'invalid_move');
    assert.equal((await f.call(indexOf(me), 'game:yut:move', { pieceId: 'x' })).reason, 'invalid_payload');
  }
});

test('a move must be one of the server legal moves and advances the turn state', async t => {
  const f = await startFixtureWith(t);
  const { me, other } = f;
  await arrange(f, g => { g.currentTurn = me; g.phase = 'moving'; g.pendingMoves = [2]; g.players[me].pieces[0] = { id: 0, position: 3, lastPos: 2, finished: false }; });
  assert.equal((await f.call(indexOf(other), 'game:yut:move', { pieceId: 0 })).reason, 'not_your_turn');
  assert.equal((await f.call(indexOf(me), 'game:yut:move', { pieceId: 0, moveIndex: 3 })).reason, 'invalid_move');
  const moved = await f.call(indexOf(me), 'game:yut:move', { pieceId: 0 });
  assert.equal(moved.ok, true);
  const g = await readGame(f);
  assert.equal(g.players[me].pieces[0].position, 5);
  assert.equal(g.currentTurn, other, 'turn passes when nothing is left to play');
  assert.deepEqual(g.lastAction.move.path, [3, 4, 5]);
});

async function startFixtureWith(t, opts) {
  const f = await fixture(t);
  const g = await startFromLobby(f, opts);
  f.me = g.currentTurn;
  f.other = f.me === A ? B : A;
  return f;
}

test('the deadline auto-throws and auto-moves, and three automatic turns in a row forfeit', async t => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 1_000_000 });
  const ended = collect(f, 'game:yut:ended');
  yutRuntime.random = queue([0.1, 0.1, 0.99, 0.99]);
  t.after(() => { yutRuntime.random = Math.random; });
  const g0 = await startFromLobby(f);
  yutRuntime.random = () => 0.99;
  const idle = g0.currentTurn;
  const active = idle === A ? B : A;
  // 첫 마감: 자동 던지기 + 자동 이동 → 차례 교대
  const states = collect(f, 'game:yut:state');
  f.tick(COUNTDOWN_MS + TURN_MS);
  await flush();
  const g1 = await readGame(f);
  assert.equal(g1.autoStreak[idle], 1);
  assert.ok(states[0].some(s => s.lastAction.auto === true), 'automatic actions are flagged');
  assert.equal(g1.turnDeadline, Date.now() + TURN_MS, 'deadline restarts');
  // 자동 이동이 끝나면 상대 차례(모=보너스 던지기면 같은 사람이 이어 던진다)
  assert.ok([idle, active].includes(g1.currentTurn));
  // 한 사람이 계속 자동이면 3번째에 기권패
  await arrange(f, g => { g.currentTurn = idle; g.phase = 'throwing'; g.pendingMoves = []; g.autoStreak = { [idle]: 2 }; });
  const g2 = await readGame(f);
  f.tick(Math.max(0, g2.turnDeadline - Date.now()));
  await flush();
  assert.equal(ended[0].length, 1);
  assert.equal(ended[0][0].winner, active);
  assert.equal(ended[0][0].reason, 'forfeit');
  assert.equal(await f.redis.get(gameKey(f)), null);
});

test('a manual action clears the automatic streak', async t => {
  const f = await startFixtureWith(t);
  await arrange(f, g => { g.autoStreak = { [f.me]: 2 }; });
  assert.equal((await f.call(indexOf(f.me), 'game:yut:throw', {})).ok, true);
  assert.equal((await readGame(f)).autoStreak[f.me], 0);
});

test('every yut action rejects with game_over once a winner exists', async t => {
  const f = await startFixtureWith(t);
  await arrange(f, g => { g.winner = f.me; });
  for (const [event, payload] of [['game:yut:throw', {}], ['game:yut:move', { pieceId: 0 }], ['game:yut:sync', {}]]) {
    assert.equal((await f.call(indexOf(f.other), event, payload)).reason, 'game_over', event);
    assert.equal((await f.call(indexOf(f.me), event, payload)).reason, 'game_over', event);
  }
});

test('the last piece home finishes once: ended carries the series and coin bonus, state is deleted', async t => {
  const f = await fixture(t);
  const ended = collect(f, 'game:yut:ended');
  const g0 = await startFromLobby(f, { stake: 1000, pieces: 2 });
  const me = g0.currentTurn;
  await arrange(f, g => {
    g.phase = 'moving';
    g.pendingMoves = [2];
    g.coinBonus = { [me]: 120 };
    g.players[me].pieces[0] = { id: 0, position: 20, lastPos: 20, finished: true };
    g.players[me].pieces[1] = { id: 1, position: 19, lastPos: 18, finished: false };
  });
  const moved = await f.call(indexOf(me), 'game:yut:move', { pieceId: 1 });
  assert.equal(moved.ok, true);
  assert.equal(moved.won, true);
  await flush();
  assert.equal(ended[1].length, 1);
  assert.equal(ended[1][0].winner, me);
  assert.equal(ended[1][0].reason, 'goal');
  assert.equal(ended[1][0].coinBonus, 120);
  assert.equal(ended[1][0].series.wins[me], 1);
  assert.equal(f.results.length, 1, 'recorded once');
  assert.equal(await f.redis.get(gameKey(f)), null);
  assert.equal((await f.call(indexOf(me), 'game:yut:throw', {})).reason, 'no_game');
});

test('a settlement exception still deletes the finished state and announces the end', async t => {
  const f = await fixture(t);
  const ended = collect(f, 'game:yut:ended');
  const g0 = await startFromLobby(f, { pieces: 2 });
  const me = g0.currentTurn;
  await arrange(f, g => {
    g.phase = 'moving';
    g.pendingMoves = [1];
    g.players[me].pieces[0] = { id: 0, position: 20, lastPos: 20, finished: true };
    g.players[me].pieces[1] = { id: 1, position: 20, lastPos: 19, finished: false };
  });
  const base = boundary.query;
  boundary.query = async (sql, params) => {
    if (sql.includes('SELECT UserId FROM Users WHERE UserCode')) throw new Error('db down');
    return base(sql, params);
  };
  t.after(() => { boundary.query = base; });
  assert.equal((await f.call(indexOf(me), 'game:yut:move', { pieceId: 1 })).ok, true);
  await flush();
  assert.equal(await f.redis.get(gameKey(f)), null, 'the finished game must not block a new one');
  assert.equal(ended[0].length, 1);
  assert.equal(ended[0][0].winner, me);
  assert.ok(await f.redis.get(lastKey(f)), 'the rematch summary is kept');
});

test('consent rematch keeps stake, characters, bgm, piece count and series, and swaps the starter', async t => {
  const f = await fixture(t);
  const g0 = await startFromLobby(f, { stake: 100, pieces: 3, characters: ['miho', 'nolbu'] });
  const first = g0.currentTurn;
  await arrange(f, g => {
    g.phase = 'moving';
    g.pendingMoves = [1];
    for (const p of g.players[first].pieces.slice(0, 2)) Object.assign(p, { position: 20, lastPos: 20, finished: true });
    Object.assign(g.players[first].pieces[2], { position: 20, lastPos: 19, finished: false });
  });
  assert.equal((await f.call(indexOf(first), 'game:yut:move', { pieceId: 2 })).won, true);
  await flush();
  assert.equal(await f.redis.get(gameKey(f)), null);
  assert.equal((await f.call(indexOf(first), 'game:restart:request', { gameType: 'yut' })).ok, true);
  const accepted = await f.call(indexOf(first) ^ 1, 'game:restart:respond', { gameType: 'yut', accept: true });
  assert.equal(accepted.accepted, true);
  const g1 = await readGame(f);
  assert.notEqual(g1.gameId, g0.gameId);
  assert.equal(g1.stake, 100);
  assert.equal(g1.pieceCount, 3);
  assert.deepEqual(g1.characters, g0.characters);
  assert.equal(g1.bgm, g0.bgm);
  assert.equal(g1.series.games, 1);
  assert.notEqual(g1.currentTurn, first, 'the starter alternates');
  assert.equal(g1.phase, 'throwing');
  assert.ok(Math.abs(g1.turnDeadline - (Date.now() + TURN_MS)) < 2000, 'a fresh 30 second deadline');
});

test('a rematch is refused while a staked game is still running, and forged responses are ignored', async t => {
  const f = await startFixtureWith(t, { stake: 100 });
  const before = await readGame(f);
  assert.equal((await f.call(1, 'game:restart:respond', { gameType: 'yut', accept: true })).reason, 'no_restart_request');
  assert.equal((await f.call(0, 'game:restart:request', { gameType: 'yut' })).ok, true);
  const refused = await f.call(1, 'game:restart:respond', { gameType: 'yut', accept: true });
  assert.equal(refused.ok, false);
  assert.equal(refused.reason, 'game_in_progress');
  assert.equal((await readGame(f)).gameId, before.gameId);
});

test('session:restore resends a running game but not a finished one', async t => {
  const f = await startFixtureWith(t);
  const running = await f.call(0, 'session:restore', {});
  assert.ok(running.restored.includes('yut'));
  await arrange(f, g => { g.winner = f.me; });
  const finished = await f.call(0, 'session:restore', {});
  assert.equal(finished.restored.includes('yut'), false);
});

test('a stale timer from a replaced game does nothing', async t => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 1_000_000 });
  await startFromLobby(f);
  await arrange(f, g => { g.gameId = 'replaced'; });
  f.tick(COUNTDOWN_MS + TURN_MS + 10);
  await flush();
  const g = await readGame(f);
  assert.equal(g.autoStreak, undefined);
  assert.equal(g.seq, 1);
});
