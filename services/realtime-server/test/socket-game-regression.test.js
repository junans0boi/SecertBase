import assert from 'node:assert/strict';
import test from 'node:test';
import {
  boundary,
  createMarbleGameState,
  createYutGameState,
  fixture,
  flush,
  getUserLevel,
} from './support/socket-harness.js';

test('legacy RPS still discards an unanswered choice after 60 seconds', async t => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 100_000 });
  await f.call(0, 'game:rps:select', { choice: 'rock' });
  f.tick(60_001);
  const late = await f.call(1, 'game:rps:select', { choice: 'paper' });
  assert.equal(late.waiting, true, 'RPS keeps its own 60 second lifetime');
});

test('lobby invite uses JWT numeric identity and supplies the game and room destination', async t => {
  const f = await fixture(t, { players: 1 });
  assert.equal((await f.call(0, 'game:lobby:join', { gameType: 'rps' })).ok, true);
  await flush();
  assert.deepEqual(f.invites, [[11, 'game_invite', { game_type: 'rps', room_code: f.roomCode }]]);
});

test('a failed invite does not fail the lobby and reopening it can retry the notification', async t => {
  const f = await fixture(t, { players: 1 });
  let attempts = 0;
  boundary.notifyPartner = async () => { attempts++; return { sent: 0, skipped: 'error' }; };
  assert.equal((await f.call(0, 'game:lobby:join', { gameType: 'rps' })).ok, true);
  await flush();
  await f.call(0, 'game:lobby:leave', { gameType: 'rps' });
  assert.equal((await f.call(0, 'game:lobby:join', { gameType: 'rps' })).ok, true);
  await flush();
  assert.equal(attempts, 2);
});

test('rejected invite promises are caught and the successful retry is deduped for 60 seconds', async t => {
  const f = await fixture(t, { players: 1 });
  const logs = [];
  t.mock.method(console, 'error', (...args) => logs.push(args));
  let attempts = 0;
  boundary.notifyPartner = async () => {
    if (++attempts === 1) throw new Error('transport unavailable');
    return { sent: 1 };
  };
  await f.call(0, 'game:lobby:join', { gameType: 'rps' });
  await flush();
  assert.equal(logs.length, 1);
  await f.call(0, 'game:lobby:leave', { gameType: 'rps' });
  await f.call(0, 'game:lobby:join', { gameType: 'rps' });
  await flush();
  await f.call(0, 'game:lobby:leave', { gameType: 'rps' });
  await f.call(0, 'game:lobby:join', { gameType: 'rps' });
  await flush();
  assert.equal(attempts, 2, 'successful send must retain dedupe protection');
});

test('partners already present in the room do not receive an away-player invite', async t => {
  const f = await fixture(t);
  await f.call(0, 'game:lobby:join', { gameType: 'rps' });
  await flush();
  assert.equal(f.invites.length, 0);
});

test('session restore sends the bomb holder and elapsed timer from the real socket handler', async t => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 100_000 });
  await f.redis.set(`bomb:${f.roomCode}:game`, JSON.stringify({
    currentPlayer: 'BETA-code', duration: 30_000, startTime: 95_000,
    currentQuiz: { category: 'math' },
  }));
  const restored = await f.call(0, 'session:restore', {});
  assert.deepEqual(restored.activeGames.bomb, {
    currentPlayer: 'BETA-code', timer: 25, startTime: 95_000, duration: 30,
    category: 'math',
  });
});

test('marble state delivers server total assets including invested buildings', async t => {
  const f = await fixture(t);
  const state = createMarbleGameState('ALPHA-code', 'BETA-code');
  state.lands[1] = { owner: 'ALPHA-code', level: 2 };
  await f.redis.set(`marble:${f.roomCode}:game`, JSON.stringify(state));
  const restored = await f.call(0, 'session:restore', {});
  assert.deepEqual(restored.activeGames.marble.assets, { 'ALPHA-code': 5_700_000, 'BETA-code': 5_000_000 });
});

test('claiming the last tourist property emits the monopoly win reason through sockets', async t => {
  const f = await fixture(t);
  const state = createMarbleGameState('ALPHA-code', 'BETA-code');
  state.lands[8] = { owner: 'ALPHA-code', level: 0 };
  state.pendingLandAction = { userId: 'ALPHA-code', pos: 17, type: 'claim' };
  await f.redis.set(`marble:${f.roomCode}:game`, JSON.stringify(state));
  const ended = [];
  f.clients[0].on('game:marble:ended', event => ended.push(event));
  const claimed = await f.call(0, 'game:marble:land_act', { action: 'claim', pos: 17 });
  assert.equal(claimed.ok, true);
  await flush();
  assert.deepEqual(ended, [{ winner: 'ALPHA-code', winReason: 'tourist_monopoly', finalScores: null }]);
});

// 윷놀이 잡기 추가 던지기·복원 소켓 회귀는 test/yut-socket.test.js로 옮겼다(게임 2.0).

test('bowling completion grants winner/loser XP once through its socket handler', async t => {
  const f = await fixture(t);
  await f.redis.set(`game:${f.roomCode}:bowling`, JSON.stringify({
    status: 'playing', turn: 'BETA-code', seed: 1, history: [],
    rolls: { 'ALPHA-code': Array(20).fill(1), 'BETA-code': Array(19).fill(0) },
    scores: { 'ALPHA-code': 20, 'BETA-code': 0 }, result: null,
  }));
  assert.equal((await f.call(1, 'game:bowling:roll', { pins: 0 })).ok, true);
  await flush();
  assert.equal((await getUserLevel(11)).xp, 50);
  assert.equal((await getUserLevel(22)).xp, 20);
  assert.deepEqual(f.results, [[1, 'bowling', 'ALPHA-code', 'BETA-code', 0, 'ALPHA-code', 'BETA-code', null]]);
  assert.equal((await f.call(1, 'game:bowling:roll', { pins: 0 })).ok, false);
  assert.equal((await getUserLevel(11)).xp, 50);
});

// 패널티킥 XP·소켓 회귀는 test/penalty-socket.test.js로 옮겼다(게임 2.0).

// ── 게임 정비(#177): 재시작·판돈·준비·탱크 2.0·원카드·가위바위보 ─────────────

test('a forged restart response without a pending request cannot overwrite a running game', async t => {
  const f = await fixture(t);
  const state = createYutGameState('ALPHA-code', 'BETA-code');
  state.gameId = 'original';
  await f.redis.set(`yut:${f.roomCode}:game`, JSON.stringify(state));
  const forged = await f.call(1, 'game:restart:respond', { accept: true, gameType: 'yut' });
  assert.equal(forged.ok, false);
  assert.equal(forged.reason, 'no_restart_request');
  assert.equal(JSON.parse(await f.redis.get(`yut:${f.roomCode}:game`)).gameId, 'original');
});

test('only the partner can accept a restart request, which then restarts the game', async t => {
  const f = await fixture(t);
  const state = createYutGameState('ALPHA-code', 'BETA-code');
  state.gameId = 'original';
  await f.redis.set(`yut:${f.roomCode}:game`, JSON.stringify(state));
  assert.equal((await f.call(0, 'game:restart:request', { gameType: 'yut' })).ok, true);
  const self = await f.call(0, 'game:restart:respond', { accept: true, gameType: 'yut' });
  assert.equal(self.ok, false, 'the requester cannot accept their own request');
  const accepted = await f.call(1, 'game:restart:respond', { accept: true, gameType: 'yut' });
  assert.equal(accepted.accepted, true);
  assert.notEqual(JSON.parse(await f.redis.get(`yut:${f.roomCode}:game`)).gameId, 'original');
  assert.equal((await f.call(0, 'game:restart:request', { gameType: 'dice' })).reason, 'unsupported_game');
});

test('tank stake comes from the agreed lobby, never from the creation payload', async t => {
  const f = await fixture(t);
  await f.call(0, 'game:lobby:join', { gameType: 'tank' });
  await f.call(1, 'game:lobby:join', { gameType: 'tank' });
  assert.equal((await f.call(0, 'game:lobby:set_stake', { gameType: 'tank', stake: 1000 })).ok, true);
  const early = await f.call(0, 'game:lobby:start', { gameType: 'tank' });
  assert.equal(early.reason, 'partner_not_ready', 'a staked game needs the partner to agree');
  assert.equal((await f.call(1, 'game:lobby:ready', { gameType: 'tank', ready: true })).ok, true);
  assert.equal((await f.call(0, 'game:lobby:start', { gameType: 'tank' })).ok, true);
  assert.equal((await f.call(0, 'game:tank:new', { stake: 9999 })).ok, true);
  assert.equal(JSON.parse(await f.redis.get(`game:${f.roomCode}:tank`)).stake, 1000);
});

test('changing the stake resets the partner ready state; free games need no ready', async t => {
  const f = await fixture(t);
  await f.call(0, 'game:lobby:join', { gameType: 'uno' });
  await f.call(1, 'game:lobby:join', { gameType: 'uno' });
  await f.call(0, 'game:lobby:set_stake', { gameType: 'uno', stake: 500 });
  await f.call(1, 'game:lobby:ready', { gameType: 'uno', ready: true });
  await f.call(0, 'game:lobby:set_stake', { gameType: 'uno', stake: 3000 });
  assert.equal((await f.call(0, 'game:lobby:start', { gameType: 'uno' })).reason, 'partner_not_ready');
  await f.call(0, 'game:lobby:set_stake', { gameType: 'uno', stake: 0 });
  assert.equal((await f.call(0, 'game:lobby:start', { gameType: 'uno' })).ok, true);
});

test('games without stakes refuse a stake and a tank created outside the lobby is free', async t => {
  const f = await fixture(t);
  await f.call(0, 'game:lobby:join', { gameType: 'marble' });
  assert.equal((await f.call(0, 'game:lobby:set_stake', { gameType: 'marble', stake: 500 })).reason, 'stake_not_supported');
  assert.equal((await f.call(1, 'game:tank:new', { stake: 5000 })).ok, true);
  assert.equal(JSON.parse(await f.redis.get(`game:${f.roomCode}:tank`)).stake, 0);
});

test('tank 2.0: hidden class pick, masked aim and a fire that carries its own aim', async t => {
  const f = await fixture(t);
  const updates = [[], []];
  f.clients.forEach((c, i) => c.on('game:tank:updated', s => updates[i].push(s)));
  const shots = [];
  f.clients[1].on('game:tank:shot', s => shots.push(s));
  assert.equal((await f.call(0, 'game:tank:new', {})).ok, true);
  assert.equal((await f.call(0, 'game:tank:select', { tankClass: 'rhino' })).battleStarted, false);
  await flush();
  assert.equal(updates[1].at(-1).players[0].tankClass, null, 'partner cannot see my pick yet');
  assert.equal(updates[1].at(-1).players[0].classPicked, true);
  assert.equal((await f.call(1, 'game:tank:select', { tankClass: 'falcon' })).battleStarted, true);
  await flush();
  const battle = updates[1].at(-1);
  assert.equal(battle.phase, 'aiming');
  assert.equal(battle.players[0].tankClass, 'rhino');
  assert.equal(battle.players[0].angle, null, 'opponent aim is masked');
  assert.ok(battle.turnDeadline > 0);
  const fired = await f.call(0, 'game:tank:fire', { angle: 70, power: 42, weapon: 'basic' });
  assert.equal(fired.ok, true);
  await flush();
  assert.equal(shots.at(-1).angle, 70);
  assert.equal(shots.at(-1).power, 42);
  assert.equal(updates[1].at(-1).turn, 1);
  assert.equal(updates[1].at(-1).players[0].angle, null);
});

test('tank turn timer: three consecutive timeouts forfeit and record the result once', async t => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 1_000_000 });
  const ended = [];
  f.clients[0].on('game:tank:ended', e => ended.push(e));
  await f.call(0, 'game:tank:new', {});
  await f.call(0, 'game:tank:select', { tankClass: 'turtle' });
  await f.call(1, 'game:tank:select', { tankClass: 'turtle' });
  // ALPHA 시간 초과 → BETA 발사 → ALPHA 시간 초과 ×2 (연속 3회가 되려면 ALPHA 턴만 넘겨야 한다)
  for (let i = 0; i < 3; i++) {
    f.tick(30_001);
    await flush();
    if (i < 2) {
      assert.equal((await f.call(1, 'game:tank:fire', { angle: 90, power: 1 })).ok, true);
      await flush();
    }
  }
  assert.equal(ended.length, 1);
  assert.equal(ended[0].winner, 'BETA-code');
  assert.equal(ended[0].reason, 'afk');
  assert.equal(f.results.length, 1);
  assert.equal(await f.redis.get(`game:${f.roomCode}:tank`), null);
});

test('rps: any participant can reset and a finished match is recorded', async t => {
  const f = await fixture(t);
  assert.equal((await f.call(1, 'game:rps:start', { mode: 'single' })).ok, true);
  await f.call(0, 'game:rps:pick', { choice: 'rock' });
  await f.call(1, 'game:rps:pick', { choice: 'scissors' });
  await flush();
  assert.equal(f.results.length, 1);
  assert.equal(f.results[0][1], 'rps');
  assert.equal(f.results[0][2], 'ALPHA-code');
  assert.equal((await f.call(1, 'game:rps:start', { mode: 'rps3' })).ok, true);
  assert.equal((await f.call(1, 'game:rps:reset', {})).ok, true, 'BETA (not User1) may reset');
});

// The oldmaid and blackjack tests live in their own socket test files (games 2.0 modules).

test('AFK: acting resets the clock and a finished game is never forfeited', async t => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 6_000_000 });
  const ended = [];
  f.clients[0].on('game:bowling:updated', s => { if (s.status === 'finished') ended.push(s); });
  assert.equal((await f.call(0, 'game:bowling:start', {})).ok, true);
  await flush();
  f.tick(80_000);
  await flush();
  const before = JSON.parse(await f.redis.get(`game:${f.roomCode}:bowling`));
  const roller = before.turn === 'ALPHA-code' ? 0 : 1;
  assert.equal((await f.call(roller, 'game:bowling:roll', { aim: 0, curve: 0 })).ok, true);
  await flush();
  f.tick(80_000); // 이전 시계 기준이면 이미 90초가 지났다
  await flush();
  assert.equal(ended.length, 0, 'the roll restarted the 90 second clock');
  f.tick(10_000);
  await flush();
  assert.equal(ended.length, 1);
  assert.equal(ended[0].result.reason, 'forfeit');
});

test('lobby options: only the host sets an allowed value and the partner sees it', async t => {
  const f = await fixture(t);
  const updates = [];
  f.clients[1].on('game:lobby:updated', e => updates.push(e));
  const joined = await f.call(0, 'game:lobby:join', { gameType: 'penalty' });
  assert.deepEqual(joined.lobby.options, { cells: 3 }, 'a new lobby starts with the defaults');
  await f.call(1, 'game:lobby:join', { gameType: 'penalty' });
  assert.equal((await f.call(1, 'game:lobby:set_option', { gameType: 'penalty', key: 'cells', value: 6 })).reason, 'not_host');
  assert.equal((await f.call(0, 'game:lobby:set_option', { gameType: 'penalty', key: 'cells', value: 9 })).reason, 'invalid_option');
  assert.equal((await f.call(0, 'game:lobby:set_option', { gameType: 'blackjack', key: 'cells', value: 3 })).reason, 'lobby_not_found');
  assert.equal((await f.call(0, 'game:lobby:set_option', { gameType: 'penalty', key: 'cells', value: 6 })).ok, true);
  await flush();
  assert.deepEqual(updates.at(-1).options, { cells: 6 });
});

test('lobby options: a change resets partner ready and the started game carries the options', async t => {
  const f = await fixture(t);
  await f.call(0, 'game:lobby:join', { gameType: 'uno' });
  await f.call(1, 'game:lobby:join', { gameType: 'uno' });
  assert.equal((await f.call(0, 'game:lobby:set_stake', { gameType: 'uno', stake: 500 })).ok, true);
  assert.equal((await f.call(1, 'game:lobby:ready', { gameType: 'uno', ready: true })).ok, true);
  assert.equal((await f.call(0, 'game:lobby:set_option', { gameType: 'uno', key: 'mode', value: 'classic' })).ok, true);
  assert.equal((await f.call(0, 'game:lobby:start', { gameType: 'uno' })).reason, 'partner_not_ready', 'changing an option asks the partner again');
  assert.equal((await f.call(1, 'game:lobby:ready', { gameType: 'uno', ready: true })).ok, true);
  const started = new Promise(resolve => f.clients[1].once('game:lobby:started', resolve));
  assert.equal((await f.call(0, 'game:lobby:start', { gameType: 'uno' })).ok, true);
  assert.deepEqual((await started).metadata.options, { mode: 'classic' });
  assert.equal((await started).metadata.serverStart, true, 'one card is created by the server on lobby start');
  await flush();
  assert.equal(JSON.parse(await f.redis.get(`uno:${f.roomCode}:game`)).mode, 'classic');
});

test('reaction: only listed emojis reach both players, rate limited per user', async t => {
  const f = await fixture(t);
  const seen = [];
  f.clients[1].on('game:reaction', e => seen.push(e));
  assert.equal((await f.call(0, 'game:reaction', { emoji: '💩' })).reason, 'invalid_reaction');
  assert.equal((await f.call(0, 'game:reaction', { emoji: '😎', gameType: 'blackjack' })).ok, true);
  assert.equal((await f.call(0, 'game:reaction', { emoji: '😅' })).reason, 'too_fast');
  await flush();
  assert.equal(seen.length, 1);
  assert.equal(seen[0].emoji, '😎');
  assert.equal(seen[0].by, 'ALPHA-code');
  assert.equal(seen[0].gameType, 'blackjack');
});

test('equipped item stats already parsed by the driver do not break game creation', async t => {
  const f = await fixture(t);
  const base = boundary.query;
  // mysql2 returns JSON_OBJECTAGG as an object when the server types it as JSON
  // (the test DB does), and as a string otherwise. Both must start the games.
  boundary.query = async (sql, params) => {
    if (sql.includes('SELECT UserId FROM Users WHERE UserCode')) {
      return { rows: [{ UserId: params[0] === 'ALPHA-code' ? 11 : 22 }] };
    }
    if (sql.includes('JOIN shop_items si ON si.id = ei.item_id')) {
      return { rows: [{
        slot: 'onecard_cardback', name: '벚꽃 카드뒷면', icon: '🌸', grade: 'B',
        stats: params[0] === 11 ? { coin_bonus_pct: 3 } : '{"coin_bonus_pct":5}',
      }] };
    }
    if (sql.includes('FROM equipped_items ei')) return { rows: [{ stat_key: 'coin_bonus_pct', total: '3' }] };
    return base(sql, params);
  };
  const started = new Promise(resolve => f.clients[1].once('game:uno:state', resolve));
  await f.call(0, 'game:lobby:join', { gameType: 'uno' });
  await f.call(1, 'game:lobby:join', { gameType: 'uno' });
  assert.equal((await f.call(0, 'game:lobby:start', { gameType: 'uno' })).ok, true);
  const event = await started;
  assert.deepEqual(event.equippedItems['ALPHA-code'].onecard_cardback.stats, { coin_bonus_pct: 3 });
  assert.deepEqual(event.equippedItems['BETA-code'].onecard_cardback.stats, { coin_bonus_pct: 5 });
});
