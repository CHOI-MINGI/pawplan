import { Prisma } from "@prisma/client";
import type { NextFunction, Request, Response } from "express";

export class HttpError extends Error {
  status: number;
  code: string;

  constructor(status: number, code: string, message: string) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

export type AsyncHandler = (req: Request, res: Response, next: NextFunction) => Promise<void>;

export function asyncHandler(handler: AsyncHandler) {
  return (req: Request, res: Response, next: NextFunction) => {
    handler(req, res, next).catch(next);
  };
}

export function ok(res: Response, data: unknown, status = 200) {
  res.status(status).json(serialize({ success: true, data }));
}

export function parseId(value: string | undefined, label = "id") {
  if (!value || !/^\d+$/.test(value)) {
    throw new HttpError(400, "VALIDATION_ERROR", `${label} must be a positive integer`);
  }
  return BigInt(value);
}

export function requireString(value: unknown, label: string) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpError(400, "VALIDATION_ERROR", `${label} is required`);
  }
  return value.trim();
}

export function optionalDate(value: unknown) {
  if (value === undefined || value === null || value === "") return undefined;
  const date = new Date(String(value));
  if (Number.isNaN(date.getTime())) {
    throw new HttpError(400, "VALIDATION_ERROR", "invalid date");
  }
  return date;
}

export function optionalNumber(value: unknown) {
  if (value === undefined || value === null || value === "") return undefined;
  const number = Number(value);
  if (!Number.isFinite(number)) {
    throw new HttpError(400, "VALIDATION_ERROR", "invalid number");
  }
  return number;
}

export function serialize(value: unknown): unknown {
  if (typeof value === "bigint") return Number(value);
  if (value instanceof Date) return value.toISOString();
  if (value instanceof Prisma.Decimal) return value.toNumber();
  if (Array.isArray(value)) return value.map(serialize);
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, serialize(item)]));
  }
  return value;
}
