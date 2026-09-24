import assert from "node:assert/strict";
import test from "node:test";
import { peerFromPair } from "./store.js";

test("peer route comes from the pair doc when mirrored", () => {
  const route = peerFromPair(
    {
      secretHash: "x",
      devices: {
        mac: { platform: "apns", token: "mac-token", apnsEnvironment: "production" },
        android: { platform: "fcm", token: "fcm-token" },
      },
    },
    "mac",
  );
  assert.deepEqual(route, {
    platform: "apns",
    token: "mac-token",
    apnsEnvironment: "production",
  });
});

test("pair written before routes were mirrored falls back", () => {
  assert.equal(peerFromPair({ secretHash: "x" }, "android"), undefined);
});

test("missing peer or empty token falls back", () => {
  const pair = {
    secretHash: "x",
    devices: { mac: { platform: "apns" as const, token: "" } },
  };
  assert.equal(peerFromPair(pair, "mac"), undefined);
  assert.equal(peerFromPair(pair, "android"), undefined);
});
