import cors from "cors";
import express from "express";
import multer from "multer";
import { authRoutes } from "./routes/authRoutes.js";
import { appRoutes } from "./routes/appRoutes.js";
import { env } from "./env.js";
import { HttpError } from "./http.js";
import { prisma } from "./prisma.js";

const app = express();

app.use(cors({ origin: env.corsOrigin === "*" ? true : env.corsOrigin }));
app.use(express.json({ limit: "1mb" }));

app.get("/health", (_req, res) => {
  res.json({ ok: true });
});

app.use("/api/v1/auth", authRoutes);
app.use("/api/v1", appRoutes);

app.use(
  (
    error: unknown,
    _req: express.Request,
    res: express.Response,
    _next: express.NextFunction,
  ) => {
    if (
      error &&
      typeof error === "object" &&
      "type" in error &&
      (error as { type?: unknown }).type === "entity.parse.failed"
    ) {
      res.status(400).json({
        success: false,
        error: {
          code: "VALIDATION_ERROR",
          message: "invalid JSON body",
        },
      });
      return;
    }

    if (error instanceof HttpError) {
      res.status(error.status).json({
        success: false,
        error: {
          code: error.code,
          message: error.message,
        },
      });
      return;
    }

    if (error instanceof multer.MulterError) {
      res.status(400).json({
        success: false,
        error: {
          code: "VALIDATION_ERROR",
          message:
            error.code === "LIMIT_FILE_SIZE"
              ? "file must be 8MB or smaller"
              : error.message,
        },
      });
      return;
    }

    console.error(error);
    res.status(500).json({
      success: false,
      error: {
        code: "INTERNAL_SERVER_ERROR",
        message: "unexpected server error",
      },
    });
  },
);

const server = app.listen(env.port, env.host, () => {
  console.log(`PawPlan API listening on http://${env.host}:${env.port}`);
});

async function shutdown() {
  server.close();
  await prisma.$disconnect();
}

process.on("SIGINT", () => void shutdown());
process.on("SIGTERM", () => void shutdown());
