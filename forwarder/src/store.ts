import { getFirestore, FieldValue, type Timestamp } from "firebase-admin/firestore";

export type Sender = "mac" | "android";
export type Platform = "apns" | "fcm";
export type ApnsEnvironment = "sandbox" | "production";

export type DeviceRecord = {
  platform: Platform;
  token: string;
  e2ePublicKey?: string;
  apnsEnvironment?: ApnsEnvironment;
  updatedAt?: Timestamp;
};

// Push route mirrored onto the pair doc so an envelope needs one read
// (the auth read) instead of a second read of the peer's device doc.
export type PushRoute = Pick<DeviceRecord, "platform" | "token" | "apnsEnvironment">;

export type PairRecord = {
  secretHash: string;
  devices?: Partial<Record<Sender, PushRoute>>;
  createdAt?: Timestamp;
  updatedAt?: Timestamp;
};

// The peer's push route from the pair doc, or undefined for a pair written
// before routes were mirrored there (callers then read the device doc).
export function peerFromPair(pair: PairRecord, sender: Sender): PushRoute | undefined {
  const route = pair.devices?.[sender];
  if (!route?.token || !route.platform) {
    return undefined;
  }
  return route;
}

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
  // Only a re-used id (DEBUG fixed id, Mac re-posting its QR) has old
  // devices to clear; a fresh random id skips the collection read + batch.
  if ((await pairRef(pairId).get()).exists) {
    await deletePair(pairId);
  }
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
  const route: Record<string, unknown> = {
    platform: record.platform,
    token: record.token,
  };
  if (record.apnsEnvironment !== undefined) {
    payload.apnsEnvironment = record.apnsEnvironment;
    route.apnsEnvironment = record.apnsEnvironment;
  }
  const batch = db().batch();
  batch.set(deviceRef(pairId, sender), payload, { merge: true });
  batch.set(pairRef(pairId), { devices: { [sender]: route } }, { merge: true });
  await batch.commit();
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
