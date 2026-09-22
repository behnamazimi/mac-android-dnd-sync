import { getDevice, type ApnsEnvironment, type DeviceRecord } from "./store.js";

export async function wakeMacOnJoin(
  pairId: string,
  wake: (token: string, environment?: ApnsEnvironment) => Promise<void>,
  loadMac: (id: string) => Promise<DeviceRecord | null> = (id) =>
    getDevice(id, "mac"),
): Promise<void> {
  const mac = await loadMac(pairId);
  if (!mac?.token || mac.platform !== "apns") {
    return;
  }
  await wake(mac.token, mac.apnsEnvironment);
}
