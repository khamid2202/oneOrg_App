# Push notifications — Firebase setup

Everything in the app is done. The in-app inbox (`GET /notifications`, the bell,
mark-as-read) works right now against `dev-api.oneorg.uz` with no setup at all.

**Push delivery does not**, and cannot be finished from this repo: it needs a
Firebase project, which means credentials and an Apple developer account. Until
the steps below are done, `PushService` reports `PushPermission.unavailable`,
no permission sheet appears, and `POST /notifications/device-token` is never
called. Nothing breaks — `flutter build apk --debug` passes today — push is
simply dark.

The backend side is already live: `POST /notifications/send` fans out to every
registered device (see `staff/notifications.md`). It is only *this* app's
devices that are missing from that list.

---

## 1. Firebase project

Create one at <https://console.firebase.google.com>, or reuse the project the
backend already sends through — **it must be the same project**, or FCM will
reject tokens registered here. Check with whoever holds the server's FCM
service-account key before creating a new one.

## 2. Android

1. In the Firebase console, add an Android app with package name
   **`com.oneorg.staff`** (from `android/app/build.gradle.kts`).
2. Download `google-services.json` and put it at
   **`android/app/google-services.json`**.
3. Nothing else. `android/app/build.gradle.kts` applies the Google Services
   plugin the moment that file exists:

   ```kotlin
   if (file("google-services.json").exists()) {
       apply(plugin = "com.google.gms.google-services")
   }
   ```

   Release builds also need the signing certificate's SHA-1/SHA-256 added to
   the Firebase Android app if you use any other Firebase product later; plain
   FCM does not require it.

## 3. iOS

1. Add an iOS app in the Firebase console with bundle id **`com.oneorg.staff`**
   (`PRODUCT_BUNDLE_IDENTIFIER` in `ios/Runner.xcodeproj`).
2. Download `GoogleService-Info.plist` and add it to
   `ios/Runner/GoogleService-Info.plist` **through Xcode** (drag into the
   `Runner` group, "Copy items if needed", target `Runner` ticked). Copying it
   with `cp` alone leaves it out of the app bundle and Firebase will not find
   it at runtime.
3. In Xcode: `Runner` target → **Signing & Capabilities** → **+ Capability** →
   **Push Notifications**. This is what wires up `ios/Runner/Runner.entitlements`
   (already written, with `aps-environment`) and refreshes the provisioning
   profile.
4. In the Apple Developer portal, create an **APNs authentication key** (`.p8`,
   Keys → + → Apple Push Notifications service). Upload it in Firebase under
   Project settings → **Cloud Messaging** → *APNs Authentication Key*, along
   with the Key ID and your Team ID.

   Without this step, iOS devices register a token and receive nothing.

5. `cd ios && pod install` after the first `flutter pub get`.

**iOS 13 and 14 are no longer supported.** `firebase_core` 4.x requires a 15.0
deployment target, so `ios/Podfile` and the Xcode project were raised from 13.0
to 15.0.

## 4. Verify

1. Run on a **physical iPhone** — the iOS Simulator cannot receive APNs pushes.
   Android emulators can, if the image has Google Play services.
2. Sign in. The permission sheet appears once, then the OS prompt.
3. Accept, and check the device landed:

   ```bash
   curl -H "Authorization: Bearer $TOKEN" https://dev-api.oneorg.uz/notifications
   ```

   Then have someone with `notifications.create` send one:

   ```bash
   curl -X POST https://dev-api.oneorg.uz/notifications/send \
     -H "Authorization: Bearer $ADMIN_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"target_type":"user","user_id":4,"title":"Test","body":"Hello","type":"announcement"}'
   ```

   The response reports `devices_targeted` / `devices_pushed`. A
   `devices_pushed: 0` with a non-zero `notifications_created` means the inbox
   row was written but FCM rejected the push — usually a missing APNs key
   (iOS) or a `google-services.json` from a different Firebase project.

---

## If nothing arrives with the app closed

Work down this list — the first two are what catch almost everyone.

1. **Is the config actually in the build?** `android/app/google-services.json`
   and `ios/Runner/GoogleService-Info.plist` must both exist, and the iOS one
   must have been added *through Xcode* so it lands in the bundle. Without
   them `Firebase.initializeApp()` throws, `PushService` reports
   `PushPermission.unavailable`, **the permission sheet never appears**, and no
   token is ever registered. This is the state a fresh clone is in.
2. **Did a token reach the server?** Sign in, then:

   ```bash
   curl -X POST https://dev-api.oneorg.uz/notifications/send      -H "Authorization: Bearer $ADMIN_TOKEN"      -H "Content-Type: application/json"      -d '{"target_type":"user","user_id":<you>,"title":"T","body":"B"}'
   ```

   `devices_targeted: 0` means no device is registered — the app never got as
   far as `POST /notifications/device-token`, so go back to step 1.
   `devices_pushed: 0` with a non-zero `devices_targeted` means FCM rejected
   it: usually a missing APNs key on iOS, or a `google-services.json` from a
   different Firebase project than the server sends through.
3. **iOS: physical device only.** The Simulator cannot receive APNs pushes, and
   an alert push needs the Push Notifications capability plus the uploaded
   `.p8` key. A token without the key registers fine and then receives nothing.
4. **Android: battery optimisation.** Aggressive OEM power management (Xiaomi,
   Huawei, Oppo, Samsung) kills background delivery for apps the user has not
   whitelisted. Check under Settings › Battery before suspecting the code.
5. **Was the app force-swiped away?** On most Android OEMs a force-stopped app
   receives nothing at all until it is next opened — that is the OS, not FCM.

## Known gaps

- **Notification icon (Android).** Foreground notifications use
  `@mipmap/launcher_icon`. Android 5+ renders notification icons as a white
  silhouette, so a full-colour launcher icon shows up as a white or grey
  square. Fix by adding a monochrome, transparent-background drawable (e.g.
  `res/drawable/ic_notification.png`) and pointing both
  `PushService._androidChannel`'s details and a
  `com.google.firebase.messaging.default_notification_icon` manifest entry at
  it.
- **Tapping a push always opens the inbox**, never the specific thing it is
  about. The payload's `data` (e.g. `{ "invoice_id": 12 }`) is parsed and kept
  on `AppNotification.data` but nothing routes on it yet.
