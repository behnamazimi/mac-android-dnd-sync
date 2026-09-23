import { createPrivateKey, sign } from "node:crypto";
import { connect, type ClientHttp2Session } from "node:http2";
import type { ApnsEnvironment } from "./store.js";

const TOPIC = "com.dndsync.macos";
const JWT_TTL_MS = 50 * 60 * 1000;
const SANDBOX_HOST = "https://api.sandbox.push.apple.com";
const PRODUCTION_HOST = "https://api.push.apple.com";

let cachedJwt: { token: string; expiresAt: number } | null = null;

export function isApnsEnvironment(value: unknown): value is ApnsEnvironment {
  return value === "sandbox" || value === "production";
}

export function hostsForPush(environment?: ApnsEnvironment): string[] {
  if (environment === "production") {
    return [PRODUCTION_HOST];
  }
  if (environment === "sandbox") {
    return [SANDBOX_HOST];
  }
  return [...apnsHosts()];
}

export function apnsHosts(): [string, string] {
  const configured = (process.env.APNS_HOST || SANDBOX_HOST).trim().replace(/\/$/, "");
  const preferred = configured.startsWith("http") ? configured : `https://${configured}`;
  if (preferred === PRODUCTION_HOST) {
    return [PRODUCTION_HOST, SANDBOX_HOST];
  }
  return [SANDBOX_HOST, PRODUCTION_HOST];
}

export function isWrongApnsEnvironment(status: string, responseBody: string): boolean {
  if (status !== "400") {
    return false;
  }
  return (
    responseBody.includes("BadDeviceToken") ||
    responseBody.includes("BadEnvironmentKeyInToken")
  );
}

function normalizeP8(raw: string): string {
  let p8 = raw.trim();
  if (
    (p8.startsWith('"') && p8.endsWith('"')) ||
    (p8.startsWith("'") && p8.endsWith("'"))
  ) {
    p8 = p8.slice(1, -1).trim();
  }
  p8 = p8.replace(/\\n/g, "\n").replace(/\r\n/g, "\n");
  const labeled = p8.match(
    /-----BEGIN ([A-Z ]*PRIVATE KEY)-----([\s\S]*?)-----END \1-----/,
  );
  const bodySource = labeled ? labeled[2] : p8;
  const body = bodySource.replace(/[^A-Za-z0-9+/=]/g, "");
  if (body.length < 80) {
    throw new Error("APNs P8 secret is not a PEM private key");
  }
  const wrapped = body.match(/.{1,64}/g)?.join("\n") ?? body;
  return `-----BEGIN PRIVATE KEY-----\n${wrapped}\n-----END PRIVATE KEY-----\n`;
}

function base64url(input: Buffer | string): string {
  const buf = typeof input === "string" ? Buffer.from(input) : input;
  return buf.toString("base64url");
}

function makeJwt(): string {
  const now = Date.now();
  if (cachedJwt && cachedJwt.expiresAt > now + 60_000) {
    return cachedJwt.token;
  }
  const keyId = process.env.APNS_KEY_ID?.trim();
  const teamId = process.env.APNS_TEAM_ID?.trim();
  const p8 = process.env.APNS_P8 ? normalizeP8(process.env.APNS_P8) : "";
  if (!keyId || !teamId || !p8) {
    throw new Error("APNs credentials are not configured");
  }
  const header = base64url(JSON.stringify({ alg: "ES256", kid: keyId }));
  const claims = base64url(
    JSON.stringify({ iss: teamId, iat: Math.floor(now / 1000) }),
  );
  const signingInput = `${header}.${claims}`;
  const signature = sign("SHA256", Buffer.from(signingInput), {
    key: createPrivateKey(p8),
    dsaEncoding: "ieee-p1363",
  });
  const token = `${signingInput}.${base64url(signature)}`;
  cachedJwt = { token, expiresAt: now + JWT_TTL_MS };
  return token;
}

const COLLAPSE_ID = "dndsync";

/** Apple may retry for this long. A Focus flip older than a minute is stale. */
export const APNS_EXPIRATION_SECONDS = 60;

export function apnsExpiration(nowMs = Date.now()): string {
  return String(Math.floor(nowMs / 1000) + APNS_EXPIRATION_SECONDS);
}

export function alertApnsHeaders(nowMs = Date.now()): Record<string, string> {
  return {
    "apns-push-type": "alert",
    "apns-priority": "10",
    "apns-expiration": apnsExpiration(nowMs),
    "apns-collapse-id": COLLAPSE_ID,
  };
}

export function alertPushBody(fields: Record<string, unknown>): string {
  return JSON.stringify({
    aps: {
      alert: { title: "Do Not Disturb Sync" },
      "interruption-level": "time-sensitive",
      "relevance-score": 1,
    },
    ...fields,
  });
}

export type ApnsDelivery = {
  host: string;
  apnsId: string;
  tokenSuffix: string;
  pushType: "alert";
};

export async function sendJoinedApns(
  deviceTokenHex: string,
  environment?: ApnsEnvironment,
): Promise<void> {
  await postAlertApns(deviceTokenHex, alertPushBody({ joined: true }), environment);
}

export async function sendAlertApns(
  deviceTokenHex: string,
  envelopeB64: string,
  environment?: ApnsEnvironment,
): Promise<ApnsDelivery> {
  return postAlertApns(
    deviceTokenHex,
    alertPushBody({ envelope_b64: envelopeB64 }),
    environment,
  );
}

async function postAlertApns(
  deviceTokenHex: string,
  body: string,
  environment?: ApnsEnvironment,
): Promise<ApnsDelivery> {
  const jwt = makeJwt();
  if (Buffer.byteLength(body, "utf8") > 4096) {
    throw new Error("APNs payload exceeds 4 KiB");
  }
  const token = deviceTokenHex.trim().replace(/\s+/g, "");
  const hosts = hostsForPush(environment);
  const tokenSuffix = token.slice(-8);
  console.log(
    `[DEBUG] apns env=${environment ?? "unset"} token=…${tokenSuffix} hosts=${hosts.join(" ")}`,
  );
  let last: Error | undefined;
  for (let i = 0; i < hosts.length; i++) {
    try {
      const apnsId = await postOnce(hosts[i], token, body, jwt);
      console.log(`[DEBUG] apns ${hosts[i]} 200 id=${apnsId}`);
      return { host: hosts[i], apnsId, tokenSuffix, pushType: "alert" };
    } catch (error) {
      const message = error instanceof Error ? error.message : "push failed";
      console.error(`[DEBUG] apns ${hosts[i]} ${message}`);
      if (!(error instanceof ApnsStatusError) || !error.wrongEnvironment || i === hosts.length - 1) {
        throw error;
      }
      last = error;
    }
  }
  throw last ?? new Error("APNs failed");
}

class ApnsStatusError extends Error {
  readonly wrongEnvironment: boolean;

  constructor(status: string, responseBody: string) {
    super(`APNs ${status}${responseBody ? `: ${responseBody}` : ""}`);
    this.wrongEnvironment = isWrongApnsEnvironment(status, responseBody);
  }
}

async function postOnce(
  host: string,
  token: string,
  body: string,
  jwt: string,
): Promise<string> {
  const client: ClientHttp2Session = connect(host);
  try {
    const { status, apnsId, responseBody } = await new Promise<{
      status: string;
      apnsId: string;
      responseBody: string;
    }>((resolve, reject) => {
      client.once("error", reject);
      const req = client.request({
        ":method": "POST",
        ":path": `/3/device/${token}`,
        authorization: `bearer ${jwt}`,
        "apns-topic": TOPIC,
        ...alertApnsHeaders(),
        "content-type": "application/json",
      });
      let status = "";
      let apnsId = "";
      const chunks: Buffer[] = [];
      req.on("response", (headers) => {
        status = String(headers[":status"] ?? "");
        apnsId = String(headers["apns-id"] ?? "");
      });
      req.on("data", (chunk) => chunks.push(chunk as Buffer));
      req.on("error", reject);
      req.on("end", () => {
        resolve({
          status,
          apnsId,
          responseBody: Buffer.concat(chunks).toString("utf8"),
        });
      });
      req.end(body);
    });
    if (status !== "200") {
      throw new ApnsStatusError(status, responseBody);
    }
    return apnsId;
  } finally {
    client.close();
  }
}
