import assert from "node:assert/strict";
import test from "node:test";
import { apnsHosts, hostsForPush, isWrongApnsEnvironment, silentPushBody } from "./apns.js";
import { wakeMacOnJoin } from "./join_wake.js";

test("joined push has no envelope and no on/off bit", () => {
  const body = JSON.parse(silentPushBody({ joined: true })) as {
    aps: { "content-available": number };
    joined?: boolean;
    envelope_b64?: string;
    command?: string;
  };
  assert.equal(body.aps["content-available"], 1);
  assert.equal(body.joined, true);
  assert.equal(body.envelope_b64, undefined);
  assert.equal(body.command, undefined);
});

test("wake calls the Mac APNs token", async () => {
  const tokens: string[] = [];
  await wakeMacOnJoin(
    "dndsync-test",
    async (token) => {
      tokens.push(token);
    },
    async () => ({ platform: "apns", token: "abc" }),
  );
  assert.deepEqual(tokens, ["abc"]);
});

test("wake skips a missing or non-APNs Mac", async () => {
  let calls = 0;
  const wake = async () => {
    calls += 1;
  };
  await wakeMacOnJoin("dndsync-test", wake, async () => null);
  await wakeMacOnJoin(
    "dndsync-test",
    wake,
    async () => ({ platform: "fcm", token: "phone" }),
  );
  assert.equal(calls, 0);
});

test("wake failure propagates so the route can still return 204", async () => {
  await assert.rejects(
    wakeMacOnJoin(
      "dndsync-test",
      async () => {
        throw new Error("apns down");
      },
      async () => ({ platform: "apns", token: "abc" }),
    ),
    /apns down/,
  );
});

test("APNs host order follows APNS_HOST and always includes the other environment", () => {
  const previous = process.env.APNS_HOST;
  process.env.APNS_HOST = "https://api.push.apple.com";
  assert.deepEqual(apnsHosts(), [
    "https://api.push.apple.com",
    "https://api.sandbox.push.apple.com",
  ]);
  process.env.APNS_HOST = "https://api.sandbox.push.apple.com";
  assert.deepEqual(apnsHosts(), [
    "https://api.sandbox.push.apple.com",
    "https://api.push.apple.com",
  ]);
  if (previous === undefined) {
    delete process.env.APNS_HOST;
  } else {
    process.env.APNS_HOST = previous;
  }
});

test("a stored APNs environment picks one host", () => {
  assert.deepEqual(hostsForPush("sandbox"), ["https://api.sandbox.push.apple.com"]);
  assert.deepEqual(hostsForPush("production"), ["https://api.push.apple.com"]);
  assert.equal(hostsForPush(undefined).length, 2);
});

test("wake forwards the environment stored with the Mac token", async () => {
  const seen: Array<string | undefined> = [];
  await wakeMacOnJoin(
    "dndsync-test",
    async (_token, environment) => {
      seen.push(environment);
    },
    async () => ({ platform: "apns", token: "abc", apnsEnvironment: "sandbox" }),
  );
  assert.deepEqual(seen, ["sandbox"]);
});

test("only a wrong-environment 400 is retried on the other host", () => {
  assert.equal(
    isWrongApnsEnvironment("400", '{"reason":"BadDeviceToken"}'),
    true,
  );
  assert.equal(
    isWrongApnsEnvironment("400", '{"reason":"BadEnvironmentKeyInToken"}'),
    true,
  );
  assert.equal(isWrongApnsEnvironment("400", '{"reason":"BadTopic"}'), false);
  assert.equal(isWrongApnsEnvironment("410", '{"reason":"Unregistered"}'), false);
});
