// 그림 맞히기: 맞히는 사람이 받는 모든 이벤트(상태·획·재생·sync·session:restore·힌트·추측)에
// 라운드가 끝나기 전에는 제시어와 동의어가 한 번도 들어 있지 않다. 6라운드 전체를 돌며 확인한다.
import assert from 'node:assert/strict';
import test from 'node:test';
import { fixture, flush } from './support/socket-harness.js';
import { setCatchRandom, CATCH_REVEAL_MS } from '../src/games/catch.js';
const A='ALPHA-code';
test('catch: guesser payloads never contain the word before reveal', async (t) => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 1_000_000 });
  setCatchRandom(() => 0.3); t.after(() => setCatchRandom());
  const seen = [[], []];
  f.clients.forEach((c, i) => c.onAny((ev, ...args) => seen[i].push({ ev, json: JSON.stringify(args) })));
  await f.call(0, 'game:lobby:join', { gameType: 'catch' }); await f.call(1, 'game:lobby:join', { gameType: 'catch' });
  await f.call(0, 'game:lobby:start', { gameType: 'catch' }); await flush();
  const key = `game:${f.roomCode}:catch`;
  for (let round = 1; round <= 6; round++) {
    const st = JSON.parse(await f.redis.get(key));
    const word = st.word, aliases = st.aliases;
    const g = st.drawer === A ? 1 : 0, d = 1 - g;
    seen[g].length = 0;
    // stroke, hint, sync, restore, wrong guess
    await f.call(d, 'game:catch:stroke', { round: st.round, id: 's1', seq: 0, tool: 'pen', color: 1, w: 0.01, pts: [[0.1,0.1],[0.2,0.2]], end: true });
    await f.call(g, 'game:catch:hint', { round: st.round });
    await f.call(g, 'game:catch:sync', {});
    await f.call(g, 'session:restore', {});
    await f.call(g, 'game:catch:guess', { round: st.round, text: '아무말' });
    f.tick(31_000); await flush();
    f.tick(16_000); await flush();
    await f.call(g, 'game:catch:sync', {});
    const joined = seen[g].map(x => x.json).join('\n');
    for (const w of [word, ...aliases]) assert.equal(joined.includes(w), false, `round ${round} leaked ${w}`);
    // now end the round by a correct guess; 
    f.tick(1000); await flush();
    await f.call(g, 'game:catch:guess', { round: st.round, text: word }); await flush();
    f.tick(CATCH_REVEAL_MS + 100); await flush();
  }
});
