// 그림 맞히기 2.0 소켓 회귀: 서버 시작, 획 전달·재생(재접속), 실행 취소·지우기, 타이머 종료,
// 힌트 일정, 정답·아까워요, 제시어 비노출, 재대결, 자리 비움.
import assert from 'node:assert/strict';
import test from 'node:test';
import { fixture, flush } from './support/socket-harness.js';
import {
  CATCH_MAX_BATCHES_PER_SEC, CATCH_REVEAL_MS, normalizeStrokeBatch, setCatchRandom,
} from '../src/games/catch.js';
import { CATCH_ROUND_MS } from '../src/catch-engine.js';

const A = 'ALPHA-code';
const B = 'BETA-code';
const START = 1_000_000;
const LOBBY_MS = 5_300;

function collect(f) {
  const log = { states: [[], []], strokes: [[], []], undos: [[], []], clears: [[], []], replays: [[], []], guesses: [[], []], results: [[], []] };
  f.clients.forEach((c, i) => {
    c.on('game:catch:state', (s) => log.states[i].push(s));
    c.on('game:catch:stroke', (s) => log.strokes[i].push(s));
    c.on('game:catch:undo', (s) => log.undos[i].push(s));
    c.on('game:catch:clear', (s) => log.clears[i].push(s));
    c.on('game:catch:replay', (s) => log.replays[i].push(s));
    c.on('game:catch:guess', (s) => log.guesses[i].push(s));
    c.on('game:catch:round_result', (s) => log.results[i].push(s));
  });
  return log;
}

async function startCatch(t, f, rounds) {
  t.mock.timers.enable({ apis: ['Date'], now: START });
  setCatchRandom(() => 0); // 첫 그리는 사람 = 첫 번째(ALPHA)
  t.after(() => setCatchRandom());
  assert.equal((await f.call(0, 'game:lobby:join', { gameType: 'catch' })).ok, true);
  assert.equal((await f.call(1, 'game:lobby:join', { gameType: 'catch' })).ok, true);
  if (rounds) assert.equal((await f.call(0, 'game:lobby:set_option', { gameType: 'catch', key: 'rounds', value: rounds })).ok, true);
  const started = await f.call(0, 'game:lobby:start', { gameType: 'catch' });
  assert.equal(started.ok, true, `start rejected: ${started.reason}`);
  await flush();
}

const stroke = (round, id, seq, pts, extra = {}) => ({ round, id, seq, tool: 'pen', color: 3, w: 0.012, pts, ...extra });
const secret = (log) => log.states[0].at(-1).word ?? log.states[1].at(-1).word;
// 자리 비움으로 보이지 않게 그리는 사람이 한 획 긋는다.
const scribble = async (f, log) => {
  const s = log.states[0].at(-1);
  await f.call(s.drawer === A ? 0 : 1, 'game:catch:stroke', stroke(s.round, `sc${s.round}`, 0, [[0.2, 0.2], [0.3, 0.3]], { end: true }));
};
const tickTo = async (f, at) => { f.tick(at - Date.now()); await flush(); };

test('catch: the lobby start creates the game; only the drawer sees the word', async (t) => {
  const f = await fixture(t);
  const log = collect(f);
  await startCatch(t, f, 4);
  const mine = log.states[0].at(-1);
  const theirs = log.states[1].at(-1);
  assert.equal(mine.status, 'playing');
  assert.equal(mine.phase, 'drawing');
  assert.equal(mine.round, 1);
  assert.equal(mine.maxRounds, 4, 'lobby rounds option');
  assert.equal(mine.drawer, A);
  assert.deepEqual(mine.players, [A, B]);
  assert.equal(mine.turnDeadline, START + LOBBY_MS + CATCH_ROUND_MS);
  assert.equal(mine.serverNow, START);
  assert.ok(mine.gameId);
  assert.ok(mine.category);
  assert.equal(mine.wordLen, [...mine.word].length);
  assert.equal(theirs.word, undefined, 'the guesser never receives the word');
  assert.equal(theirs.wordLen, mine.wordLen);
  assert.deepEqual(theirs.hint, Array(mine.wordLen).fill(''));
  assert.equal(JSON.stringify(log.states[1]).includes(mine.word), false);
  assert.deepEqual(theirs.series.wins, { [A]: 0, [B]: 0 });

  const sync = await f.call(1, 'game:catch:sync', {});
  assert.equal(sync.ok, true);
  assert.equal(sync.state.word, undefined);
  assert.equal(JSON.stringify(sync).includes(mine.word), false);
  const draw = await f.call(0, 'game:catch:sync', {});
  assert.equal(draw.state.word, mine.word);
  // 저장소 어디에도 클라이언트가 보낸 시작 이벤트는 필요 없다(옛 start 이벤트는 사라졌다).
  assert.equal(JSON.stringify(log.states[1]).includes('"aliases"'), false);
});

test('catch: default rounds is 6 and unknown option values fall back', async (t) => {
  const f = await fixture(t);
  const log = collect(f);
  await startCatch(t, f);
  assert.equal(log.states[0].at(-1).maxRounds, 6);
  assert.equal((await f.call(0, 'game:lobby:set_option', { gameType: 'catch', key: 'rounds', value: 5 })).ok, false);
});

test('catch: strokes reach the guesser, are recorded, and replay after a reconnect', async (t) => {
  const f = await fixture(t);
  const log = collect(f);
  await startCatch(t, f);
  const round = 1;
  assert.equal((await f.call(0, 'game:catch:stroke', stroke(round, 's1', 0, [[0.1, 0.1], [0.2, 0.2]]))).ok, true);
  assert.equal((await f.call(0, 'game:catch:stroke', stroke(round, 's1', 1, [[0.3, 0.3]], { end: true }))).ok, true);
  assert.equal((await f.call(0, 'game:catch:stroke', stroke(round, 's2', 0, [[0.5, 0.5]], { tool: 'eraser', w: 0.04, end: true }))).ok, true);
  assert.equal((await f.call(0, 'game:catch:stroke', stroke(round, 's3', 0, [[0.7, 0.2]], { tool: 'marker', color: 11, end: true }))).ok, true);
  await flush();
  assert.equal(log.strokes[1].length, 4, 'every batch is relayed');
  assert.deepEqual(log.strokes[1][0], { round: 1, id: 's1', seq: 0, tool: 'pen', color: 3, w: 0.012, pts: [[0.1, 0.1], [0.2, 0.2]], end: false });
  assert.equal(log.strokes[0].length, 0, 'the drawer does not get their own strokes back');
  assert.equal(log.strokes[1][2].tool, 'eraser');
  assert.equal(log.strokes[1][2].w, 0.04, 'same width on both screens');

  // 다시 접속한 쪽은 sync로 지금까지의 그림 전체를 받는다.
  const sync = await f.call(1, 'game:catch:sync', {});
  assert.equal(sync.ok, true);
  await flush();
  const replay = log.replays[1].at(-1);
  assert.equal(replay.round, 1);
  assert.deepEqual(replay.strokes.map((s) => s.id), ['s1', 's2', 's3']);
  assert.deepEqual(replay.strokes[0].pts, [[0.1, 0.1], [0.2, 0.2], [0.3, 0.3]], 'batches are merged into one stroke');
  assert.equal(replay.strokes[2].color, 11);

  const before = log.replays[1].length;
  const restored = await f.call(1, 'session:restore', {});
  assert.ok(restored.restored.includes('catch'));
  await flush();
  assert.ok(log.replays[1].length > before);
  assert.equal(log.replays[1].at(-1).strokes.length, 3);
  assert.equal(log.states[1].at(-1).word, undefined);
});

test('catch: a server restart still replays strokes from the stored record', async (t) => {
  const f = await fixture(t);
  const log = collect(f);
  await startCatch(t, f);
  await f.call(0, 'game:catch:stroke', stroke(1, 'a1', 0, [[0.2, 0.2], [0.4, 0.4]], { end: true }));
  const saved = JSON.parse(await f.redis.get(`game:${f.roomCode}:catch:art`));
  assert.equal(saved.strokes.length, 1);
  assert.equal(saved.round, 1);
  assert.equal(saved.gameId, log.states[0].at(-1).gameId);
});

test('catch: only the drawer can draw, rounds are checked, bad payloads and floods are refused', async (t) => {
  const f = await fixture(t);
  const log = collect(f);
  await startCatch(t, f);
  const ok = stroke(1, 'x1', 0, [[0.5, 0.5]]);
  assert.equal((await f.call(1, 'game:catch:stroke', ok)).reason, 'not_drawer');
  assert.equal((await f.call(1, 'game:catch:undo', { round: 1 })).reason, 'not_drawer');
  assert.equal((await f.call(1, 'game:catch:clear', { round: 1 })).reason, 'not_drawer');
  assert.equal((await f.call(0, 'game:catch:stroke', { ...ok, round: 9 })).reason, 'stale_round');
  assert.equal((await f.call(0, 'game:catch:stroke', { ...ok, tool: 'laser' })).reason, 'invalid_payload');
  assert.equal((await f.call(0, 'game:catch:stroke', { ...ok, color: 12 })).reason, 'invalid_payload');
  assert.equal((await f.call(0, 'game:catch:stroke', { ...ok, w: 0.5 })).reason, 'invalid_payload');
  assert.equal((await f.call(0, 'game:catch:stroke', { ...ok, pts: [] })).reason, 'invalid_payload');
  assert.equal((await f.call(0, 'game:catch:stroke', { ...ok, pts: [['a', 1]] })).reason, 'invalid_payload');
  assert.equal((await f.call(0, 'game:catch:stroke', { ...ok, id: 'bad id!' })).reason, 'invalid_payload');
  assert.equal((await f.call(0, 'game:catch:stroke', stroke(1, 'late', 3, [[0.1, 0.1]]))).reason, 'unknown_stroke');
  await flush();
  assert.equal(log.strokes[1].length, 0, 'nothing invalid is relayed');

  // 좌표는 0~1로 잘리고, 같은 묶음 번호를 다시 보내도 두 번 그려지지 않는다.
  assert.equal((await f.call(0, 'game:catch:stroke', stroke(1, 'c1', 0, [[-3, 4.5]]))).ok, true);
  assert.deepEqual(log.strokes[1].at(-1)?.pts ?? (await flush(), log.strokes[1].at(-1).pts), [[0, 1]]);
  assert.equal((await f.call(0, 'game:catch:stroke', stroke(1, 'c1', 0, [[0.9, 0.9]]))).duplicate, true);

  // 한 소켓이 1초 안에 너무 많은 묶음을 보내면 막힌다.
  let limited = 0;
  for (let i = 0; i < CATCH_MAX_BATCHES_PER_SEC + 5; i++) {
    const r = await f.call(0, 'game:catch:stroke', stroke(1, `f${i}`, 0, [[0.1, 0.1]]));
    if (r.reason === 'rate_limited') limited++;
  }
  assert.ok(limited >= 4, `flood limited (${limited})`);
  f.tick(1_500);
  assert.equal((await f.call(0, 'game:catch:stroke', stroke(1, 'after', 0, [[0.1, 0.1]]))).ok, true, 'the window resets');
});

test('catch: round stroke caps stop a runaway drawing', async (t) => {
  const f = await fixture(t);
  await startCatch(t, f);
  const pts = Array.from({ length: 80 }, (_, i) => [i / 100, 0.5]);
  let refused = null;
  for (let n = 0; n < 220 && !refused; n++) {
    if (n % 10 === 0) f.tick(1_100);
    const r = await f.call(0, 'game:catch:stroke', stroke(1, `big${Math.floor(n / 40)}`, n % 40, pts));
    if (!r.ok) refused = r.reason;
  }
  assert.equal(refused, 'stroke_limit');
});

test('catch: undo removes a stroke on both screens and in the stored record; clear wipes the board', async (t) => {
  const f = await fixture(t);
  const log = collect(f);
  await startCatch(t, f);
  for (const id of ['u1', 'u2', 'u3']) await f.call(0, 'game:catch:stroke', stroke(1, id, 0, [[0.2, 0.2], [0.3, 0.3]], { end: true }));
  const undone = await f.call(0, 'game:catch:undo', { round: 1 });
  assert.deepEqual(undone, { ok: true, id: 'u3' }, 'no id = the last stroke');
  assert.equal((await f.call(0, 'game:catch:undo', { round: 1, id: 'u1' })).id, 'u1');
  assert.equal((await f.call(0, 'game:catch:undo', { round: 1, id: 'nope' })).reason, 'no_stroke');
  assert.equal((await f.call(0, 'game:catch:undo', { round: 2 })).reason, 'stale_round');
  await flush();
  assert.deepEqual(log.undos[1].map((u) => u.id), ['u3', 'u1']);
  assert.equal((await f.call(0, 'game:catch:stroke', stroke(1, 'u3', 1, [[0.9, 0.9]]))).reason, 'unknown_stroke', 'a late batch of an undone stroke is dropped');
  await f.call(1, 'game:catch:sync', {});
  await flush();
  assert.deepEqual(log.replays[1].at(-1).strokes.map((s) => s.id), ['u2']);

  assert.equal((await f.call(0, 'game:catch:clear', { round: 1 })).ok, true);
  await flush();
  assert.equal(log.clears[1].length, 1);
  assert.equal(log.clears[1][0].round, 1);
  await f.call(1, 'game:catch:sync', {});
  await flush();
  assert.deepEqual(log.replays[1].at(-1).strokes, []);
  const saved = JSON.parse(await f.redis.get(`game:${f.roomCode}:catch:art`));
  assert.deepEqual(saved.strokes, []);
});

test('catch: the 60 s round ends on the server, reveals the word, then the next round starts by itself', async (t) => {
  const f = await fixture(t);
  const log = collect(f);
  await startCatch(t, f, 4);
  const first = log.states[0].at(-1);
  await f.call(0, 'game:catch:stroke', stroke(1, 'r1', 0, [[0.1, 0.1]], { end: true }));
  await tickTo(f, first.turnDeadline - 1);
  assert.equal(log.results[0].length, 0, 'not before the deadline');
  await tickTo(f, first.turnDeadline);
  const r1 = log.results[1].at(-1);
  assert.equal(r1.round, 1);
  assert.equal(r1.outcome, 'timeout');
  assert.equal(r1.word, first.word);
  assert.deepEqual(r1.points, { [A]: 0, [B]: 0 });
  assert.equal(r1.revealUntil - r1.serverNow, CATCH_REVEAL_MS);
  const reveal = log.states[1].at(-1);
  assert.equal(reveal.phase, 'reveal');
  assert.equal(reveal.word, first.word, 'the guesser now sees the word');
  assert.equal(reveal.turnDeadline, null);
  assert.equal((await f.call(1, 'game:catch:guess', { round: 1, text: first.word })).reason, 'round_over');
  assert.equal((await f.call(0, 'game:catch:stroke', stroke(1, 'r2', 0, [[0.1, 0.1]]))).reason, 'round_over');

  await tickTo(f, reveal.revealUntil);
  const second = log.states[0].at(-1);
  assert.equal(second.round, 2);
  assert.equal(second.phase, 'drawing');
  assert.equal(second.drawer, B, 'drawers alternate');
  assert.notEqual(second.word, first.word);
  assert.equal(second.turnDeadline, Date.now() + CATCH_ROUND_MS);
  assert.equal(second.history.length, 1);
  assert.equal(log.states[0].at(-1).word, undefined, 'the new word is hidden from the new guesser');
  // 새 라운드에서는 이전 그림이 비어 있다.
  await f.call(0, 'game:catch:sync', {});
  await flush();
  assert.deepEqual(log.replays[0].at(-1), { round: 2, strokes: [] });
});

test('catch: letters open at 30 s and 15 s left; a direct hint costs a point', async (t) => {
  const f = await fixture(t);
  const log = collect(f);
  await startCatch(t, f, 8);
  const state = log.states[1].at(-1);
  const deadline = state.turnDeadline;
  const len = state.wordLen;
  assert.ok(len >= 3, 'the seeded first word has 3+ letters (1~2 letter words have no hints, see the engine test)');
  const shown = () => log.states[1].at(-1).hint.filter(Boolean).length;
  await tickTo(f, deadline - 30_001);
  assert.equal(shown(), 0);
  await tickTo(f, deadline - 30_000);
  assert.equal(shown(), 1);
  const word = log.states[0].at(-1).word;
  const tiles = log.states[1].at(-1).hint;
  tiles.forEach((c, i) => c && assert.equal(c, [...word][i]));
  await tickTo(f, deadline - 15_000);
  assert.equal(shown(), 2);
  assert.equal(log.states[1].at(-1).canHint, len > 3, 'one letter always stays hidden');
  await tickTo(f, deadline - 14_000);
  assert.equal(shown(), 2, 'no more automatic letters');
});

test('catch: a direct hint opens one letter, is limited to once and refused to the drawer', async (t) => {
  const f = await fixture(t);
  const log = collect(f);
  setCatchRandom(() => 0);
  await startCatch(t, f, 8);
  // 3글자 이상 제시어가 나올 때까지 라운드를 넘겨 확인한다.
  for (let i = 0; i < 8 && log.states[0].at(-1).wordLen < 3; i++) {
    await scribble(f, log);
    await tickTo(f, log.states[0].at(-1).turnDeadline);
    await tickTo(f, log.states[0].at(-1).revealUntil);
  }
  const s = log.states[0].at(-1);
  assert.ok(s.wordLen >= 3);
  const guesser = s.drawer === A ? 1 : 0;
  const drawer = 1 - guesser;
  assert.equal((await f.call(drawer, 'game:catch:hint', { round: s.round })).reason, 'drawer_cannot_hint');
  assert.equal((await f.call(guesser, 'game:catch:hint', { round: s.round + 1 })).reason, 'stale_round');
  const hint = await f.call(guesser, 'game:catch:hint', { round: s.round });
  assert.deepEqual(hint, { ok: true, penalty: 1 });
  await flush();
  assert.equal(log.states[guesser].at(-1).hint.filter(Boolean).length, 1);
  assert.equal(log.states[guesser].at(-1).directHint, true);
  assert.equal((await f.call(guesser, 'game:catch:hint', { round: s.round })).reason, 'hint_used');
});

test('catch: guesses are judged, close misses say close, correct answers score 3 + time bonus and the drawer 2', async (t) => {
  const f = await fixture(t);
  const log = collect(f);
  await startCatch(t, f, 4);
  const s = log.states[0].at(-1);
  const answer = s.word;
  assert.equal((await f.call(0, 'game:catch:guess', { round: 1, text: '아무말' })).reason, 'drawer_cannot_guess');
  assert.equal((await f.call(1, 'game:catch:guess', { round: 7, text: '아무말' })).reason, 'stale_round');
  assert.equal((await f.call(1, 'game:catch:guess', { text: '아무말' })).reason, 'invalid_payload');
  const wrong = await f.call(1, 'game:catch:guess', { round: 1, text: '뷁뷁뷁뷁' });
  assert.deepEqual(wrong, { ok: true, verdict: 'wrong' });
  assert.equal((await f.call(1, 'game:catch:guess', { round: 1, text: '또' })).reason, 'too_fast', '0.7 s between guesses');
  f.tick(700);
  if ([...answer].length >= 3) {
    const close = await f.call(1, 'game:catch:guess', { round: 1, text: `${answer}가` });
    assert.equal(close.verdict, 'close');
    f.tick(700);
  }
  await flush();
  assert.deepEqual(log.guesses[0].map((g) => g.verdict).slice(0, 1), ['wrong'], 'the drawer sees the guess bubbles');
  assert.equal(log.guesses[0][0].userId, B);
  assert.equal(log.guesses[0][0].text, '뷁뷁뷁뷁');

  const left = s.turnDeadline - Date.now();
  const right = await f.call(1, 'game:catch:guess', { round: 1, text: ` ${[...answer].join(' ')} ` });
  assert.deepEqual(right, { ok: true, verdict: 'correct' });
  await flush();
  const r = log.results[0].at(-1);
  assert.equal(r.outcome, 'correct');
  assert.equal(r.guesser, B);
  assert.equal(r.word, answer);
  const bonus = Math.floor(left / 20_000);
  assert.equal(r.points[B], 3 + bonus);
  assert.equal(r.points[A], 2);
  assert.deepEqual(r.scores, { [A]: 2, [B]: 3 + bonus });
  const after = log.states[1].at(-1);
  assert.equal(after.phase, 'reveal');
  assert.equal(after.word, answer);
  assert.equal(after.history[0].outcome, 'correct');
});

test('catch: an alias counts as the right answer', async (t) => {
  const f = await fixture(t);
  const log = collect(f);
  await startCatch(t, f, 8);
  // 동의어가 있는 제시어가 나올 때까지 넘긴다.
  const bank = (await import('../src/catch-engine.js')).WORD_BANK;
  for (let i = 0; i < 8; i++) {
    const s = log.states[0].at(-1);
    const entry = bank.find((e) => e.w === secret(log));
    if (entry.aliases.length) {
      const g = s.drawer === A ? 1 : 0;
      const r = await f.call(g, 'game:catch:guess', { round: s.round, text: entry.aliases[0] });
      assert.equal(r.verdict, 'correct');
      return;
    }
    await scribble(f, log);
    await tickTo(f, s.turnDeadline);
    await tickTo(f, log.states[0].at(-1).revealUntil);
  }
});

test('catch: a full game scores, records once, shows a gallery, then a consented rematch swaps the first drawer', async (t) => {
  const f = await fixture(t);
  const log = collect(f);
  await startCatch(t, f, 4);
  const gameId = log.states[0].at(-1).gameId;
  for (let round = 1; round <= 4; round++) {
    const s = log.states[0].at(-1);
    assert.equal(s.round, round);
    const drawer = s.drawer === A ? 0 : 1;
    await f.call(drawer, 'game:catch:stroke', stroke(round, `g${round}`, 0, [[0.1, 0.1], [0.4, 0.4]], { end: true }));
    if (round !== 2) {
      const mine = log.states[drawer].at(-1);
      await f.call(1 - drawer, 'game:catch:guess', { round, text: mine.word });
    } else {
      await tickTo(f, s.turnDeadline); // 시간 초과
    }
    await flush();
    if (round < 4) await tickTo(f, log.states[0].at(-1).revealUntil);
  }
  // 마지막 라운드는 정답을 보여 준 뒤에 끝난다.
  assert.equal(log.states[0].at(-1).status, 'playing');
  assert.equal(f.results.length, 0);
  await tickTo(f, log.states[0].at(-1).revealUntil);
  const end = log.states[1].at(-1);
  assert.equal(end.status, 'finished');
  assert.equal(end.result.reason, 'score');
  assert.equal(end.history.length, 4);
  assert.equal(end.gallery.length, 4);
  assert.deepEqual(end.gallery.map((g) => g.round), [1, 2, 3, 4]);
  assert.ok(end.gallery.every((g) => g.strokes.length === 1 && g.word));
  assert.equal(end.gallery[1].outcome, 'timeout');
  const total = end.scores;
  assert.equal(total[A] + total[B] > 0, true);
  await flush();
  assert.equal(f.results.length, 1, 'outcome recorded once');
  assert.equal(f.results[0][1], 'catch');
  assert.equal(f.results.at(-1).at(-1), gameId, 'recorded with the lobby gameId');
  assert.equal((await f.call(1, 'game:catch:guess', { round: 4, text: '아무' })).reason, 'game_over');
  assert.equal((await f.call(1, 'game:catch:stroke', stroke(4, 'z', 0, [[0, 0]]))).reason, 'round_over');
  const seriesWins = end.series.wins;
  assert.equal(seriesWins[A] + seriesWins[B] + end.series.draws, 1);

  // 재접속하면 결과와 갤러리를 다시 받는다.
  await f.call(1, 'game:catch:sync', {});
  await flush();
  assert.equal(log.states[1].at(-1).gallery.length, 4);

  assert.equal((await f.call(1, 'game:restart:request', { gameType: 'catch' })).ok, true);
  const accepted = await f.call(0, 'game:restart:respond', { accept: true, gameType: 'catch' });
  assert.equal(accepted.ok, true, `rematch rejected: ${accepted.reason}`);
  await flush();
  const fresh = log.states[0].at(-1);
  assert.equal(fresh.status, 'playing');
  assert.notEqual(fresh.gameId, gameId);
  assert.equal(fresh.round, 1);
  assert.equal(fresh.maxRounds, 4, 'rounds carry over');
  assert.equal(fresh.drawer, B, 'the other player draws first');
  assert.deepEqual(fresh.scores, { [A]: 0, [B]: 0 });
  assert.equal(fresh.series.games, 1, 'series carries over');
  assert.equal(fresh.gallery, undefined);
});

test('catch: seen words are stored per room (90 days) and a rematch does not repeat them', async (t) => {
  const f = await fixture(t);
  const log = collect(f);
  await startCatch(t, f, 4);
  const seenKey = `catch:${f.roomCode}:seen`;
  const words = [];
  for (let round = 1; round <= 4; round++) {
    const s = log.states[0].at(-1);
    words.push(secret(log));
    assert.deepEqual(JSON.parse(await f.redis.get(seenKey)), words, 'saved as each word is drawn');
    await scribble(f, log);
    await tickTo(f, s.turnDeadline);
    if (round < 4) await tickTo(f, log.states[0].at(-1).revealUntil);
  }
  assert.equal(new Set(words).size, 4);
  await tickTo(f, log.states[0].at(-1).revealUntil);
  assert.equal((await f.call(1, 'game:restart:request', { gameType: 'catch' })).ok, true);
  assert.equal((await f.call(0, 'game:restart:respond', { accept: true, gameType: 'catch' })).ok, true);
  await flush();
  const next = log.states[0].at(-1);
  assert.equal(words.includes(secret(log)), false, 'the next game starts with a fresh word');
  assert.equal(JSON.parse(await f.redis.get(seenKey)).length, 5);
});

test('catch: a player who never draws two turns in a row forfeits', async (t) => {
  const f = await fixture(t);
  const log = collect(f);
  await startCatch(t, f, 4);
  // 1라운드: A(그리는 사람)가 아무것도 안 그림 → 시간 초과
  await tickTo(f, log.states[0].at(-1).turnDeadline);
  await tickTo(f, log.states[0].at(-1).revealUntil);
  // 2라운드: B가 그림 → 시간 초과(그림이 있으므로 B는 괜찮다)
  assert.equal(log.states[0].at(-1).drawer, B);
  await f.call(1, 'game:catch:stroke', stroke(2, 'b1', 0, [[0.2, 0.2]], { end: true }));
  await tickTo(f, log.states[0].at(-1).turnDeadline);
  await tickTo(f, log.states[0].at(-1).revealUntil);
  // 3라운드: 다시 A가 아무것도 안 그림 → 연속 두 번이라 기권
  assert.equal(log.states[0].at(-1).drawer, A);
  await tickTo(f, log.states[0].at(-1).turnDeadline);
  const end = log.states[1].at(-1);
  assert.equal(end.status, 'finished');
  assert.equal(end.result.reason, 'forfeit');
  assert.equal(end.result.winner, B);
  assert.equal(end.result.loser, A);
  await flush();
  assert.equal(f.results.length, 1);
  assert.equal(f.results[0][2], B);
});

test('catch: normalizeStrokeBatch clamps coordinates and ignores the colour of an eraser', () => {
  const n = normalizeStrokeBatch({ id: 'a', seq: 0, tool: 'eraser', color: 99, w: 0.03, pts: [[1.5, -2], [0.123456, 0.5]] });
  assert.deepEqual(n.pts, [[1, 0], [0.1235, 0.5]]);
  assert.equal(n.color, 0);
  assert.equal(n.end, false);
  assert.equal(normalizeStrokeBatch(null), null);
  assert.equal(normalizeStrokeBatch({ id: 'a', seq: -1, tool: 'pen', color: 1, w: 0.01, pts: [[0, 0]] }), null);
});
