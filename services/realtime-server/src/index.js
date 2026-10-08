import { config } from './config.js';
import { redis } from './redis.js';
import apiRoutes from './routes.js';
import { registerSocketHandlers } from './socket.js';
import { createRealtimeServer } from './app/create-realtime-server.js';

const realtime = createRealtimeServer({
  config,
  redis,
  routes: apiRoutes,
  registerSocketHandlers,
});

realtime.httpServer.listen(config.PORT, () => {
  console.log(`Secret Base realtime server listening on :${config.PORT}`);
  console.log(`REST API available at http://localhost:${config.PORT}/api`);
});
