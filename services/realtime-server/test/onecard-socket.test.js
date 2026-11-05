// 원카드 2.0 소켓 흐름(티켓 19): 서버 시작·승리 가드·단일 종료 경로·서버 타이머·재대결.
import assert from 'node:assert/strict';
import test from 'node:test';
import { boundary, fixture, flush } from './support/socket-harness.js';
// Loaded after the harness so the module shares its memory DB/Redis boundaries.
const { onecardRuntime, TURN_MS } = await import('../src/games/onecard.js');

const A = 'ALPHA-code';
const B = 'BETA-code';
const COUNTDOWN_MS = 5300;
const card = (color, value, suffix = 'x') => ({ color, value, id: `${color ?? 'wild'}-${value}-${suffix}` });
const gameKey = f => `uno:${f.roomCode}:game`;
const readGame = async f => JSON.parse(await f.redis.get(gameKey(f)));
const writeGame = (f, g) => f.redis.set(gameKey(f), JSON.stringify(g), 'EX', 3600);
const indexOf = player => (player === A ? 0 : 1);

async function startFromLobby(f, { mode = null, stake = 0 } = {}) {
  await f.call(0, 'game:lobby:join', { gameType: 'uno' });
  await f.call(1, 'game:lobby:join', { gameType: 'uno' });
  if (stake) assert.equal((await f.call(0, 'game:lobby:set_stake', { gameType: 'uno', stake })).ok, true);
  if (mode) assert.equal((await f.call(0, 'game:lobby:set_option', { gameType: 'uno', key: 'mode', value: mode })).ok, true);
  if (stake) assert.equal((await f.call(1, 'game:lobby:ready', { gameType: 'uno', ready: true })).ok, true);
  assert.equal((await f.call(0, 'game:lobby:start', { gameType: 'uno' })).ok, true);
  await flush();
  return readGame(f);
}

/** Rewrite the running game for a scenario, keeping its id and deadline (and so its timer). */
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

test('lobby start creates the game on the server; sync returns a private view with a deadline', async t => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 1_000_000 });
  const g = await startFromLobby(f, { mode: 'classic' });
  assert.equal(g.mode, 'classic');
  assert.equal(g.turnDeadline, 1_000_000 + COUNTDOWN_MS + TURN_MS, 'first deadline counts from the end of the lobby countdown');
  const sync = await f.call(1, 'game:uno:sync', {});
  assert.equal(sync.ok, true);
  const view = sync.state;
  assert.deepEqual(view.players, [A, B]);
  assert.equal(view.hand.length, 7);
  assert.equal(view.hands, undefined, 'the opponent hand never leaves the server');
  assert.deepEqual(view.handCount, { [A]: 7, [B]: 7 });
  assert.equal(view.turnDeadline, g.turnDeadline);
  assert.equal(view.serverNow, 1_000_000);
  assert.ok(view.equippedItems && typeof view.equippedItems === 'object');
  assert.equal(view.currentColor, view.topCard.color);
});

test('every one card action rejects with game_over once a winner exists', async t => {
  const f = await fixture(t);
  await startFromLobby(f);
  await arrange(f, g => { g.winner = A; });
  for (const [event, payload] of [
    ['game:uno:play', { cardId: 'red-1-a' }],
    ['game:uno:draw', {}],
    ['game:uno:pass', {}],
    ['game:uno:call', {}],
    ['game:uno:catch', {}],
    ['game:uno:challenge', {}],
    ['game:uno:sync', {}],
  ]) {
    assert.equal((await f.call(1, event, payload)).reason, 'game_over', event);
  }
});

test('emptying the hand finishes once: ended carries hands and series, state is deleted, later actions fail', async t => {
  const f = await fixture(t);
  const ended = collect(f, 'game:uno:ended');
  await startFromLobby(f);
  await arrange(f, g => {
    g.currentPlayer = A;
    g.discardPile = [card('red', '7')];
    g.declaredColor = null;
    g.hands[A] = [card('red', '3')];
  });
  const played = await f.call(0, 'game:uno:play', { cardId: 'red-3-x' });
  assert.equal(played.ok, true);
  assert.equal(played.won, true);
  await flush();
  assert.equal(ended[1].length, 1);
  assert.equal(ended[1][0].winner, A);
  assert.equal(ended[1][0].reason, 'empty_hand');
  assert.deepEqual(ended[1][0].hands[A], []);
  assert.equal(ended[1][0].hands[B].length, 7);
  assert.equal(ended[1][0].series.wins[A], 1);
  assert.equal(f.results.length, 1, 'recorded once');
  assert.equal(await f.redis.get(gameKey(f)), null);
  assert.equal((await f.call(1, 'game:uno:draw', {})).reason, 'no_game');
});

test('a settlement exception still deletes the finished state and announces the end', async t => {
  const f = await fixture(t);
  const ended = collect(f, 'game:uno:ended');
  await startFromLobby(f);
  await arrange(f, g => {
    g.currentPlayer = B;
    g.discardPile = [card('blue', '7')];
    g.hands[B] = [card('blue', '1')];
  });
  const base = boundary.query;
  boundary.query = async (sql, params) => {
    if (sql.includes('SELECT UserId FROM Users WHERE UserCode')) throw new Error('db down');
    return base(sql, params);
  };
  t.after(() => { boundary.query = base; });
  assert.equal((await f.call(1, 'game:uno:play', { cardId: 'blue-1-x' })).ok, true);
  await flush();
  assert.equal(await f.redis.get(gameKey(f)), null, 'the finished game must not block a new one');
  assert.equal(ended[0].length, 1);
  assert.equal(ended[0][0].winner, B);
  assert.ok(await f.redis.get(`uno:${f.roomCode}:last`), 'the rematch summary is kept');
});

test('drawing a +2 penalty ends the turn even when the drawn card is playable', async t => {
  const f = await fixture(t);
  await startFromLobby(f);
  await arrange(f, g => {
    g.mode = 'go_wild';
    g.currentPlayer = B;
    g.discardPile = [card('red', 'draw2')];
    g.drawStack = 2;
    g.drawStackType = 'draw2';
    g.hands[B] = [card('blue', '1')];
    g.deck = [...g.deck.filter(c => c.color !== 'red' || c.value !== '4'), card('red', '4', 'p'), card('green', '7', 'p')];
  });
  const drew = await f.call(1, 'game:uno:draw', {});
  assert.equal(drew.ok, true);
  assert.equal(drew.count, 2);
  assert.equal(drew.penalty, true);
  assert.equal(drew.canPlayDrawn, false);
  const g = await readGame(f);
  assert.equal(g.currentPlayer, A, 'the turn passes after serving the penalty');
  assert.equal(g.drawStack, 0);
  assert.equal(g.drawnCardId, null);
  assert.equal((await f.call(1, 'game:uno:play', { cardId: 'red-4-p' })).reason, 'not_your_turn');
});

test('a normal draw of a playable card waits for play or pass', async t => {
  const f = await fixture(t);
  await startFromLobby(f);
  await arrange(f, g => {
    g.currentPlayer = A;
    g.discardPile = [card('red', '8')];
    g.hands[A] = [card('blue', '1'), card('green', '2')];
    g.deck = [...g.deck, card('red', '5', 'n')];
  });
  const drew = await f.call(0, 'game:uno:draw', {});
  assert.equal(drew.canPlayDrawn, true);
  assert.equal((await f.call(0, 'game:uno:draw', {})).reason, 'must_choose_drawn_card');
  assert.equal((await f.call(0, 'game:uno:play', { cardId: 'blue-1-x' })).reason, 'must_choose_drawn_card');
  assert.equal((await f.call(0, 'game:uno:pass', {})).ok, true);
  assert.equal((await readGame(f)).currentPlayer, B);
});

test('discard-all batch applies its skip cards only once', async t => {
  const f = await fixture(t);
  await startFromLobby(f, { mode: 'go_wild' });
  await arrange(f, g => {
    g.currentPlayer = A;
    g.discardPile = [card('red', '7')];
    g.hands[A] = [card('red', 'skip', 'a'), card('red', 'skip', 'b'), card('red', 'discard_all', 'a'), card('blue', '5'), card('green', '3')];
  });
  const played = await f.call(0, 'game:uno:play', { cardId: 'red-discard_all-a' });
  assert.equal(played.ok, true);
  const g = await readGame(f);
  assert.equal(g.hands[A].length, 2);
  assert.equal(g.currentPlayer, A, 'one skip in a two player game returns the turn (two skips used to cancel out)');
});

test('the +4 challenge is judged by the hand at the moment the +4 was played', async t => {
  const f = await fixture(t);
  const challenged = collect(f, 'game:uno:challenged');
  await startFromLobby(f, { mode: 'go_wild' });
  // ALPHA has no red when playing +4 on red; a catch then gives ALPHA red cards.
  await arrange(f, g => {
    g.currentPlayer = A;
    g.discardPile = [card('red', '7')];
    g.declaredColor = null;
    g.hands[A] = [card(null, 'wild_draw4', '0'), card('blue', '5')];
    g.deck = [...g.deck, card('red', '1', 'c'), card('red', '2', 'c')];
  });
  assert.equal((await f.call(0, 'game:uno:play', { cardId: 'wild-wild_draw4-0', declaredColor: 'green' })).ok, true);
  assert.equal((await readGame(f)).hadColorAtDraw4, false);
  assert.equal((await f.call(1, 'game:uno:catch', {})).ok, true);
  assert.ok((await readGame(f)).hands[A].some(c => c.color === 'red'), 'ALPHA holds red now');
  const result = await f.call(1, 'game:uno:challenge', {});
  assert.equal(result.ok, true);
  assert.equal(result.success, false, 'the +4 was legal when played');
  await flush();
  const event = challenged[0].at(-1);
  assert.equal(event.drawnPlayer, B);
  assert.equal(event.drawnCount, 6);
  assert.equal(event.nextPlayer, A);
  assert.ok(Object.prototype.hasOwnProperty.call(event, 'unoCallNeeded'));
  assert.equal((await readGame(f)).declaredColor, 'green');
});

test('a +4 played while holding the current color loses the challenge', async t => {
  const f = await fixture(t);
  await startFromLobby(f, { mode: 'go_wild' });
  await arrange(f, g => {
    g.currentPlayer = A;
    g.discardPile = [card('red', '7')];
    g.hands[A] = [card(null, 'wild_draw4', '0'), card('red', '5'), card('blue', '1')];
  });
  assert.equal((await f.call(0, 'game:uno:play', { cardId: 'wild-wild_draw4-0', declaredColor: 'blue' })).ok, true);
  const result = await f.call(1, 'game:uno:challenge', {});
  assert.equal(result.success, true);
  const g = await readGame(f);
  assert.equal(g.hands[A].length, 6);
  assert.equal(g.currentPlayer, B);
});

test('call and catch are separate: only the one-card player may call, only the opponent may catch', async t => {
  const f = await fixture(t);
  await startFromLobby(f);
  await arrange(f, g => {
    g.currentPlayer = A;
    g.discardPile = [card('red', '7')];
    g.hands[A] = [card('red', '1'), card('blue', '9')];
  });
  assert.equal((await f.call(0, 'game:uno:play', { cardId: 'red-1-x' })).ok, true);
  assert.equal((await readGame(f)).unoCallNeeded, A);
  assert.equal((await f.call(1, 'game:uno:call', {})).reason, 'not_needed');
  assert.equal((await f.call(0, 'game:uno:catch', {})).reason, 'no_target');
  assert.equal((await f.call(0, 'game:uno:call', {})).ok, true);
  assert.equal((await f.call(1, 'game:uno:catch', {})).reason, 'no_target', 'a called one card cannot be caught');
});

test('first starter is random; consent rematches alternate starters and keep mode, stake and series', async t => {
  const f = await fixture(t);
  const original = onecardRuntime.random;
  onecardRuntime.random = () => 0.999;
  t.after(() => { onecardRuntime.random = original; });
  const ended = collect(f, 'game:uno:ended');
  const first = await startFromLobby(f, { mode: 'classic', stake: 500 });
  assert.equal(first.starter, B, 'random() ≈ 1 picks the second player');
  onecardRuntime.random = original;
  assert.equal(first.stake, 500);

  const finish = async () => {
    const g = await arrange(f, s => {
      s.discardPile = [card('red', '7')];
      s.hands[s.currentPlayer] = [card('red', '3')];
    });
    assert.equal((await f.call(indexOf(g.currentPlayer), 'game:uno:play', { cardId: 'red-3-x' })).ok, true);
    await flush();
  };
  const rematch = async () => {
    assert.equal((await f.call(0, 'game:restart:request', { gameType: 'uno' })).ok, true);
    assert.equal((await f.call(1, 'game:restart:respond', { gameType: 'uno', accept: true })).ok, true);
    await flush();
    return readGame(f);
  };

  await finish();
  const second = await rematch();
  assert.equal(second.starter, A);
  assert.equal(second.currentPlayer, A);
  assert.equal(second.mode, 'classic');
  assert.equal(second.stake, 500);
  assert.notEqual(second.gameId, first.gameId);
  assert.equal(second.series.games, 1);
  await finish();
  const third = await rematch();
  assert.equal(third.starter, B);
  assert.equal(third.mode, 'classic');
  assert.equal(third.stake, 500);
  assert.equal(third.series.games, 2);
  assert.equal(ended[0].length, 2);
  assert.equal(new Set(f.results.map(r => r[7])).size, 2, 'each game is recorded under its own id');
});

test('turn timer: expiry draws one and passes; a pending penalty is taken; three in a row forfeit', async t => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 2_000_000 });
  const ended = collect(f, 'game:uno:ended');
  const states = collect(f, 'game:uno:state');
  const g0 = await startFromLobby(f);
  const idle = g0.currentPlayer;
  const other = idle === A ? B : A;
  f.tick(COUNTDOWN_MS + TURN_MS - 1);
  await flush();
  assert.equal((await readGame(f)).currentPlayer, idle, 'nothing happens before the deadline');
  f.tick(1);
  await flush();
  let g = await readGame(f);
  assert.equal(g.hands[idle].length, 8, 'safe action: draw one');
  assert.equal(g.currentPlayer, other, 'and pass');
  assert.equal(g.lastAction.type, 'draw');
  assert.equal(g.lastAction.auto, true);
  assert.equal(g.autoStreak[idle], 1);
  assert.equal(g.turnDeadline, Date.now() + TURN_MS, 'the deadline restarts on every state change');
  assert.equal(states[indexOf(other)].at(-1).turnDeadline, g.turnDeadline);

  // The other player faces a +4 stack and times out: the penalty is served, not a random card.
  await arrange(f, s => { s.drawStack = 4; s.drawStackType = 'wild_draw4'; s.lastDraw4Player = idle; s.colorBeforeDraw4 = 'red'; s.hadColorAtDraw4 = false; });
  f.tick(TURN_MS);
  await flush();
  g = await readGame(f);
  assert.equal(g.hands[other].length, 11);
  assert.equal(g.drawStack, 0);
  assert.equal(g.currentPlayer, idle);

  f.tick(TURN_MS); // idle: 2nd auto
  await flush();
  assert.equal((await readGame(f)).autoStreak[idle], 2);
  // other acts by hand: their streak resets
  const turn = await readGame(f);
  assert.equal(turn.currentPlayer, other);
  assert.equal((await f.call(indexOf(other), 'game:uno:draw', {})).ok, true);
  const afterManual = await readGame(f);
  assert.equal(afterManual.autoStreak[other], 0);
  if (afterManual.currentPlayer === other) assert.equal((await f.call(indexOf(other), 'game:uno:pass', {})).ok, true);
  await flush();
  f.tick(TURN_MS); // idle: 3rd consecutive → forfeit
  await flush();
  assert.equal(ended[0].length, 1);
  assert.equal(ended[0][0].reason, 'forfeit');
  assert.equal(ended[0][0].winner, other);
  assert.equal(f.results.length, 1);
  assert.equal(await f.redis.get(gameKey(f)), null);
});

test('restore re-sends players, equipped items and the deadline, and joins the viewer room', async t => {
  const f = await fixture(t);
  await startFromLobby(f);
  await arrange(f, g => { delete g.turnDeadline; });
  const states = collect(f, 'game:uno:state');
  const restored = await f.call(1, 'session:restore', {});
  await flush();
  assert.ok(restored.restored.includes('uno'));
  const view = states[1].at(-1);
  assert.deepEqual(view.players, [A, B]);
  assert.ok(view.equippedItems);
  assert.ok(view.turnDeadline > 0, 'a restored game without a deadline gets a fresh one');
});

test('AFK watcher: an idle game whose own timer is gone forfeits through the same finish path', async t => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 5_000_000 });
  const warnings = [];
  const ended = collect(f, 'game:uno:ended');
  f.clients[1].on('game:afk:warning', e => warnings.push(e));
  const g = await startFromLobby(f);
  // Simulate a game whose turn timer no longer matches (e.g. state written by an older server).
  await arrange(f, s => { s.turnDeadline = Date.now() + 3_600_000; });
  await f.call(0, 'game:uno:sync', {});
  await flush();
  f.tick(60_000);
  await flush();
  assert.equal(warnings.length, 1);
  assert.equal(warnings[0].player, g.currentPlayer);
  f.tick(30_000);
  await flush();
  assert.equal(ended[1].length, 1);
  assert.equal(ended[1][0].reason, 'forfeit');
  assert.notEqual(ended[1][0].winner, g.currentPlayer);
  assert.equal(f.results.length, 1);
  assert.equal(await f.redis.get(gameKey(f)), null);
});

test('sync without a game reports no_game (the screen shows the preparing state)', async t => {
  const f = await fixture(t);
  assert.equal((await f.call(0, 'game:uno:sync', {})).reason, 'no_game');
  assert.equal((await f.call(0, 'game:uno:play', { cardId: 'x' })).reason, 'no_game');
});
