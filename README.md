<div align="center">

# DND Sync

**Keep Do Not Disturb in lockstep between your Mac and Android phone**

Flip the system Focus control on either device and the other follows, with no extra switch in the app.

</div>

## Install

Download the `.dmg` and `.apk` from the [latest GitHub Release](https://github.com/behnamazimi/mac-android-dnd-sync/releases/latest).

Neither the App Store nor Play Store lists DND Sync yet. The Mac app is notarized; sideload the Android app on Android 15.

## Quickstart

Pair both devices, then flip Focus. Status shows **Paired** when it worked.

### Mac

1. Open the `.dmg`, put **DND Sync** in Applications, and launch it. It lives in the menu bar, with no Dock icon.
2. Click the icon and finish the wizard: allow Shortcuts, add **DND Sync On** and **DND Sync Off**, then optionally **Open at login**.
3. Leave the window open on the QR code.

### Android

1. Sideload the `.apk` and open **DND Sync**.
2. Scan the Mac's QR code, or paste the pairing code if the camera cannot read it. Joining needs the internet, even on the same Wi-Fi.
3. Enable **DND Sync** in the system Do Not Disturb access list, then allow notifications.

Flip Focus on the Mac or Do Not Disturb on the phone. The other device follows.

## What you can do

- **Flip Focus on the Mac:** Do Not Disturb on the phone follows.
- **Flip Do Not Disturb on the phone:** Focus on the Mac follows.
- **Stay on the same Wi-Fi:** Bonjour finds the peer and syncs over a direct LAN connection, usually within seconds.
- **Leave the LAN:** a silent push wakes the other device. There is no cloud copy of on or off, and no live Mac socket.
- **Grant nearby devices (optional):** same-Wi-Fi discovery is faster. Sync still works over the internet without it.

## Requirements

- **macOS 14 or later:** the Mac app is a menu-bar extra.
- **Android 15:** the phone app targets API 35.
- **Shortcuts on the Mac:** the bundled On and Off shortcuts are how this Mac applies Focus.
- **Do Not Disturb access on the phone:** enable DND Sync in the system list.
- **A running Mac:** a fully quit Mac cannot apply Focus from the phone. Open at login is skippable in the wizard and the right choice if you sync off-LAN.

## Privacy

We store a link between your devices and a way to reach them. We never store whether Do Not Disturb is on or off.

## Notes

- **Close is not quit:** closing the Mac window hides it. LAN, pushes, and the pair keep running. Quit from the menu-bar right-click menu or ⌘Q.
- **Unpair is not a factory reset:** it clears the pair, not Shortcuts entries, login-item state, or Android's Do Not Disturb access grant.
- **Reinstall does not restore keys:** scan the QR again.
- **A failed-off ping:** this phone or another mode kept Do Not Disturb on. That is the only notification in normal use.

## License

No license file is published. The Android app bundles Inter under the SIL Open Font License 1.1.
