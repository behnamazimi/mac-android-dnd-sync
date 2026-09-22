import assert from "node:assert/strict";
import test from "node:test";
import { silentPushBody } from "./apns.js";
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
