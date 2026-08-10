# gymZish — Web Admin Portal & Firestore Integration Guidelines

This document outlines the architecture, database schema, security rules, and functional specifications to guide the web team in developing the **gymZish** Web Admin Portal.

---

## 1. Overview & Sync Architecture

**gymZish** is a mobile fitness application that manages workout splits and logs. The mobile client pulls its central catalog of exercises and categories from **Cloud Firestore** and caches them locally for offline operation. 

The web team's objective is to build a secure, responsive admin portal where admins can:
1. **Manage the Exercise Catalog**: Create, read, update, and delete (CRUD) exercises.
2. **Add Categories / Muscle Groups**: Classify workouts to align with the mobile app's AI Generator.
3. **Upload Media**: Upload demonstration animated GIFs or videos to Firebase Storage and bind them to exercises.

All changes made in the Web Admin Portal sync in real time to the mobile apps via Firestore.

```
┌────────────────────────┐
│   Web Admin Portal     │
└───────────┬────────────┘
            │ Writes (CRUD)
            ▼
┌────────────────────────┐            Reads (Real-time / Cached)            ┌────────────────────────┐
│    Cloud Firestore     │ ───────────────────────────────────────────────> │  gymZish Flutter App   │
└────────────────────────┘                                                  └────────────────────────┘
```

---

## 2. Firestore Database Schemas

### A. Collection: `exercises`
Each document in this collection represents a single exercise library item. 
* **Document ID**: Unique slug identifier (e.g., `barbell-bench-press`, `dumbbell-shoulder-press`).
* **Fields**:

| Field | Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `id` | `string` | Unique slug matching the Document ID. | `"barbell-bench-press"` |
| `name` | `string` | User-facing display name. | `"Barbell Bench Press"` |
| `muscleGroup` | `string` | The target category. Must match one of the defined muscle groups. | `"Chest"` |
| `equipment` | `string` | Required equipment. | `"Barbell"` |
| `difficulty` | `string` | Experience level modifier. | `"Intermediate"` |
| `instructions` | `string` | Paragraph or list of step-by-step training instructions. | `"Lie flat on a bench, grip the barbell, lower it to your chest, and press up."` |
| `gifUrl` | `string` | HTTPS link to the animated demonstration GIF/video asset. | `"https://firebasestorage.googleapis.com/.../bench_press.gif"` |

> [!NOTE]
> **Muscle Group Enumeration**: Currently restricted to `Chest`, `Back`, `Shoulders`, `Legs`, `Arms`, `Core`, and `Cardio`.
> **Equipment Enumeration**: Restricted to `Barbell`, `Dumbbell`, `Machine`, `Cable`, `Bodyweight`, `Kettlebell`, or `Other`.
> **Difficulty Enumeration**: Restricted to `Beginner`, `Intermediate`, or `Advanced`.

---

## 3. Firebase Security Rules & Admin Authentication

Access to read/write exercises is restricted to authenticated users with the `isAdmin` flag enabled on their user document.

### A. User Profile Node (`/users/{uid}`)
An administrator user must have `isAdmin: true` set inside their profile document in the `users` collection:

```json
{
  "uid": "ADMIN_USER_ID",
  "displayName": "Admin User",
  "email": "admin@gymzish.com",
  "isAdmin": true
}
```

### B. Firestore Rules Configuration
The security rules have been deployed as follows:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper: checks if user has admin privileges
    function isAdmin() {
      return request.auth != null && 
        exists(/databases/$(database)/documents/users/$(request.auth.uid)) &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
    }

    // Global Exercise library: read-only for users, read/write for administrators
    match /exercises/{exerciseId} {
      allow read: if request.auth != null;
      allow write: if isAdmin();
    }
  }
}
```

---

## 4. Web Portal Feature Requirements

### A. Authentication & Gating
* **Gated Access**: Build a login panel using Firebase Authentication (Email/Password or Google Sign-In).
* **Authorization Verification**: Immediately upon logging in, perform a lookup check against the user's Firestore document (`/users/{uid}`) to verify `isAdmin === true`. If the flag is absent or false, block dashboard access, display a permission error, and sign out the user.

### B. Exercise Management Dashboard (CRUD)
* **Datatable View**: Displays all exercises retrieved from Firestore with search capability, sorting by name, and filters for `muscleGroup` and `equipment`.
* **Creation Form**: Form to add a new exercise.
  * *Slug Generator*: Automatically generates the slug `id` (Document ID) from the entered `name` (e.g., `"Incline Dumbbell Fly"` becomes `"incline-dumbbell-fly"`).
  * *Validations*: Fields like name, instruction description, muscle group, and equipment selection must be required.
* **Editing Form**: Ability to edit existing fields. Do not allow editing of the Document ID/slug once created to prevent breaking references in users' custom plans.

### C. Media upload Flow
* **File Uploader**: Drag-and-drop animated GIF/video uploader.
* **Firebase Storage Structure**:
  * Upload exercise media to the bucket directory path: `/exercises/demonstrations/{exercise-id}.gif` (or `.mp4`).
  * Capture the retrieved public download URL and assign it directly to the exercise's `gifUrl` field.

---

## 5. Technology Stack Recommendation

The mobile client is built on Flutter. For the Web Admin Portal, we recommend:
* **Framework**: React.js with Next.js or Vite.
* **UI styling**: TailwindCSS with component libraries (e.g., shadcn/ui or MUI) for a clean dashboard experience.
* **SDK**: Official Firebase Web SDK (`firebase/auth`, `firebase/firestore`, `firebase/storage`).
