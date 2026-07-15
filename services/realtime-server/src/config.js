import dotenv from "dotenv";
import { z } from "zod";
import { assertSafeTestRuntime } from "./target-safety.js";

dotenv.config();

const schema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  PORT: z.coerce.number().int().min(1).max(65535).default(4100),
  CORS_ORIGIN: z
    .string()
    .min(1)
    .transform((value) =>
      value
        .split(",")
        .map((item) => item.trim())
        .filter(Boolean),
    )
    .refine(
      (origins) =>
        origins.length > 0 &&
        origins.every((origin) => z.string().url().safeParse(origin).success),
      "CORS_ORIGIN must contain valid URL origins",
    ),
  REDIS_URL: z.string().url(),
  REDIS_KEY_PREFIX: z.string().optional().default(""),
  PRODUCTION_REDIS_URL: z.string().url().optional(),
  DATABASE_URL: z.string().url(),
  PRODUCTION_DATABASE_URL: z.string().url().optional(),
  UPLOADS_ROOT: z.string().optional().default("uploads"),
  JWT_SECRET: z.string().min(32),
  GOOGLE_CLIENT_ID: z.string().optional().default(""),
  KAKAO_REVIEW_AUTO_LOGIN: z
    .string()
    .optional()
    .default("false")
    .transform((value) => value === "true"),
  KAKAO_REVIEW_EMAIL: z.string().optional().default(""),
  KAKAO_REST_API_KEY: z.string().optional().default(""),
  NAVER_SEARCH_CLIENT_ID: z.string().optional().default(""),
  NAVER_SEARCH_CLIENT_SECRET: z.string().optional().default(""),
  NAVER_MAPS_CLIENT_ID: z.string().optional().default(""),
  NAVER_MAPS_CLIENT_SECRET: z.string().optional().default(""),
  ROOM_SECRET: z.string().min(4),
  ALLOWED_USERS: z
    .string()
    .min(1)
    .transform((value) =>
      value
        .split(",")
        .map((item) => item.trim())
        .filter(Boolean),
    )
    .refine((users) => users.length === 2, "ALLOWED_USERS must contain 2 users"),
});

const parsed = schema.safeParse(process.env);
if (!parsed.success) {
  console.error("Invalid environment configuration");
  console.error(parsed.error.flatten().fieldErrors);
  process.exit(1);
}

export const config = parsed.data;

if (config.NODE_ENV === "test") {
  assertSafeTestRuntime({
    databaseUrl: config.DATABASE_URL,
    redisUrl: config.REDIS_URL,
    redisNamespace: config.REDIS_KEY_PREFIX,
    uploadsRoot: config.UPLOADS_ROOT,
    productionDatabaseUrl: config.PRODUCTION_DATABASE_URL,
    productionRedisUrl: config.PRODUCTION_REDIS_URL,
  });
}
