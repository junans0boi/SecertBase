import dotenv from "dotenv";
import { z } from "zod";

dotenv.config();

const schema = z.object({
  PORT: z.coerce.number().int().min(1).max(65535).default(4100),
  CORS_ORIGIN: z.string().url(),
  REDIS_URL: z.string().url(),
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
