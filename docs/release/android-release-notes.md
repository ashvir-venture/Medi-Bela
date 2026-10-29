# Android release notes (Play Store)

Not uploading to Play yet; these are the decisions and the steps for when you do.

## Exact alarms (policy check)

- The app declares `SCHEDULE_EXACT_ALARM` only (not `USE_EXACT_ALARM`).
  Google Play allows `USE_EXACT_ALARM` only for apps whose core function is an
  alarm clock or a calendar, so a medicine-reminder app risks rejection with it.
- `SCHEDULE_EXACT_ALARM` is off by default on Android 14+. The app asks the user
  on the Reminder check screen ("Alarms & reminders"), shows a warning banner on
  Home and Today's medicine while it is off, and falls back to inexact alarms
  (reminders may arrive several minutes late) until it is allowed.
- Play Console → App content → *Exact alarms* declaration (shown when the app
  targets Android 14+ with this permission). Suggested text:

  > Medi-Bela reminds patients to take prescribed medicines at the times their
  > pharmacist set. A late reminder means a late or missed dose, so the app asks
  > the user for permission to schedule exact alarms and falls back to inexact
  > alarms when it is not granted.

- Full-screen intents (`USE_FULL_SCREEN_INTENT`) are not used, so there is no
  full-screen declaration to make.

## Signing (needed before the first upload)

Play rejects app bundles signed with the debug key, on every track (internal
testing included). The release build is still debug-signed
(`android/app/build.gradle.kts`). Before the first upload:

1. Create an upload keystore once, and keep it and its passwords safe and out
   of the repository:
   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Wire `build.gradle.kts` to read it from a gitignored `key.properties`
   (a small change; ask when you are ready).
3. Enrol in Play App Signing (Google keeps the app signing key; you sign each
   upload with the upload key).
4. `flutter build appbundle` and upload to *Internal testing* first.

## Before uploading

- Device testing (the three-phone matrix in plan.md, Rounds 1, 3 and 6) has
  not been done yet.
- Version is `0.1.0+1` (`mobile/pubspec.yaml`); raise the build number (`+2`,
  `+3`, ...) for every upload.
