import Redis from "ioredis";
import { config } from "./config.js";

export const redis = new Redis(config.REDIS_URL, {
  maxRetriesPerRequest: 3,
  enableReadyCheck: true,
  keyPrefix: config.REDIS_KEY_PREFIX,
});

redis.on("error", (error) => {
  console.error("Redis error:", error.message);
});
