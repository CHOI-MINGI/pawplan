import bcrypt from "bcrypt";
import type { NextFunction, Request, Response } from "express";
import jwt from "jsonwebtoken";
import { env } from "./env.js";
import { HttpError } from "./http.js";

export type AuthedRequest = Request & {
  userId: bigint;
};

type JwtPayload = {
  sub: string;
};

export async function hashPassword(password: string) {
  return bcrypt.hash(password, 12);
}

export async function verifyPassword(password: string, hash: string) {
  return bcrypt.compare(password, hash);
}

export function signAccessToken(userId: bigint) {
  return jwt.sign({ sub: userId.toString() }, env.jwtSecret, { expiresIn: "7d" });
}

export function requireAuth(req: Request, _res: Response, next: NextFunction) {
  const header = req.header("authorization");
  const token = header?.startsWith("Bearer ") ? header.slice("Bearer ".length) : undefined;

  if (!token) {
    next(new HttpError(401, "UNAUTHORIZED", "missing access token"));
    return;
  }

  try {
    const payload = jwt.verify(token, env.jwtSecret) as JwtPayload;
    (req as AuthedRequest).userId = BigInt(payload.sub);
    next();
  } catch {
    next(new HttpError(401, "UNAUTHORIZED", "invalid access token"));
  }
}
