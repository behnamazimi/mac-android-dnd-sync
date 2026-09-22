import { getFirestore, FieldValue, type Timestamp } from "firebase-admin/firestore";

export type Sender = "mac" | "android";
export type Platform = "apns" | "fcm";
export type ApnsEnvironment = "sandbox" | "production";

export type PairRecord = {
  secretHash: string;
  createdAt?: Timestamp;
  updatedAt?: Timestamp;
};

export type DeviceRecord = {
  platform: Platform;
  token: string;
  e2ePublicKey?: string;
  apnsEnvironment?: ApnsEnvironment;
  updatedAt?: Timestamp;
};

function db() {
  return getFirestore();
}

function pairRef(pairId: string) {
  return db().collection("pairs").doc(pairId);
}

function deviceRef(pairId: string, sender: Sender) {
  return pairRef(pairId).collection("devices").doc(sender);
}

export async function getPair(pairId: string): Promise<PairRecord | null> {
  const snap = await pairRef(pairId).get();
  if (!snap.exists) {
    return null;
  }
  const data = snap.data() as PairRecord;
  if (!data.secretHash) {
    return null;
  }
  return data;
}

export async function createPair(
  pairId: string,
  secretHash: string,
): Promise<void> {
  await deletePair(pairId);
  await pairRef(pairId).set({
    secretHash,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
}

export async function upsertDevice(
  pairId: string,
  sender: Sender,
  record: {
    platform: Platform;
    token: string;
    e2ePublicKey?: string;
    apnsEnvironment?: ApnsEnvironment;
  },
): Promise<void> {
  const payload: Record<string, unknown> = {
    platform: record.platform,
    token: record.token,
    updatedAt: FieldValue.serverTimestamp(),
  };
  if (record.e2ePublicKey !== undefined) {
    payload.e2ePublicKey = record.e2ePublicKey;
  }
  if (record.apnsEnvironment !== undefined) {
    payload.apnsEnvironment = record.apnsEnvironment;
  }
  await deviceRef(pairId, sender).set(payload, { merge: true });
}

export async function getDevice(
  pairId: string,
  sender: Sender,
): Promise<DeviceRecord | null> {
  const snap = await deviceRef(pairId, sender).get();
  if (!snap.exists) {
    return null;
  }
  return snap.data() as DeviceRecord;
}

export async function listDevicePublicKeys(
  pairId: string,
): Promise<Array<{ sender: Sender; e2ePublicKey?: string }>> {
  const snap = await pairRef(pairId).collection("devices").get();
  return snap.docs.map((doc) => {
    const data = doc.data() as DeviceRecord;
    return {
      sender: doc.id as Sender,
      e2ePublicKey: data.e2ePublicKey,
    };
  });
}

export async function deletePair(pairId: string): Promise<void> {
  const devices = await pairRef(pairId).collection("devices").get();
  const batch = db().batch();
  for (const doc of devices.docs) {
    batch.delete(doc.ref);
  }
  batch.delete(pairRef(pairId));
  await batch.commit();
}
