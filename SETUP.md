# GymGenie — Setup Guide

This connects the generated source code to YOUR Firebase project (`gymgenie-a5380`).

## Prerequisites
- Flutter SDK 3.22+ (`flutter doctor` all green for Android/iOS)
- Dart SDK comes with Flutter
- A Google account with access to the `gymgenie-a5380` Firebase project

## 1. Enable Firebase services (console.firebase.google.com → project GymGenie)
1. **Authentication** → Get started → Sign-in method:
   - Enable **Email/Password**
   - Enable **Google** (set a support email when prompted)
2. **Firestore Database** → Create database → choose a region → **Start in production mode**
3. (Rules are deployed in step 4 below.)

## 2. Generate Firebase config files
At the root of this project:
```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=gymgenie-a5380
```
- Select **android** and **ios** (space to toggle, enter to confirm).
- This **overwrites `lib/firebase_options.dart`** (the placeholder in this repo),
  creates `android/app/google-services.json`, and registers the iOS app.

## 3. Android config
1. `android/app/build.gradle` (or `build.gradle.kts`):
   - `minSdkVersion 23` (required by firebase_auth / google_sign_in)
2. Add the Google services plugin if FlutterFire didn't already:
   - `android/settings.gradle`: `id "com.google.gms.google-services" version "4.4.2" apply false` in plugins
   - `android/app/build.gradle`: `apply plugin: "com.google.gms.google-services"`
   (Newer FlutterFire CLI versions do this automatically — check before adding.)
3. **Google sign-in on Android needs your SHA-1**:
   ```bash
   cd android && ./gradlew signingReport
   ```
   Copy the debug SHA-1 → Firebase console → Project settings → Your apps →
   Android app → Add fingerprint. Re-download `google-services.json` afterwards.

## 4. Deploy Firestore security rules
```bash
npm install -g firebase-tools    # once
firebase login
firebase use gymgenie-a5380
firebase deploy --only firestore:rules
```
(Or paste `firestore.rules` content into console → Firestore → Rules → Publish.)

## 5. Run
```bash
flutter pub get
flutter run            # choose Android device/emulator or iOS simulator
```

## First use
1. Sign up with email or Google — a profile doc is auto-created in Firestore.
2. Set your weekly workout goal (Profile → Goals).
3. Create a plan (Plans tab → +) or start an empty workout from Home.
4. Log sets during the workout, Finish → see summary + history + progress charts.

## Data model (all under your Firestore project)
- `users/{uid}` — profile & goals
- `users/{uid}/plans/*` — workout plans
- `users/{uid}/logs/*` — completed workout logs
- `users/{uid}/bodyWeights/*` — body-weight entries

## Troubleshooting
- **"DefaultFirebaseOptions have not been configured"** → run step 2.
- **Google sign-in fails on Android (ApiException 10)** → missing SHA-1 (step 3.3).
- **Permission denied in Firestore** → deploy the rules (step 4) and confirm the
  user is signed in.
- **iOS pods error** → `cd ios && pod repo update && pod install`, ensure iOS
  deployment target ≥ 13.0 in `ios/Podfile`.
