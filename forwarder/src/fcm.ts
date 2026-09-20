import { getMessaging } from "firebase-admin/messaging";

export async function sendDataFcm(
  token: string,
  envelopeB64: string,
): Promise<void> {
  await getMessaging().send({
    token,
    android: { priority: "high" },
    data: { envelope_b64: envelopeB64 },
  });
}
