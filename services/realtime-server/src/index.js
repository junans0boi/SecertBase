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
