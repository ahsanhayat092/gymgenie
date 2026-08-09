# GymGenie

A full Flutter fitness app with a Firebase backend (Android & iOS).

## Setup

See **SETUP.md** for the full step-by-step guide (Firebase console setup,
FlutterFire CLI, Android SHA-1, rules deployment). Quick version:

1. Install Flutter (Dart 3, sdk ^3.4.0).
2. Run `flutter pub get`.
3. Configure Firebase: `flutterfire configure` (this regenerates
   `lib/firebase_options.dart`, which is a placeholder in the repo).
4. Deploy `firestore.rules` to your Firebase project.
5. Run the app: `flutter run`.

## Stack

- flutter_riverpod (state management)
- go_router (routing)
- firebase_core / firebase_auth / cloud_firestore / google_sign_in
- fl_chart (progress charts)
- intl (formatting)

See SPEC.md for the full architecture contract.
