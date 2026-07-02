# SafeTrace 🛡️
### Hybrid Offline/Online Smartphone Recovery & Anti-Theft Security System

[![Download APK](https://img.shields.io/badge/Download-APK-blue.svg?style=for-the-badge&logo=android&logoColor=white)](https://github.com/kayastha12/safetrace/releases/latest/download/app-release.apk)
[![Flutter](https://img.shields.io/badge/Built_with-Flutter-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)](https://android.com)

**SafeTrace** is a lightweight, hybrid smartphone tracking and security application designed to help recover lost or stolen devices. It operates using secure offline cellular SMS commands and backup online Firebase streams.

---

## 📥 Direct Download
You can download and install the latest compiled version of the app directly using the link below:

### [👉 Click Here to Download SafeTrace APK (Latest) 👈](https://github.com/kayastha12/safetrace/releases/latest/download/app-release.apk)

---

## ✨ Features

- 📶 **Hybrid Tracking**: Operates completely offline via cellular SMS text networks or online via Firebase sync.
- 📍 **GPS Recovery**: Retrieve real-time coordinates and automated Google Maps location links.
- 🔒 **Secure Remote Lock**: Instantly overlay a red PIN gate pad with native back-press, app switcher/recents, and swipe-up bypass protection.
- 🔊 **Test Ring/Alarm**: Sound a high-volume looping alarm remotely even if the device is set to silent.
- 📲 **Onboarding Setup Manual**: Guided installation carousel explaining Google Messages RCS settings, battery Autostart exemptions, and permission configs.

---

## 📲 Remote SMS Commands

Send these commands from your configured **Trusted Phone Number** to execute recovery commands:

| SMS Command | Action | Description |
| :--- | :--- | :--- |
| **`WHERE MY PHONE`** | Get Location & Battery | Replies with Google Maps URL and current battery %. |
| **`RING MY PHONE`** | Sound Alarm | Loops the alarm ringtone at maximum volume. |
| **`LOCK MY PHONE`** | Lock Device | Overlays the security PIN pad and blocks app bypasses. |

*(Commands are space and casing insensitive. E.g., `where my phone`, `WHERE_MY_PHONE`, or `wheremyphone` will all trigger correctly).*

---

## ⚙️ Required Setup

For the application to function reliably in the background:
1. **Grant Permissions**: Approve Location (Allow all the time), SMS, Phone State, and Notifications.
2. **Display over other apps**: Enable the overlay permission in Android system settings (so the app can show the lock screen instantly).
3. **Turn OFF RCS Chat on sending phone**: Android apps cannot intercept RCS data chats. Make sure you send commands as standard carrier SMS.
4. **Enable Autostart**: Allow background launch and disable battery optimizations in app info settings so the OS does not freeze the app.
