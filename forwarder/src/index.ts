import { initializeApp } from "firebase-admin/app";
import { onRequest } from "firebase-functions/v2/https";
import { app } from "./app.js";

initializeApp();

const secrets = [
  "DEV_PAIR_SECRET_HASH",
  "APNS_KEY_ID",
  "APNS_TEAM_ID",
  "APNS_P8",
  "APNS_HOST",
  "APP_KEY",
];

const FORWARDED_HEADERS = new Set([
  "authorization",
  "content-type",
  "x-app-key",
]);

export const api = onRequest(
  {
    region: "europe-west1",
    cors: false,
    invoker: "public",
    secrets,
  },
  async (req, res) => {
    try {
      const host = req.header("host") || "localhost";
      let path = String(req.originalUrl || req.url || "/");
      if (path === "/api") {
        path = "/";
      } else if (path.startsWith("/api/")) {
        path = path.slice(4);
      }
      const url = `https://${host}${path}`;
      const headers = new Headers();
      for (const [key, value] of Object.entries(req.headers)) {
        if (!FORWARDED_HEADERS.has(key.toLowerCase())) {
          continue;
        }
        if (typeof value === "string") {
          headers.set(key, value);
        } else if (Array.isArray(value)) {
          headers.set(key, value.join(","));
        }
      }
      const method = req.method || "GET";
      const hasBody = method !== "GET" && method !== "HEAD";
      const raw = hasBody ? req.rawBody : undefined;
      const body = raw ? new Uint8Array(raw) : undefined;
      const request = new Request(url, {
        method,
        headers,
        body,
        ...(body ? { duplex: "half" as const } : {}),
      });
      const response = await app.fetch(request);
      res.status(response.status);
      response.headers.forEach((value, key) => {
        res.setHeader(key, value);
      });
      const payload = Buffer.from(await response.arrayBuffer());
      if (payload.length === 0) {
        res.end();
        return;
      }
      res.send(payload);
    } catch (error) {
      const message = error instanceof Error ? error.message : "internal error";
      console.error("forwarder adapter", message);
      res.status(500).json({ error: message });
    }
  },
);
