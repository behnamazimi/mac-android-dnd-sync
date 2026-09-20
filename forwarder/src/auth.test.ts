import assert from "node:assert/strict";
import { test } from "node:test";
import {
  appKeyFromEnv,
  bearerToken,
  requireAppKey,
  safeEqualHex,
  safeEqualString,
  sha256Hex,
} from "./auth.js";

function fakeContext(headers: Record<string, string>): any {
  return {
    req: {
      header: (name: string) => headers[name],
    },
  };
}

test("sha256Hex is deterministic and hex-encoded", () => {
  const digest = sha256Hex("hello");
  assert.equal(digest.length, 64);
  assert.match(digest, /^[0-9a-f]{64}$/);
  assert.equal(digest, sha256Hex("hello"));
  assert.notEqual(digest, sha256Hex("hello2"));
});

test("safeEqualString compares by content, not reference", () => {
  assert.equal(safeEqualString("secret", "secret"), true);
  assert.equal(safeEqualString("secret", "other"), false);
  assert.equal(safeEqualString("", ""), true);
});

test("safeEqualHex rejects mismatched length, non-hex, and empty input", () => {
  const hex = sha256Hex("value");
  assert.equal(safeEqualHex(hex, hex), true);
  assert.equal(safeEqualHex(hex, sha256Hex("other")), false);
  assert.equal(safeEqualHex("abc", "abcd"), false);
  assert.equal(safeEqualHex("not-hex!!", "not-hex!!"), false);
  assert.equal(safeEqualHex("", ""), false);
});

test("appKeyFromEnv reads APP_KEY and defaults to empty", () => {
  const prior = process.env.APP_KEY;
  try {
    delete process.env.APP_KEY;
    assert.equal(appKeyFromEnv(), "");
    process.env.APP_KEY = "test-app-key";
    assert.equal(appKeyFromEnv(), "test-app-key");
  } finally {
    if (prior === undefined) {
      delete process.env.APP_KEY;
    } else {
      process.env.APP_KEY = prior;
    }
  }
});

test("requireAppKey fails closed when APP_KEY is unset, even if a header matches", () => {
  const prior = process.env.APP_KEY;
  try {
    delete process.env.APP_KEY;
    const c = fakeContext({ "X-App-Key": "" });
    assert.equal(requireAppKey(c), false);
  } finally {
    if (prior === undefined) {
      delete process.env.APP_KEY;
    } else {
      process.env.APP_KEY = prior;
    }
  }
});

test("requireAppKey matches only the configured key", () => {
  const prior = process.env.APP_KEY;
  try {
    process.env.APP_KEY = "expected-key";
    assert.equal(requireAppKey(fakeContext({ "X-App-Key": "expected-key" })), true);
    assert.equal(requireAppKey(fakeContext({ "X-App-Key": "wrong-key" })), false);
    assert.equal(requireAppKey(fakeContext({})), false);
  } finally {
    if (prior === undefined) {
      delete process.env.APP_KEY;
    } else {
      process.env.APP_KEY = prior;
    }
  }
});

test("bearerToken parses a well-formed header and rejects everything else", () => {
  assert.equal(bearerToken(fakeContext({ Authorization: "Bearer abc123" })), "abc123");
  assert.equal(bearerToken(fakeContext({ Authorization: "bearer abc123" })), "abc123");
  assert.equal(bearerToken(fakeContext({ Authorization: "Bearer " })), null);
  assert.equal(bearerToken(fakeContext({ Authorization: "Basic abc123" })), null);
  assert.equal(bearerToken(fakeContext({})), null);
});
