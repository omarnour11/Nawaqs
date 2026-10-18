# Android release signing & Google Play checklist

This document describes how to produce a **signed release App Bundle (`.aab`)**
for Google Play. It contains no secrets — the keystore and its passwords live
outside Git.

## 1. What the build requires

The Android module reads `android/key.properties` (git-ignored):

```properties
storeFile=/absolute/path/to/upload-keystore.jks
storePassword=…
keyAlias=upload
keyPassword=…
```

* If the file is **present and the keystore exists** → a real release build
  (`signingConfig = release`).
* If the file is **missing** → `assembleRelease` / `bundleRelease` **fail** with
  a clear message. Debug and profile builds are unaffected.
* `NAWAQS_ALLOW_DEBUG_SIGNING=true` builds a debug-signed release **for local
  experiments only**. Never upload such an artifact.

`android/key.properties.example` documents the exact keys with placeholder
values.

## 2. Create a dedicated upload keystore (one time)

```bash
keytool -genkeypair -v \
  -keystore ~/keys/nawaqs-upload.jks \
  -alias upload \
  -keyalg RSA -keysize 4096 -validity 10000
```

Notes:
* Keep the `.jks` **outside the repository** (e.g. `~/keys/`).
* Back it up in a password manager or encrypted storage. Losing the upload key
  is recoverable through Play Console support, but it is slow; losing a
  **signing** key (see §3) is not.
* Never email, commit, or paste the keystore or its passwords.

Then create `android/key.properties` (already git-ignored) with the absolute
path and passphrases.

## 3. Prefer Google Play App Signing

Enrol in **Play App Signing** when creating the app in Play Console:

* Google holds the **app signing key** and signs the APKs delivered to users.
* You keep the **upload key** generated in §2 and use it to sign the `.aab`
  you upload.
* If the upload key is lost, you can request a reset in Play Console without
  losing installs or the ability to update.

This is the default for new apps and is strongly recommended.

## 4. Build the bundle

```bash
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

Without `API_BASE_URL`, the app falls back to the emulator address
(`10.0.2.2:5001`), which is unreachable on a physical device. A release build
**must** pass this define.

Artifact: `build/app/outputs/bundle/release/app-release.aab`

## 5. Verify before uploading

```bash
# Certificate + signature
apksigner verify --print-certs build/app/outputs/bundle/release/app-release.aab

# Package id / version / SDK levels are visible in the bundle's manifest;
# bundletool's `dump manifest` is the most reliable check:
bundletool dump manifest \
  --bundle=build/app/outputs/bundle/release/app-release.aab
```

Expected values:
* `package` = `com.nawakes.nawakes_mobile`
* `versionCode` from `pubspec.yaml` (`version: x.y.z+N` → N)
* `targetSdkVersion` = 36
* no `android:debuggable`, no `usesCleartextTraffic="true"`

## 6. Play Console steps (manual, requires your account)

1. Create the app; enrol in Play App Signing.
2. Complete **Data safety** (the app collects location, account, and health
   questionnaire data).
3. Provide a **privacy policy URL**.
4. Complete **Account deletion**: in-app deletion path **and** a web link where
   users can request deletion. This is mandatory and is currently **missing**
   from the app (see remaining blockers).
5. Upload the `.aab` to an internal testing track first.
6. Fill in content rating, target audience, ads declaration, and news-app
   declarations as applicable.
7. Only promote to production after internal testing passes.

## 7. Current known blockers

| Blocker | Status |
| --- | --- |
| No `account deletion` endpoint/UI + web link | **Open** — Play policy requirement |
| No privacy policy URL wired into the app | **Open** — needed for the listing |
| `API_BASE_URL` must be supplied at build time | **Open** — no production host provided |
| Push notifications (FCM) | **Not implemented** — in-app notifications only |
| Release runtime smoke test | **Blocked** — no device/emulator available |
