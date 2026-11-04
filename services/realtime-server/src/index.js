import { config } from './config.js';
import { redis } from './redis.js';
import apiRoutes from './routes.js';
import { registerSocketHandlers } from './socket.js';
import { createRealtimeServer } from './app/create-realtime-server.js';
import { assertSchemaReady } from './schema-readiness.js';
import cron from 'node-cron';
import { query } from './db.js';
import { businessDate } from './business-date.js';
import { notifier } from './modules/notifications/index.js';
import { startTodayLoopScheduler } from './modules/notifications/notifier.js';

// 개별 요청 실패가 프로세스 전체를 종료시키지 않도록 마지막 방어선을 둔다.
process.on('unhandledRejection', (reason) => {
  console.error('[process] unhandledRejection:', reason?.stack ?? reason);
});
process.on('uncaughtException', (err) => {
  console.error('[process] uncaughtException:', err?.stack ?? err);
});

const realtime = createRealtimeServer({
  config,
  redis,
  routes: apiRoutes,
  registerSocketHandlers,
});

await assertSchemaReady();

startTodayLoopScheduler({ cron, queryFn: query, redis, notifier, businessDate });

realtime.httpServer.listen(config.PORT, () => {
  console.log(`Secret Base realtime server listening on :${config.PORT}`);
  console.log(`REST API available at http://localhost:${config.PORT}/api`);
});
