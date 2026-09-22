import { Hono } from "hono";
import { fromBinary } from "@bufbuild/protobuf";
import { CloudEnvelopeSchema } from "../generated/dndsync/v1/cloud_envelope_pb.js";
import {
  authenticatePair,
  bearerToken,
  requireAppKey,
  safeEqualHex,
  sha256Hex,
} from "./auth.js";
import { isApnsEnvironment, sendJoinedApns, sendSilentApns } from "./apns.js";
import { sendDataFcm } from "./fcm.js";
import { wakeMacOnJoin } from "./join_wake.js";
import {
  createPair,
  deletePair,
  getDevice,
  listDevicePublicKeys,
  upsertDevice,
  type ApnsEnvironment,
  type Platform,
  type Sender,
} from "./store.js";

const MAX_PUSH_JSON_BYTES = 4096;

function isSender(value: unknown): value is Sender {
  return value === "mac" || value === "android";
}

function isPlatform(value: unknown): value is Platform {
  return value === "apns" || value === "fcm";
}

function apnsEnvironmentOf(body: {
  platform?: string;
  apns_environment?: string;
}): ApnsEnvironment | undefined {
  if (body.platform !== "apns" || !isApnsEnvironment(body.apns_environment)) {
    return undefined;
  }
  return body.apns_environment;
}

function otherSender(sender: Sender): Sender {
  return sender === "mac" ? "android" : "mac";
}

export const app = new Hono();

app.get("/health", (c) => c.json({ ok: true }));

app.post("/v1/pairs", async (c) => {
  if (!requireAppKey(c)) {
    return c.json({ error: "unauthorized" }, 401);
  }
  const body = await c.req.json<{
    pair_id?: string;
    secret_hash?: string;
    sender?: string;
    platform?: string;
    token?: string;
    e2e_public_key?: string;
    apns_environment?: string;
  }>();
  const pairId = body.pair_id?.trim() ?? "";
  const secretHash = body.secret_hash?.trim() ?? "";
  if (!pairId || !/^[a-f0-9]{64}$/i.test(secretHash)) {
    return c.json({ error: "invalid pair" }, 400);
  }
  if (!isSender(body.sender) || !isPlatform(body.platform) || !body.token) {
    return c.json({ error: "invalid device" }, 400);
  }
  await createPair(pairId, secretHash.toLowerCase());
  await upsertDevice(pairId, body.sender, {
    platform: body.platform,
    token: body.token,
    e2ePublicKey: body.e2e_public_key,
    apnsEnvironment: apnsEnvironmentOf(body),
  });
  return c.body(null, 201);
});

app.post("/v1/pairs/:pairId/join", async (c) => {
  const secret = bearerToken(c);
  if (!secret) {
    return c.json({ error: "unauthorized" }, 401);
  }
  const pairId = c.req.param("pairId");
  const pair = await authenticatePair(pairId, secret);
  if (!pair) {
    return c.json({ error: "unauthorized" }, 401);
  }
  const body = await c.req.json<{
    sender?: string;
    platform?: string;
    token?: string;
    e2e_public_key?: string;
    apns_environment?: string;
  }>();
  if (!isSender(body.sender) || !isPlatform(body.platform) || !body.token) {
    return c.json({ error: "invalid device" }, 400);
  }
  await upsertDevice(pairId, body.sender, {
    platform: body.platform,
    token: body.token,
    e2ePublicKey: body.e2e_public_key,
    apnsEnvironment: apnsEnvironmentOf(body),
  });
  if (body.sender === "android") {
    try {
      await wakeMacOnJoin(pairId, sendJoinedApns);
    } catch (error) {
      const message = error instanceof Error ? error.message : "join wake failed";
      console.error("join wake failed", message);
    }
  }
  return c.body(null, 204);
});

app.get("/v1/pairs/:pairId/devices", async (c) => {
  const secret = bearerToken(c);
  if (!secret) {
    return c.json({ error: "unauthorized" }, 401);
  }
  const pairId = c.req.param("pairId");
  const pair = await authenticatePair(pairId, secret);
  if (!pair) {
    return c.json({ error: "unauthorized" }, 401);
  }
  const devices = await listDevicePublicKeys(pairId);
  return c.json({
    devices: devices.map((device) => ({
      sender: device.sender,
      e2e_public_key: device.e2ePublicKey ?? "",
    })),
  });
});

app.put("/v1/pairs/:pairId/devices", async (c) => {
  const secret = bearerToken(c);
  if (!secret) {
    return c.json({ error: "unauthorized" }, 401);
  }
  const pairId = c.req.param("pairId");
  const pair = await authenticatePair(pairId, secret);
  if (!pair) {
    const expected = (process.env.DEV_PAIR_SECRET_HASH ?? "").toLowerCase();
    const incoming = sha256Hex(secret).toLowerCase();
    if (!expected || !safeEqualHex(incoming, expected)) {
      return c.json({ error: "unauthorized" }, 401);
    }
    await createPair(pairId, expected);
  }
  const body = await c.req.json<{
    sender?: string;
    platform?: string;
    token?: string;
    e2e_public_key?: string;
    apns_environment?: string;
  }>();
  if (!isSender(body.sender) || !isPlatform(body.platform) || !body.token) {
    return c.json({ error: "invalid device" }, 400);
  }
  await upsertDevice(pairId, body.sender, {
    platform: body.platform,
    token: body.token,
    e2ePublicKey: body.e2e_public_key,
    apnsEnvironment: apnsEnvironmentOf(body),
  });
  return c.body(null, 204);
});

app.post("/v1/pairs/:pairId/envelopes", async (c) => {
  const secret = bearerToken(c);
  if (!secret) {
    return c.json({ error: "unauthorized" }, 401);
  }
  const pairId = c.req.param("pairId");
  const pair = await authenticatePair(pairId, secret);
  if (!pair) {
    return c.json({ error: "unauthorized" }, 401);
  }
  const contentType = c.req.header("Content-Type") ?? "";
  if (!contentType.includes("application/protobuf")) {
    return c.json({ error: "unsupported media type" }, 415);
  }
  const bytes = new Uint8Array(await c.req.arrayBuffer());
  let envelope;
  try {
    envelope = fromBinary(CloudEnvelopeSchema, bytes);
  } catch {
    return c.json({ error: "invalid envelope" }, 400);
  }
  if (envelope.version !== 1) {
    return c.json({ error: "unsupported version" }, 400);
  }
  if (envelope.pairId !== pairId) {
    return c.json({ error: "pair mismatch" }, 400);
  }
  if (!isSender(envelope.sender)) {
    return c.json({ error: "invalid sender" }, 400);
  }
  const peer = await getDevice(pairId, otherSender(envelope.sender));
  if (!peer?.token) {
    console.error(`[DEBUG] envelope sender=${envelope.sender} peer has no token`);
    return c.json({ error: "peer not registered" }, 409);
  }
  console.log(
    `[DEBUG] envelope sender=${envelope.sender} peer=${peer.platform} apns=${peer.apnsEnvironment ?? "unset"}`,
  );
  const envelopeB64 = Buffer.from(bytes).toString("base64");
  const previewSize = Buffer.byteLength(
    JSON.stringify({
      aps: { "content-available": 1 },
      envelope_b64: envelopeB64,
    }),
    "utf8",
  );
  if (previewSize > MAX_PUSH_JSON_BYTES) {
    return c.json({ error: "payload too large" }, 413);
  }
  try {
    if (peer.platform === "apns") {
      const delivery = await sendSilentApns(peer.token, envelopeB64, peer.apnsEnvironment);
      c.header("X-Apns-Host", delivery.host);
      c.header("X-Apns-Id", delivery.apnsId);
      c.header("X-Apns-Token-Suffix", delivery.tokenSuffix);
      c.header("X-Apns-Push-Type", delivery.pushType);
    } else if (peer.platform === "fcm") {
      await sendDataFcm(peer.token, envelopeB64);
    } else {
      return c.json({ error: "unknown peer platform" }, 400);
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : "push failed";
    console.error("push failed", message);
    return c.json({ error: message }, 502);
  }
  return c.body(null, 204);
});

app.delete("/v1/pairs/:pairId", async (c) => {
  const secret = bearerToken(c);
  if (!secret) {
    return c.json({ error: "unauthorized" }, 401);
  }
  const pairId = c.req.param("pairId");
  const pair = await authenticatePair(pairId, secret);
  if (!pair) {
    return c.json({ error: "unauthorized" }, 401);
  }
  await deletePair(pairId);
  return c.body(null, 204);
});
