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

// ── 정산 영수증: 화면은 실제로 옮겨진 코인만 말한다 ────────────────────────────────
/** 메모리 지갑: transferGameReward가 쓰는 SQL만 흉내 낸다. */
function installWallet(t, { balances = { 11: 10000, 22: 10000 }, failTransfer = false, failLookup = false } = {}) {
  const baseQuery = boundary.query;
  const baseTx = boundary.transaction;
  const wallet = { balances: { ...balances }, transfers: [], refs: new Set() };
  boundary.query = async (sql, params) => {
    if (sql.includes('SELECT UserId FROM Users WHERE UserCode')) {
      if (failLookup && sql.includes('LIMIT 1')) throw new Error('lookup down');
      return { rows: [{ UserId: params[0] === A ? 11 : 22 }] };
    }
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

/** 이기는 마지막 한 수만 남긴 판돈 판을 만들고 그 수를 둔다. */
async function winOnLastMove(t, { stake, balances, coinBonus = 0, ...walletOpts }) {
  const f = await fixture(t);
  const wallet = installWallet(t, { balances, ...walletOpts });
  const ended = collect(f, 'game:yut:ended');
  const failed = collect(f, 'wallet:settle_failed');
  const g0 = await startFromLobby(f, { stake, pieces: 2 });
  const me = g0.currentTurn;
  await arrange(f, g => {
    g.phase = 'moving';
    g.pendingMoves = [1];
    g.coinBonus = coinBonus ? { [me]: coinBonus } : {};
    g.players[me].pieces[0] = { id: 0, position: 20, lastPos: 20, finished: true };
    g.players[me].pieces[1] = { id: 1, position: 20, lastPos: 19, finished: false };
  });
  assert.equal((await f.call(indexOf(me), 'game:yut:move', { pieceId: 1 })).ok, true);
  await flush();
  return { f, wallet, me, other: me === A ? B : A, ended: ended[0][0] ?? ended[1][0], failed: [...failed[0], ...failed[1]] };
}

test('the ended receipt carries the coins that really moved when the loser can pay in full', async t => {
  const r = await winOnLastMove(t, { stake: 1000, coinBonus: 120 });
  assert.equal(r.ended.settlement, 'settled');
  assert.equal(r.ended.transferred, 1000);
  assert.equal(r.ended.winnerGain, 1120);
  assert.equal(r.wallet.transfers.length, 2, 'exactly one settlement');
  const winnerTx = r.wallet.transfers.find(x => x.user === (r.me === A ? 11 : 22));
  assert.equal(winnerTx.delta, r.ended.winnerGain);
  assert.equal(winnerTx.ref, `yut:${r.ended.gameId}`);
});

test('an all-in loser pays only what they have: the receipt says capped and shows the real amount', async t => {
  // 지는 쪽은 첫 순서(무작위)에 달렸으니 둘 다 300으로 맞춘다.
  const r = await winOnLastMove(t, { stake: 1000, balances: { 11: 300, 22: 300 }, coinBonus: 50 });
  assert.equal(r.ended.settlement, 'capped');
  assert.equal(r.ended.transferred, 300);
  assert.equal(r.ended.winnerGain, 350);
  assert.equal(r.ended.stake, 1000, 'the agreed stake stays visible; the receipt is separate');
});

test('a wallet failure is reported as failed with nothing transferred, and the game still ends once', async t => {
  const r = await winOnLastMove(t, { stake: 500, failTransfer: true });
  assert.equal(r.ended.settlement, 'failed');
  assert.equal(r.ended.transferred, 0);
  assert.equal(r.ended.winnerGain, 0);
  assert.equal(r.failed.length > 0, true, 'wallet:settle_failed is announced');
  assert.equal(r.wallet.transfers.length, 0);
  assert.equal(await r.f.redis.get(gameKey(r.f)), null);
});

test('free games have no settlement and a failing user lookup does not stop a staked settlement', async t => {
  const free = await winOnLastMove(t, { stake: 0 });
  assert.equal(free.ended.settlement, 'none');
  assert.equal(free.ended.transferred, 0);
  const staked = await winOnLastMove(t, { stake: 500, failLookup: true });
  assert.equal(staked.ended.settlement, 'settled', 'the coin transfer resolves users by code itself');
  assert.equal(staked.ended.transferred, 500);
  assert.equal(staked.f.results.length, 1, 'the result is still recorded');
});

test('lobby character picks are honoured, a taken character is refused, and an unpicked player gets a distinct fallback', async t => {
  const f = await fixture(t);
  await f.call(0, 'game:lobby:join', { gameType: 'yut' });
  await f.call(1, 'game:lobby:join', { gameType: 'yut' });
  assert.equal((await f.call(0, 'game:lobby:select_character', { gameType: 'yut', character: 'miho' })).ok, true);
  const taken = await f.call(1, 'game:lobby:select_character', { gameType: 'yut', character: 'miho' });
  assert.equal(taken.ok, false);
  assert.equal(taken.reason, 'character_taken');
  // 상대는 고르지 않고 시작: 겹치지 않는 다른 캐릭터가 배정된다.
  assert.equal((await f.call(0, 'game:lobby:start', { gameType: 'yut' })).ok, true);
  await flush();
  const g = await readGame(f);
  assert.equal(g.characters[A], 'miho');
  assert.notEqual(g.characters[B], 'miho');
  assert.ok(['honggilldong', 'nolbu'].includes(g.characters[B]));
});

test('assignCharacters never gives both players the same character', async () => {
  const { assignCharacters } = await import('../src/games/yut.js');
  for (const picks of [{}, { [A]: 'nolbu' }, { [B]: 'nolbu' }, { [A]: 'nolbu', [B]: 'nolbu' }, { [A]: 'bogus', [B]: 'miho' }]) {
    const out = assignCharacters([A, B], picks);
    assert.notEqual(out[A], out[B], JSON.stringify(picks));
    assert.ok(out[A] && out[B]);
  }
  // 지난 판 캐릭터를 이어받되 겹치면 한쪽을 바꾼다.
  const kept = assignCharacters([A, B], { [A]: 'miho' }, { [A]: 'nolbu', [B]: 'miho' });
  assert.equal(kept[A], 'miho');
  assert.notEqual(kept[B], 'miho');
});

test('game:yut:state carries both players yut skins, character stats and effective effects; stale piece skins are ignored', async t => {
  const f = await fixture(t);
  const base = boundary.query;
  const items = {
    11: [
      { slot: 'yut_piece', name: '호랑이 말', icon: '🐯', grade: 'A', stats: { piece_catch_resist_pct: 15 } },
      { slot: 'yut_yut', name: '얼음 윷', icon: '🧊', grade: 'S', stats: { piece_catch_resist_pct: 4 } },
    ],
    22: [{ slot: 'yut_yut', name: '신들의 윷', icon: '✨', grade: 'SSS', stats: { yut_control_pct: 1.2 } }],
  };
  boundary.query = async (sql, params) => {
    if (sql.includes('SELECT UserId FROM Users WHERE UserCode')) return { rows: [{ UserId: params[0] === A ? 11 : 22 }] };
    if (sql.includes('JOIN shop_items si ON si.id = ei.item_id')) return { rows: items[params[0]] ?? [] };
    return base(sql, params);
  };
  t.after(() => { boundary.query = base; });
  await startFromLobby(f, { stake: 100, characters: ['honggilldong', 'nolbu'] });
  const view = (await f.call(0, 'game:yut:sync', {})).state;
  assert.equal(view.equippedItems[A].yut_yut.name, '얼음 윷');
  assert.equal(view.equippedItems[A].yut_piece, undefined, 'piece skins no longer exist');
  assert.equal(view.equippedItems[B].yut_yut.name, '신들의 윷', "the opponent's skin is visible too");
  assert.deepEqual(view.characterStats[A], { power: 3, calm: 4, guard: 4, luck: 2, momentum: 2 });
  assert.deepEqual(view.characterStats[B], { power: 5, calm: 1, guard: 3, luck: 3, momentum: 3 });
  // 효과 = 캐릭터 능력치 + 윷 스킨(상한 적용). 홍길동 방어 4.5 + 얼음 4 = 8.5, 말 스킨의 15는 무시.
  assert.equal(view.effects[A].defensePct, 8.5);
  assert.equal(view.effects[A].calmPct, 12);
  assert.ok(view.effects[B].controlPct > 1.2 && view.effects[B].controlPct <= 2.5);
});
