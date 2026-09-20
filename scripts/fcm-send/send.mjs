import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import { initializeApp, cert } from "firebase-admin/app";
import { getMessaging } from "firebase-admin/messaging";

const usage = "Usage: node scripts/fcm-send/send.mjs <token> <on|off> [service-account.json]";
const [token, command, credPathArg] = process.argv.slice(2);

if (!token || (command !== "on" && command !== "off")) {
  console.error(usage);
  process.exit(1);
}

const scriptDir = dirname(fileURLToPath(import.meta.url));
const credPath =
  credPathArg ??
  process.env.GOOGLE_APPLICATION_CREDENTIALS ??
  resolve(scriptDir, "firebase-service-account.json");

initializeApp({
  credential: cert(JSON.parse(readFileSync(credPath, "utf8"))),
});

const messageId = await getMessaging().send({
  token,
  android: { priority: "high" },
  data: { command },
});

console.log(messageId);
