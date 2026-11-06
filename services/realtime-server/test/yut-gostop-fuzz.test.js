// 판돈 게임(윷·고스톱) 소켓 퍼즐: 두 사람이 무작위로 던지고·두고·시간을 흘려 끝까지 간다.
// 불변식: 판은 항상 끝난다(막힘 없음), 끝은 한 번, 정산은 판 id당 한 번(두 거래), 영수증 = 실제 이동 코인,
// 차례가 아닌 동작과 끝난 뒤의 동작은 거부된다. 무작위는 고정 시드라 재현된다.
import assert from 'node:assert/strict';
import test from 'node:test';
import { boundary, fixture, flush } from './support/socket-harness.js';
const { yutRuntime } = await import('../src/games/yut.js');
const { gostopRuntime } = await import('../src/games/gostop.js');
const A = 'ALPHA-code', B = 'BETA-code';
let seed = 99;
const rnd = () => { seed = (seed * 1664525 + 1013904223) % 4294967296; return seed / 4294967296; };

function installWallet(t) {
  const baseQuery = boundary.query, baseTx = boundary.transaction;
  const wallet = { balances: { 11: 10000, 22: 10000 }, transfers: [], refs: new Set() };
  boundary.query = async (sql, params) => {
    if (sql.includes('SELECT UserId FROM Users WHERE UserCode')) return { rows: [{ UserId: params[0] === A ? 11 : 22 }] };
    return baseQuery(sql, params);
  };
  boundary.transaction = async run => baseTx(conn => run({
    execute: async (sql, params) => {
      if (sql.includes('INSERT IGNORE INTO wallets')) return [[]];
      if (sql.includes('FROM wallet_transactions')) return [wallet.refs.has(params[0]) ? [{ id: 1 }] : []];
      if (sql.includes('SELECT balance FROM wallets')) return [[{ balance: wallet.balances[params[0]] }]];
      if (sql.includes('UPDATE wallets SET balance')) { wallet.balances[params[1]] = params[0]; return [[]]; }
      if (sql.includes('INSERT INTO wallet_transactions')) { wallet.transfers.push({ user: params[0], delta: params[1], ref: params[4] }); wallet.refs.add(params[4]); return [[]]; }
      return conn.execute(sql, params);
    },
  }));
  t.after(() => { boundary.query = baseQuery; boundary.transaction = baseTx; });
  return wallet;
}

async function lobby(f, type, stake) {
  await f.call(0, 'game:lobby:join', { gameType: type });
  await f.call(1, 'game:lobby:join', { gameType: type });
  await f.call(0, 'game:lobby:set_stake', { gameType: type, stake });
  await f.call(1, 'game:lobby:ready', { gameType: type, ready: true });
  assert.equal((await f.call(0, 'game:lobby:start', { gameType: type })).ok, true);
  await flush();
}

test('fuzz yut module', async t => {
  yutRuntime.random = rnd;
  t.after(() => { yutRuntime.random = Math.random; });
  for (let g = 0; g < 15; g++) {
    const f = await fixture(t);
    t.mock.timers.enable({ apis: ['Date'], now: 1_000_000 });
    const wallet = installWallet(t);
    await lobby(f, 'yut', 100);
    const ended = [];
    f.clients[0].on('game:yut:ended', e => ended.push(e));
    let states = [null, null];
    f.clients.forEach((c, i) => c.on('game:yut:state', s => { states[i] = s; }));
    for (const i of [0,1]) await f.call(i, 'game:yut:sync', {});
    let steps = 0;
    while (!ended.length && steps++ < 3000) {
      const r = rnd();
      if (r < 0.15) { f.tick(31000); await flush(); continue; }
      const i = Math.floor(rnd() * 2);
      const s = states[i];
      if (!s) { await f.call(i, 'game:yut:sync', {}); continue; }
      const me = i === 0 ? A : B;
      if (s.canThrow && (rnd() < 0.5 || !s.legalMoves.length)) await f.call(i, 'game:yut:throw', {});
      else if (s.legalMoves.length) { const m = s.legalMoves[Math.floor(rnd() * s.legalMoves.length)]; await f.call(i, 'game:yut:move', { pieceId: m.pieceId, moveIndex: m.moveIndex, backdoDir: m.backdoDir }); }
      else await f.call(i, 'game:yut:throw', {});
      await flush();
    }
    assert.equal(ended.length, 1, 'ended exactly once game ' + g);
    await flush();
    const refs = [...new Set(wallet.transfers.map(x => x.ref))];
    assert.equal(refs.length, 1);
    assert.equal(wallet.transfers.length, 2);
    const w = wallet.transfers.find(x => x.user === (ended[0].winner === A ? 11 : 22));
    const l = wallet.transfers.find(x => x.user === (ended[0].loser === A ? 11 : 22));
    assert.ok(w.delta >= 100 && l.delta === -100, JSON.stringify([w, l, ended[0].reason]));
    for (const ev of ['throw', 'move']) assert.notEqual((await f.call(0, 'game:yut:' + ev, {})).ok, true);
    t.mock.timers.reset();
  }
});

test('fuzz gostop module', async t => {
  gostopRuntime.random = rnd;
  t.after(() => { gostopRuntime.random = Math.random; });
  const results = {};
  for (let g = 0; g < 25; g++) {
    const f = await fixture(t);
    t.mock.timers.enable({ apis: ['Date'], now: 1_000_000 });
    const wallet = installWallet(t);
    await lobby(f, 'gostop', 100);
    const ended = [];
    f.clients[0].on('game:gostop:ended', e => ended.push(e));
    const states = [null, null];
    f.clients.forEach((c, i) => c.on('game:gostop:state', s => { states[i] = s; }));
    for (const i of [0,1]) await f.call(i, 'game:gostop:sync', {});
    let steps = 0;
    while (!ended.length && steps++ < 3000) {
      if (rnd() < 0.1) { f.tick(26000); await flush(); continue; }
      const i = Math.floor(rnd() * 2);
      const s = states[i]; const me = i === 0 ? A : B;
      if (!s) { await f.call(i, 'game:gostop:sync', {}); continue; }
      if (s.current !== me) { // out-of-turn attempt must fail
        const a = await f.call(i, 'game:gostop:decide', { decision: 'stop' });
        assert.equal(a.ok, false);
        continue;
      }
      let a;
      switch (s.phase) {
        case 'chongtong': a = await f.call(i, 'game:gostop:chongtong', { declare: rnd() < 0.5 }); break;
        case 'go_stop': a = await f.call(i, 'game:gostop:decide', { decision: rnd() < 0.6 ? 'go' : 'stop' }); break;
        case 'choice': a = await f.call(i, 'game:gostop:choose', { cardId: s.pending.options[Math.floor(rnd()*s.pending.options.length)].id }); break;
        case 'playing': {
          if (s.moves.bombable.length && rnd() < 0.5) a = await f.call(i, 'game:gostop:bomb', { month: s.moves.bombable[0] });
          else if (s.hand.length === 0 || (s.moves.dotan > 0 && rnd() < 0.4)) a = await f.call(i, 'game:gostop:dotan', {});
          else { const c = s.hand[Math.floor(rnd()*s.hand.length)]; a = await f.call(i, 'game:gostop:play', { cardId: c.id, shake: s.moves.shakeable.includes(c.month) && rnd() < 0.5 }); }
        }
      }
      assert.equal(a.ok, true, JSON.stringify([a, s.phase, s.hand.length, s.moves]));
      await flush();
    }
    assert.equal(ended.length, 1, 'ended once ' + g);
    await flush();
    const e = ended[0];
    results[e.reason] = (results[e.reason] ?? 0) + 1;
    if (e.reason !== 'nagari' && e.receipt.amount > 0) {
      const refs = new Set(wallet.transfers.map(x => x.ref));
      assert.equal(refs.size, 1);
      assert.equal(wallet.transfers.length, 2);
      const w = wallet.transfers.find(x => x.user === (e.winner === A ? 11 : 22));
      assert.equal(w.delta, e.receipt.transferred);
      assert.equal(e.receipt.transferred, Math.min(e.receipt.amount, 10000));
    } else assert.equal(wallet.transfers.length, 0);
    assert.notEqual((await f.call(0, 'game:gostop:decide', { decision: 'stop' })).ok, true);
    t.mock.timers.reset();
  }
  assert.ok(Object.keys(results).length >= 2, 'the fuzz reaches more than one way to end');
});
