# mambandamarket

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Push notifications

Realtime reaches an app that is open. Push is what reaches one that is closed,
and it is the only thing that can — nothing in the process is alive to hold a
socket. Both paths end at the same place: `ChatRepository`, the unread badge,
and the inbox.

The code ships whether or not Firebase is configured. Without
`android/app/google-services.json` the Gradle plugin is not applied, the build
succeeds, `Firebase.initializeApp()` finds no default app, and `PushService`
logs `push disabled` and stops there. Messages still send and still arrive
live; only closed-app delivery is missing.

### Turning it on

1. **Firebase project** — create one, then add an **Android app** with package
   name `com.mabanda.mambandamarket` (it must match `applicationId` in
   `android/app/build.gradle.kts` or the plugin fails the build).
2. **`google-services.json`** — download it from the Firebase console and put it
   at `android/app/google-services.json`. It is not a secret: it ships inside
   every APK.
3. **Server credentials** — Firebase console → Project settings → Service
   accounts → *Generate new private key*. Set the resulting JSON, verbatim, as
   `FCM_SERVICE_ACCOUNT_JSON` in the Core API environment.
4. Confirm with `GET /health`, which reports `push: true` once the server can
   see a usable service account.

### Where things live

| Piece | File |
|---|---|
| Token registration, permission prompt, tap routing | `lib/api/push_service.dart` |
| Notification channel + permission declaration | `android/app/src/main/AndroidManifest.xml` |
| Conditional Firebase Gradle wiring | `android/app/build.gradle.kts` |
| FCM v1 transport (OAuth, fan-out, dead-token pruning) | core-api `src/lib/push.ts` |
| Who gets told what | core-api `src/lib/notify.ts` |
| Token storage | `device_tokens` (migration 0005, RLS in 0006) |

### Notes

- The notification carries a conversation id and nothing else. The thread is
  fetched over the authenticated API when it is tapped, so the read rules stay
  in one place.
- A notification is suppressed for the conversation already on screen.
- Tokens FCM reports as unregistered are deleted server-side, so uninstalled
  apps do not accumulate into a wasted request on every future message.
- iOS is unwired. The Dart side is platform-neutral and the server already
  sends an `apns` block, but it needs an Apple Developer account, an APNs key
  uploaded to Firebase, and the push entitlement before it does anything.
