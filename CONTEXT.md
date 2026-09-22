# Domain language

Mac & Android DND Sync keeps Do Not Disturb / Focus in sync between one Mac
and one Android phone. The system DND/Focus control is the only switch.

## Modules (Mac)

- **Focus apply** — observe Mac Focus and apply a remote on/off via Shortcuts.
  Callers never name the shortcuts or the private DND notifications.
- **Pair session** — create, restore, QR, join, unpair. Owns E2E keys.
  `joined` is the seam; callers do not hold `aesKey`.
- **Sync session** — originate and apply DndState. Owns echo suppression and
  last-write-wins across LAN and the wake-and-pull CloudEnvelope. Two
  adapters: LAN and the cloud forwarder.
- **Onboarding progress** — one value that decides the wizard destination
  (welcome → automation → shortcuts → login → QR → status).
- **Product chrome** — status item and windows. Does not own sync logic.

## Modules (Android)

- **DND apply** — observe system DND and apply a remote on/off via a Zen
  rule. Callers never name the Zen rule id or `dndsync://zen`.
- **Pair session** — restore, QR/paste, join, unpair. Owns E2E keys.
  `joined` is forwarder join success, not merely key presence (Android joins
  a Mac-created pair and can hold keys while waiting for an FCM token).
  Callers do not hold `aesKey`; they use `seal` / `open`.
- **Sync session** — originate and apply DndState. Owns echo suppression and
  last-write-wins across LAN and the wake-and-pull CloudEnvelope. Two
  adapters: LAN and the cloud forwarder. FCM delivers envelopes; it does not
  touch the gate.
- **Onboarding progress** — one value that decides the wizard destination
  (welcome → connecting → focus access → notifications → status).
- **Product chrome** — Compose screens. Observes Pair session, Sync session,
  and DND apply. Does not own sync logic.

## Sync vocabulary

- **CloudEnvelope** — encrypted (or plaintext) inner payload forwarded over
  FCM/APNs. Firestore never stores an on/off bit.
- **Echo suppression** — after applying a remote state, ignore the local
  Focus notification we just caused so the pair does not ping-pong.
- **Wake-and-pull** — off-LAN path, and every Mac-originated flip. A silent
  push wakes the peer. There is no held LAN socket and no cloud relay of
  state.
- **LanAck** — one-shot receipt on the phone-to-Mac TCP connection. Version
  3, carries the `unix_ms` of the `DndState` the Mac accepted. A matching
  ACK skips the cloud post. The phone then closes the socket.
- **Diagnostics** — debug-only harness log. Product screens do not have On/Off
  test buttons. The product Nearby chip follows the last completed sync, not
  the live socket.
