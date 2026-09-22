import { createPrivateKey, sign } from "node:crypto";
import { connect, type ClientHttp2Session } from "node:http2";

const TOPIC = "com.dndsync.macos";
const JWT_TTL_MS = 50 * 60 * 1000;

let cachedJwt: { token: string; expiresAt: number } | null = null;

function apnsHost(): string {
  let host = (process.env.APNS_HOST || "https://api.sandbox.push.apple.com").trim();
  if (!host.startsWith("http")) {
    host = `https://${host}`;
  }
  return host.replace(/\/$/, "");
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

export function silentPushBody(fields: Record<string, unknown>): string {
  return JSON.stringify({
    aps: { "content-available": 1 },
    ...fields,
  });
}

export async function sendJoinedApns(deviceTokenHex: string): Promise<void> {
  await postSilentApns(deviceTokenHex, silentPushBody({ joined: true }));
}

export async function sendSilentApns(
  deviceTokenHex: string,
  envelopeB64: string,
): Promise<void> {
  await postSilentApns(
    deviceTokenHex,
    silentPushBody({ envelope_b64: envelopeB64 }),
  );
}

async function postSilentApns(
  deviceTokenHex: string,
  body: string,
): Promise<void> {
  const jwt = makeJwt();
  if (Buffer.byteLength(body, "utf8") > 4096) {
    throw new Error("APNs payload exceeds 4 KiB");
  }
  const token = deviceTokenHex.trim().replace(/\s+/g, "");
  const client: ClientHttp2Session = connect(apnsHost());
  try {
    const { status, responseBody } = await new Promise<{
      status: string;
      responseBody: string;
    }>((resolve, reject) => {
      client.once("error", reject);
      const req = client.request({
        ":method": "POST",
        ":path": `/3/device/${token}`,
        authorization: `bearer ${jwt}`,
        "apns-topic": TOPIC,
        "apns-push-type": "background",
        "apns-priority": "5",
        "content-type": "application/json",
      });
      let status = "";
      const chunks: Buffer[] = [];
      req.on("response", (headers) => {
        status = String(headers[":status"] ?? "");
      });
      req.on("data", (chunk) => chunks.push(chunk as Buffer));
      req.on("error", reject);
      req.on("end", () => {
        resolve({
          status,
          responseBody: Buffer.concat(chunks).toString("utf8"),
        });
      });
      req.end(body);
    });
    if (status !== "200") {
      throw new Error(`APNs ${status}${responseBody ? `: ${responseBody}` : ""}`);
    }
  } finally {
    client.close();
  }
}
