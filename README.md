<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset=".github/assets/dnd-sync-logo-dark.svg">
  <img alt="Focus Sync and Do Not Disturb Sync" src=".github/assets/dnd-sync-logo.svg" width="96">
</picture>

# Focus Sync and Do Not Disturb Sync

**Keep Do Not Disturb in lockstep between your Mac and Android phone**

Flip the system Focus control on either device and the other follows, with
no extra switch in the app.

</div>

## Install

Download the `.dmg` and `.apk` from the
[latest GitHub Release](https://github.com/behnamazimi/mac-android-dnd-sync/releases/latest).

<!-- prettier-ignore -->
> [!NOTE]
> Neither the App Store nor Play Store lists these apps yet. The Mac app is
> notarized. Sideload the Android app on Android 15 (allow installs from
> this source when the system asks).

## Quickstart

Pair both devices, then flip Focus. Status shows **Paired** when it worked.

### Mac

The Mac app is a menu-bar extra named **Focus Sync**, with no Dock icon.

1. Open the `.dmg`, drag **Focus Sync** onto **Applications**, and launch it.
2. Click the icon and finish the wizard: allow Shortcuts and notifications,
   add **Focus Sync On** and **Focus Sync Off**, then optionally **Open at
   login**.
3. Leave the window open on the QR code.

### Android

The phone app is named **Do Not Disturb Sync**.

1. Sideload the `.apk` and open **Do Not Disturb Sync**.
2. Scan the Mac's QR code, or paste the pairing code if the camera cannot
   read it. Joining needs the internet, even on the same Wi-Fi.
3. Enable **Do Not Disturb Sync** in the system Do Not Disturb access list,
   then allow notifications.

Flip Focus on the Mac or Do Not Disturb on the phone. The other device
follows.

## What you can do

The system Focus switch on the Mac and Do Not Disturb on the phone are the
only controls. Same Wi-Fi is fastest; off that network a silent push wakes
the other device.

- **Flip Focus on the Mac:** Do Not Disturb on the phone follows.
- **Flip Do Not Disturb on the phone:** Focus on the Mac follows.
- **Stay on the same Wi-Fi:** Bonjour finds the peer and syncs over a
  direct LAN connection, usually within seconds.
- **Leave the LAN:** a silent push wakes the other device. There is no
  cloud copy of on or off, and no live Mac socket.
- **Grant nearby devices (optional):** same-Wi-Fi discovery is faster.
  Sync still works over the internet without it.

## Requirements

You need a Mac that stays running and a phone that can grant Do Not Disturb
access.

- **macOS 14 or later:** the Mac app is a menu-bar extra.
- **Android 15:** the phone app targets API 35.
- **Shortcuts on the Mac:** the bundled On and Off shortcuts are how this
  Mac applies Focus.
- **Do Not Disturb access on the phone:** enable Do Not Disturb Sync in the
  system list.
- **A running Mac:** a fully quit Mac cannot apply Focus from the phone.
  Open at login is skippable in the wizard and the right choice if you
  sync off-LAN.

## Privacy

We store a link between your devices and a way to reach them. The cloud
only forwards an encrypted wake; it cannot read the Focus bit. We never
store whether Do Not Disturb is on or off.

## Notes

A few behaviors that surprise people after the first pair.

- **Close is not quit:** closing the Mac window hides it. LAN, pushes, and
  the pair keep running. Quit from the menu-bar right-click menu or ⌘Q.
- **Unpair is not a factory reset:** it clears the pair, not Shortcuts
  entries, login-item state, or Android's Do Not Disturb access grant.
- **Reinstall does not restore keys:** scan the QR again.
- **A failed-off ping:** this phone or another mode kept Do Not Disturb
  on. That is the only notification in normal use.
