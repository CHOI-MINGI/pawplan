import { Router } from "express";
import { AuthedRequest, hashPassword, requireAuth, signAccessToken, verifyPassword } from "../auth.js";
import { asyncHandler, HttpError, ok, requireString } from "../http.js";
import { prisma } from "../prisma.js";

export const authRoutes = Router();

authRoutes.post(
  "/register",
  asyncHandler(async (req, res) => {
    const email = requireString(req.body.email, "email").toLowerCase();
    const password = requireString(req.body.password, "password");
    const name = requireString(req.body.name, "name");
    const phone = typeof req.body.phone === "string" ? req.body.phone.trim() : undefined;

    if (password.length < 8) {
      throw new HttpError(400, "VALIDATION_ERROR", "password must be at least 8 characters");
    }

    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) {
      throw new HttpError(409, "CONFLICT", "email already exists");
    }

    const user = await prisma.user.create({
      data: {
        email,
        passwordHash: await hashPassword(password),
        name,
        phone,
      },
      select: { id: true, email: true, name: true, phone: true },
    });

    ok(res, user, 201);
  }),
);

authRoutes.post(
  "/login",
  asyncHandler(async (req, res) => {
    const email = requireString(req.body.email, "email").toLowerCase();
    const password = requireString(req.body.password, "password");
    const user = await prisma.user.findUnique({ where: { email } });

    if (!user || !(await verifyPassword(password, user.passwordHash))) {
      throw new HttpError(401, "UNAUTHORIZED", "invalid email or password");
    }

    await prisma.user.update({ where: { id: user.id }, data: { lastLoginAt: new Date() } });

    ok(res, {
      accessToken: signAccessToken(user.id),
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
      },
    });
  }),
);

authRoutes.get(
  "/me",
  requireAuth,
  asyncHandler(async (req, res) => {
    const userId = (req as AuthedRequest).userId;
    const user = await prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: { id: true, email: true, name: true, phone: true, status: true },
    });
    ok(res, user);
  }),
);
