import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import { createPrivateKey, sign } from "node:crypto";
import { connect } from "node:http2";

const usage =
  "Usage: node scripts/apns-send/send.mjs <device-token-hex> <on|off> [AuthKey.p8]";
const [token, command, keyPathArg] = process.argv.slice(2);

if (!token || (command !== "on" && command !== "off")) {
  console.error(usage);
  process.exit(1);
}

const keyId = process.env.APNS_KEY_ID;
const teamId = process.env.APNS_TEAM_ID;
if (!keyId || !teamId) {
  console.error("Set APNS_KEY_ID and APNS_TEAM_ID");
  process.exit(1);
}

const scriptDir = dirname(fileURLToPath(import.meta.url));
const keyPath =
  keyPathArg ?? process.env.APNS_P8_PATH ?? resolve(scriptDir, "AuthKey.p8");

const header = base64url(JSON.stringify({ alg: "ES256", kid: keyId }));
const claims = base64url(
  JSON.stringify({ iss: teamId, iat: Math.floor(Date.now() / 1000) }),
);
const signingInput = `${header}.${claims}`;
const signature = sign("SHA256", Buffer.from(signingInput), {
  key: createPrivateKey(readFileSync(keyPath)),
  dsaEncoding: "ieee-p1363",
});
const jwt = `${signingInput}.${base64url(signature)}`;

// Same window as forwarder/src/apns.ts. A UNIX time, not a duration.
const APNS_EXPIRATION_SECONDS = 60;

const body = JSON.stringify({
  aps: {
    alert: { title: "Do Not Disturb Sync" },
    "interruption-level": "time-sensitive",
    "relevance-score": 1,
  },
  command,
});

const apnsHost = process.env.APNS_HOST || "https://api.sandbox.push.apple.com";
const client = connect(apnsHost);
try {
  const { status, apnsId, responseBody } = await sendPush(client, {
    token,
    jwt,
    body,
  });
  if (status === "200") {
    console.log(`:status ${status}`);
    if (apnsId) {
      console.log(`apns-id ${apnsId}`);
    }
  } else {
    if (responseBody) {
      console.error(responseBody);
    } else {
      console.error(`:status ${status}`);
    }
    process.exitCode = 1;
  }
} finally {
  client.close();
}

function base64url(input) {
  return Buffer.from(input).toString("base64url");
}

function sendPush(client, { token, jwt, body }) {
  return new Promise((resolvePromise, reject) => {
    client.once("error", reject);
    const req = client.request({
      ":method": "POST",
      ":path": `/3/device/${token}`,
      authorization: `bearer ${jwt}`,
      "apns-topic": "com.dndsync.macos",
      "apns-push-type": "alert",
      "apns-priority": "10",
      "apns-expiration": String(
        Math.floor(Date.now() / 1000) + APNS_EXPIRATION_SECONDS,
      ),
      "content-type": "application/json",
    });

    let status = "";
    let apnsId = "";
    const chunks = [];

    req.on("response", (headers) => {
      status = String(headers[":status"] ?? "");
      apnsId = String(headers["apns-id"] ?? "");
    });
    req.on("data", (chunk) => chunks.push(chunk));
    req.on("error", reject);
    req.on("end", () => {
      resolvePromise({
        status,
        apnsId,
        responseBody: Buffer.concat(chunks).toString("utf8"),
      });
    });
    req.end(body);
  });
}
