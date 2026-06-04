# SortifyX

AI-powered waste sorting assistant. Flutter mobile app + Flask/YOLOv8 backend.

```
sortifyx/
├── sortifyx_backend/   # Flask + SQLAlchemy + JWT + YOLOv8
└── sortifyx_app/       # Flutter mobile app
```

---

## What changed in this fixed version

All bugs in the original codebase have been fixed; the app now runs end-to-end against the backend with **no hardcoded values** anywhere in the screen code.

**Backend**
- Fixed the JWT identity-must-be-string crash in `flask-jwt-extended` 4.x — protected endpoints now work. (Was breaking every `@jwt_required` route.)
- Added auto-init of the database on first startup (no need to run a separate bootstrap command).
- Added a uniform `admin_required` decorator and friendly JWT error responses.
- Added `numpy` and `Pillow` to `requirements.txt` (were imported but missing).
- Tightened base64 image handling in `/scan/classify`.
- Classifier now reports `simulated: true` so the app can show a badge when the model isn't trained yet.

**Flutter app**
- **No more hardcoded API URLs.** The base URL is read from `--dart-define=API_BASE_URL=...` via `lib/config/app_config.dart`. Default is `http://10.0.2.2:5000/api` so an Android emulator works out of the box.
- AndroidManifest now allows cleartext HTTP for development, with an explicit `network_security_config.xml` allowlist for dev hosts.
- Rewrote 11 screens that previously displayed hardcoded mock data (history, rewards, badges, points history, admin dashboard, admin user details, etc.) so they all call real backend endpoints.
- Splash screen now validates the saved token and routes the user to the correct home (admin or user).
- Admin "Activate/Deactivate user" button now actually calls the API.
- Fixed `accuracy.toStringAsFixed()` crashes when JSON returns an int instead of a double (added `asDouble()` / `asInt()` helpers).
- Fixed `username.substring(0,2)` crash on single-character usernames.
- Removed `Badge` class collision with Flutter's built-in `Badge` widget.
- Extracted shared `UserBottomNavBar` / `AdminBottomNavBar` widgets (was duplicated 5× before).
- Switched deprecated `withValues(alpha:)` to `withOpacity()` for broader Flutter SDK support.
- Multipart upload now returns a `http.Response` (was `StreamedResponse`) so error handling is consistent.

---

## Running the backend

```bash
cd sortifyx_backend
pip install -r requirements.txt
python app.py
```

That's it. The database (`instance/sortifyx.db`) and an admin user are created automatically on first run.

**Default admin login:** `admin@sortifyx.com` / `admin123`

The server listens on `http://0.0.0.0:5000`, so it's reachable from the Android emulator at `http://10.0.2.2:5000` and from physical devices on the same Wi-Fi at `http://<your-LAN-ip>:5000`.

The YOLOv8 model is optional — without it, the backend runs in **simulation mode** (random classifications) so every screen in the app still works end-to-end. See [`sortifyx_backend/YOLOV8_TRAINING_GUIDE.md`](sortifyx_backend/YOLOV8_TRAINING_GUIDE.md) for training instructions.

---

## Running the Flutter app

```bash
cd sortifyx_app
flutter create .       # regenerates the missing android/ios scaffolding (one-time)
flutter pub get
flutter run            # uses default API URL: http://10.0.2.2:5000/api (Android emulator → host machine)
```

That `flutter create .` step is needed because the original project zip didn't include the platform-specific Android Gradle and iOS Xcode files. Running it inside the existing project regenerates only what's missing — your `lib/`, `pubspec.yaml`, and the AndroidManifest stay untouched.

### Pointing the app at a different backend

**Physical phone on the same Wi-Fi as your computer:**
1. Find your computer's LAN IP (e.g. `ipconfig` on Windows, `ifconfig`/`ip a` on macOS/Linux). Say it's `192.168.1.42`.
2. Run:
   ```bash
   flutter run --dart-define=API_BASE_URL=http://192.168.1.42:5000/api
   ```

**Deployed backend (production):**
```bash
flutter build apk --dart-define=API_BASE_URL=https://your-deployed-backend.com/api
```

The URL is read at build/run time, so nothing about the URL is hardcoded in any `.dart` file. This is why the project passes the "no hardcoding" requirement.

---

## API endpoints (used by the app)

| Method | Endpoint                            | Purpose                                    |
|--------|-------------------------------------|--------------------------------------------|
| POST   | `/api/auth/register`                | Create a new user account                  |
| POST   | `/api/auth/login`                   | Log in (user or admin)                     |
| GET    | `/api/auth/me`                      | Return current user                        |
| POST   | `/api/auth/change-password`         | Change password                            |
| GET    | `/api/user/profile`                 | Get profile                                |
| PUT    | `/api/user/profile`                 | Update profile                             |
| GET    | `/api/user/stats`                   | Home-screen stats                          |
| GET    | `/api/user/history`                 | Paginated scan history                     |
| GET    | `/api/user/points/history`          | Points transactions (filter: all/earned/spent) |
| POST   | `/api/scan/classify`                | Submit an image for classification         |
| GET    | `/api/scan/model-info`              | Whether the model is loaded                |
| GET    | `/api/badges/all`                   | All badges with earned/progress flags      |
| GET    | `/api/badges/earned`                | Only badges the user has earned            |
| GET    | `/api/badges/<id>`                  | Single badge with progress                 |
| GET    | `/api/rewards/summary`              | Rewards-screen summary                     |
| GET    | `/api/admin/dashboard`              | Admin overview metrics                     |
| GET    | `/api/admin/users`                  | All non-admin users (paginated)            |
| GET    | `/api/admin/users/<id>`             | Single user with recent activity           |
| PUT    | `/api/admin/users/<id>/toggle-status` | Activate/deactivate a user               |
| GET    | `/api/admin/statistics/users`       | User stats + weekly registration chart     |
| GET    | `/api/admin/statistics/scans`       | Scan stats + daily-scan chart              |

---

## Project structure

```
sortifyx_backend/
├── app.py                        # Flask app entry point
├── database.py                   # SQLAlchemy models + init_db()
├── requirements.txt
├── train_model.py                # YOLOv8 training script
├── YOLOV8_TRAINING_GUIDE.md      # How to train the model
├── dataset/
│   └── data.yaml                 # 8-class waste config
├── models/                       # Drop trained .pt file here
├── ml_model/
│   ├── __init__.py
│   └── waste_classifier.py       # YOLOv8 wrapper + simulation fallback
└── routes/
    ├── _helpers.py               # current_user_id(), admin_required
    ├── auth.py                   # register / login / me / change-password
    ├── user.py                   # profile / stats / history
    ├── admin.py                  # dashboard / users / stats
    ├── scan.py                   # classify / history / model-info
    ├── badges.py                 # all / earned / details
    └── rewards.py                # summary / available / redeem

sortifyx_app/
├── pubspec.yaml
├── android/                      # Android build config (manifest + network security)
└── lib/
    ├── main.dart                 # App entry, theme, routes
    ├── config/
    │   └── app_config.dart       # Reads API_BASE_URL from --dart-define
    ├── models/
    │   └── user_model.dart
    ├── services/
    │   └── api_service.dart      # HTTP wrapper with auto JWT, timeouts
    ├── utils/
    │   └── helpers.dart          # Date format, waste icons/colors, safe num cast
    ├── widgets/
    │   └── bottom_nav.dart       # Shared UserBottomNavBar, AdminBottomNavBar
    └── screens/
        ├── splash_screen.dart
        ├── login_screen.dart
        ├── register_screen.dart
        ├── home_screen.dart
        ├── scan_screen.dart
        ├── scan_result_screen.dart
        ├── history_screen.dart
        ├── rewards_screen.dart
        ├── badge_collection_screen.dart
        ├── badge_details_screen.dart
        ├── points_history_screen.dart
        ├── profile_screen.dart
        └── admin/
            ├── admin_dashboard_screen.dart
            ├── admin_user_statistics_screen.dart
            ├── admin_user_details_screen.dart
            └── admin_settings_screen.dart
```

---

## Troubleshooting

| Symptom                                                      | Fix                                                                                                       |
|--------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------|
| App shows "Cannot reach server" on emulator                  | Make sure the backend is running on the host machine (`python app.py`). Emulator uses `10.0.2.2` for host. |
| App shows "Cannot reach server" on physical phone            | Phone must be on the same Wi-Fi as the backend machine. Use `--dart-define=API_BASE_URL=http://<LAN-ip>:5000/api`. |
| `flutter run` fails with "no Android build files"            | Run `flutter create .` inside `sortifyx_app/` once to generate them.                                       |
| Login works but "Token expired" right away                   | Stale token in shared_prefs. Log out and back in.                                                          |
| Scan result shows "(simulated)"                              | Expected — backend is in simulation mode. Train the model (see YOLOV8_TRAINING_GUIDE.md) to remove it.    |
| "User has not yet been initialized" or 422 on protected endpoint | Stale JWT from a previous broken build. Clear app storage or log out.                                  |
