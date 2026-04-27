import dotenv from "dotenv";

dotenv.config();

export const env = {
  host: process.env.HOST ?? "0.0.0.0",
  port: Number(process.env.PORT ?? 4000),
  jwtSecret: process.env.JWT_SECRET ?? "dev-only-secret-change-me",
  corsOrigin: process.env.CORS_ORIGIN ?? "*",
};

if (env.jwtSecret === "dev-only-secret-change-me" && process.env.NODE_ENV === "production") {
  throw new Error("JWT_SECRET must be configured in production");
}
