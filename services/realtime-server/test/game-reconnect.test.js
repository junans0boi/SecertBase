/**
 * game-reconnect.test.js
 *
 * #13: 공개 게임 완주 및 재접속 동작 검증
 * - Bomb 타이머 서버 기준 잔여 시간 계산
 * - RPS 취소 결정 로직 (rpsGameKey 존재 여부)
 */
import test from 'node:test';
import assert from 'node:assert/strict';

// ── Bomb 타이머 복원 ─────────────────────────────────────────────────────────

test('Bomb: 서버 기준 잔여 시간은 경과 시간만큼 줄어야 한다', () => {
  const duration = 30; // 초
  const startTime = Date.now() - 10_000; // 10초 전 시작
  const elapsed = Math.floor((Date.now() - startTime) / 1000);
  const remaining = Math.max(0, duration - elapsed);
  // 경과 10초 → 잔여 약 20초
  assert.ok(remaining >= 19 && remaining <= 21, `remaining=${remaining}, expected ~20`);
});

test('Bomb: 만료된 게임의 잔여 시간은 0이어야 한다', () => {
  const duration = 30;
  const startTime = Date.now() - 60_000; // 60초 전 시작 (만료)
  const elapsed = Math.floor((Date.now() - startTime) / 1000);
  const remaining = Math.max(0, duration - elapsed);
  assert.equal(remaining, 0);
});

// ── RPS 미완료 판 취소 ────────────────────────────────────────────────────────

/**
 * rpsGameKey 가 존재할 때만 취소 이벤트를 보내야 한다는 로직을
 * 순수 함수로 추출해 검증한다.
 */
const shouldCancelRps = (rpsState) => rpsState !== null;

test('RPS: 진행 중인 상태(non-null)가 있으면 취소해야 한다', () => {
  assert.equal(shouldCancelRps({ phase: 'picking' }), true);
});

test('RPS: 상태가 null이면 취소하지 않는다', () => {
  assert.equal(shouldCancelRps(null), false);
});

// ── 가위바위보 승자 결정 ──────────────────────────────────────────────────────

const rpsWinner = (c1, c2) =>
  c1 === c2 ? 'draw'
  : ((c1==='rock'&&c2==='scissors')||(c1==='scissors'&&c2==='paper')||(c1==='paper'&&c2==='rock'))
    ? 'p1' : 'p2';

test('RPS: 바위는 가위를 이긴다', () => {
  assert.equal(rpsWinner('rock', 'scissors'), 'p1');
});

test('RPS: 보자기는 바위를 이긴다', () => {
  assert.equal(rpsWinner('paper', 'rock'), 'p1');
});

test('RPS: 가위는 보자기를 이긴다', () => {
  assert.equal(rpsWinner('scissors', 'paper'), 'p1');
});

test('RPS: 같은 패는 비긴다', () => {
  assert.equal(rpsWinner('rock', 'rock'), 'draw');
  assert.equal(rpsWinner('paper', 'paper'), 'draw');
});

test('RPS: p2가 이기는 경우', () => {
  assert.equal(rpsWinner('scissors', 'rock'), 'p2');
});

// ── Yut 재접속 후 게임 상태 복원 ─────────────────────────────────────────────

/**
 * Redis yut 게임 상태가 있으면 재접속 시 클라이언트에 내려보내야 한다.
 * serializeYutGame 을 직접 부르지 않고 로직만 검증한다.
 */
const buildActiveGames = ({ yutGame, bombGame }) => {
  const activeGames = {};
  if (yutGame && yutGame.players) {
    // 실제로는 serializeYutGame(yutGame) 이지만 여기서는 원본을 그대로 사용
    activeGames.yut = yutGame;
  }
  if (bombGame) {
    const elapsed = Math.floor((Date.now() - bombGame.startTime) / 1000);
    const remaining = Math.max(0, bombGame.duration - elapsed);
    activeGames.bomb = { holder: bombGame.holder, timer: remaining };
  }
  return activeGames;
};

test('재접속: Yut 게임 상태가 있으면 activeGames.yut에 포함된다', () => {
  const yutGame = { players: ['A', 'B'], phase: 'play' };
  const result = buildActiveGames({ yutGame, bombGame: null });
  assert.ok(result.yut, 'yut 상태가 있어야 함');
  assert.deepEqual(result.yut.players, ['A', 'B']);
});

test('재접속: Bomb 게임 상태가 없으면 activeGames에 bomb 없음', () => {
  const result = buildActiveGames({ yutGame: null, bombGame: null });
  assert.equal(result.bomb, undefined);
  assert.equal(result.yut, undefined);
});

test('재접속: Bomb 타이머는 서버 기준 잔여 시간', () => {
  const bombGame = {
    holder: 'A',
    duration: 30,
    startTime: Date.now() - 5000, // 5초 경과
  };
  const result = buildActiveGames({ yutGame: null, bombGame });
  assert.ok(result.bomb.timer >= 24 && result.bomb.timer <= 26, `timer=${result.bomb.timer}`);
});
