import { createHash, timingSafeEqual } from "node:crypto";
import type { Context } from "hono";
import { getPair, type PairRecord } from "./store.js";

export function sha256Hex(value: string): string {
  return createHash("sha256").update(value, "utf8").digest("hex");
}

export function safeEqualString(left: string, right: string): boolean {
  const a = createHash("sha256").update(left, "utf8").digest();
  const b = createHash("sha256").update(right, "utf8").digest();
  return timingSafeEqual(a, b);
}

export function safeEqualHex(left: string, right: string): boolean {
  if (left.length !== right.length) {
    return false;
  }
  try {
    const a = Buffer.from(left, "hex");
    const b = Buffer.from(right, "hex");
    if (a.length !== b.length || a.length === 0) {
      return false;
    }
    return timingSafeEqual(a, b);
  } catch {
    return false;
  }
}

export function appKeyFromEnv(): string {
  return process.env.APP_KEY ?? "";
}

export function requireAppKey(c: Context): boolean {
  const expected = appKeyFromEnv();
  const provided = c.req.header("X-App-Key") ?? "";
  if (!expected) {
    return false;
  }
  return safeEqualString(provided, expected);
}

export function bearerToken(c: Context): string | null {
  const header = c.req.header("Authorization") ?? "";
  const match = /^Bearer\s+(.+)$/i.exec(header);
  if (!match) {
    return null;
  }
  const token = match[1].trim();
  return token.length > 0 ? token : null;
}

export async function authenticatePair(
  pairId: string,
  secret: string,
): Promise<PairRecord | null> {
  const pair = await getPair(pairId);
  if (!pair) {
    return null;
  }
  const incoming = sha256Hex(secret);
  if (!safeEqualHex(incoming, pair.secretHash)) {
    return null;
  }
  return pair;
}
