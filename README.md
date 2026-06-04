# SortifyX

Waste classification mobile app built as my final year project at MMU. Point your phone at a piece of trash, the app tells you what it is and which bin it goes in.

I built this because I kept staring at my own bin wondering whether the takeout container was recyclable. Turns out a lot of people have the same problem — recycling contamination rates hit 25% in some places, mostly because nobody actually knows the rules.

## What it does

You scan something with the camera, a YOLOv8 model running on the backend tells you whether it's plastic, metal, glass, paper, cardboard, organic, or trash. You get a few points for each scan, points unlock badges, and you can redeem them for real stuff like Touch n Go credit or Grab vouchers.

There's also an admin side for managing users and looking at scan stats, since the project brief required role-based access.

## Stack

- **Flutter** for the mobile app (Android, but it'd work on iOS with minor changes)
- **Flask + SQLAlchemy** for the backend
- **YOLOv8 (Ultralytics)** for the actual classification
- **SQLite** for storage — overkill to use anything heavier for a demo
- **JWT** for auth

The frontend talks to the backend over HTTP. The model lives on the backend, not the phone, so classifications need a network connection. I tried on-device inference but the model was 12MB and inference was slow, didn't seem worth it for the demo.

## Model performance

Trained on TrashNet (the standard waste-classification dataset) plus an organic waste set I pulled from Roboflow Universe. About 2,500 images, 100 epochs on Colab's free T4 GPU. Took roughly 45 minutes.

Overall mAP50 of **0.882**, but the per-class numbers tell a more honest story:

| Class | mAP50 |
|---|---|
| Metal | 0.98 |
| Paper | 0.98 |
| Glass | 0.96 |
| Cardboard | 0.96 |
| Plastic | 0.94 |
| Non-recyclable | 0.82 |
| Organic | **0.54** ← not great |

Organic is the weak link. The dataset for it was smaller and visually inconsistent (banana peels and leaves and rice all look very different), and TrashNet was studio shots which don't generalize perfectly to a phone in dim indoor lighting. Future me would add more real-world photos.

## Running it

You need Python 3.10+, Flutter 3.x, and an Android device or emulator.

**Backend:**
```bash
cd sortifyx_backend
pip install -r requirements.txt
python app.py
```

That spins up Flask on `0.0.0.0:5000`. The DB auto-initializes on first run and seeds an admin account (`admin@sortifyx.com` / `admin123` — change this if you're deploying anywhere serious).

**App:**
```bash
cd sortifyx_app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://YOUR_PC_IP:5000/api
```

The `API_BASE_URL` is the IP your phone needs to reach the backend on. If you're on an emulator, use `http://10.0.2.2:5000/api`. For a physical phone, run `ipconfig` (Windows) or `ifconfig` (Mac/Linux) on the PC running the backend, grab the LAN IP, and use that. Phone and PC need to be on the same WiFi.

If you hit "cannot reach server", it's almost certainly Windows Firewall blocking Python. Allow `python.exe` through it.

## Training your own model

There's a `SortifyX_YOLOv8_Training.ipynb` notebook for Colab. Upload it, switch the runtime to T4 GPU, run the cells in order. Drop the resulting `best.pt` into `sortifyx_backend/models/waste_yolov8.pt` and restart the backend.

If you don't have a trained model, the backend falls back to simulation mode (random classifications) so you can still demo the rest of the app.

## Things I'd change with more time

- The organic class accuracy. Needs a bigger, more consistent dataset.
- Move the model to TFLite and run on-device. No network required.
- SQLite → Postgres if this ever went into production.
- iOS build. Currently Android-only because I don't own a Mac.
- Real OAuth instead of email/password.
- A way for users to flag misclassifications. Free training data and the model gets better over time.

## Known issues

- First request after the backend starts is slow (~5s) because the model loads lazily.
- The camera preview can look stretched on tall phones running older versions of the `camera` plugin. Updating to 0.11+ fixed it for me.
- If you change WiFi networks the LAN IP changes and you need to rebuild with a new `API_BASE_URL`. Annoying.

## Project structure
sortifyx_backend/
├── app.py                  # Flask entry point
├── routes/                 # API routes (auth, scan, admin, rewards, etc.)
├── ml_model/               # YOLOv8 wrapper + simulation fallback
├── database.py             # SQLAlchemy models
├── dataset/                # Training data (after merge_datasets.py)
├── models/                 # Trained .pt files go here
└── scripts/merge_datasets.py  # Combines TrashNet + organic sources
sortifyx_app/lib/
├── main.dart               # Routes, theme
├── config/app_config.dart  # API URL config (no hardcoded values)
├── services/api_service.dart  # HTTP wrapper
├── screens/                # All the UI screens
├── widgets/                # Shared widgets (bottom nav, etc.)
└── utils/helpers.dart      # Date/number/icon helpers

## Credits

- TrashNet dataset — Gary Thung & Mindy Yang, Stanford CS229
- Organic waste subset from Roboflow Universe
- YOLOv8 by Ultralytics
- Flutter, Flask — the usual suspects

Built by Kuan Ing Shien, MMU FYP 2025/26. Supervisor: Dr. Chong Siew Chin.