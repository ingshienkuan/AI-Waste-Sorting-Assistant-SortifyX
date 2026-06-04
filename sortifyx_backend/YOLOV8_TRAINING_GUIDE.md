# YOLOv8 Training Guide for SortifyX

This guide walks through training the waste-classification model that powers the SortifyX backend. The backend ships in **simulation mode** (random classifications) until you drop a trained `.pt` file into `models/`.

---

## 0. Quick overview

```
sortifyx_backend/
├── train_model.py            # The training script
├── dataset/
│   ├── data.yaml             # Class definitions (already configured)
│   ├── train/
│   │   ├── images/           # YOU add: 200-500+ training images
│   │   └── labels/           # YOU add: matching .txt label files
│   └── val/
│       ├── images/           # YOU add: 50-100 validation images
│       └── labels/           # YOU add: matching .txt label files
└── models/
    └── waste_yolov8.pt       # OUTPUT: trained model lives here
```

The classifier in `ml_model/waste_classifier.py` auto-loads `models/waste_yolov8.pt` on backend startup. If the file is missing, simulation mode kicks in automatically.

---

## 1. Install training dependencies

These are commented out in `requirements.txt` because they're large (~2GB). Install them only on the machine you train on:

```bash
pip install ultralytics opencv-python torch torchvision
```

Optional but recommended: a GPU. CPU training works but is 10–50× slower. To check whether PyTorch sees your GPU:

```bash
python -c "import torch; print('CUDA available:', torch.cuda.is_available())"
```

---

## 2. Collect images

You need photographs of waste items in each of the 8 classes already defined in `dataset/data.yaml`:

| Class ID | Class       | What counts                                                  |
|---------:|-------------|--------------------------------------------------------------|
| 0        | plastic     | Plastic bottles, bags, containers, packaging                 |
| 1        | metal       | Aluminum cans, steel items, metal containers                 |
| 2        | glass       | Glass bottles, jars                                          |
| 3        | paper       | Paper, newspapers, magazines                                 |
| 4        | organic     | Food scraps, fruit peels, leaves                             |
| 5        | cardboard   | Cardboard boxes, packaging                                   |
| 6        | battery     | Batteries (single-use, rechargeable, AA, button cells, etc.) |
| 7        | electronics | Phones, cables, circuit boards, small devices                |

**Target volume:**
- **Minimum to demo:** ~30 images per class (~240 total). Useful for a final-year project demo but accuracy will be modest.
- **Good results:** ~150 images per class (~1200 total).
- **Production:** 500+ per class.

**Tips for good training data:**
- Vary lighting (bright, dim, sunlight, indoor).
- Vary backgrounds (table, bin, floor, hand).
- Vary angles (top-down, side, tilted).
- Include realistic conditions (slightly dirty, crumpled, partial views).
- Resize to 640×640 or larger; the trainer will downscale if needed.

**Free dataset shortcuts** (if you don't want to photograph everything yourself):
- [TrashNet](https://github.com/garythung/trashnet) — 2527 images across 6 classes (plastic, metal, glass, paper, cardboard, trash). Closest match to our classes.
- [TACO dataset](http://tacodataset.org/) — labelled images of trash in the wild.
- [Kaggle: Garbage Classification](https://www.kaggle.com/datasets/asdasdasasdas/garbage-classification) — easy to download.

If a dataset uses different class names, just relabel them to match the 8 classes in `data.yaml`, or update `data.yaml` and the `waste_types` dict in `ml_model/waste_classifier.py` to match.

---

## 3. Label your images (YOLO format)

YOLOv8 expects one `.txt` file per image, with the same filename. For an image `dataset/train/images/can_001.jpg` you need `dataset/train/labels/can_001.txt`.

**Format of each .txt file** — one line per object in the image:

```
<class_id> <x_center> <y_center> <width> <height>
```

All values are **normalized to 0–1** (i.e. relative to image dimensions). Example for a metal can (class 1) centered in the image, taking up about 30% of width and 50% of height:

```
1 0.5 0.5 0.3 0.5
```

**Labelling tools:**
- **[Roboflow](https://roboflow.com)** (recommended) — web-based, free for small projects, exports directly to YOLOv8 format. Just upload images, draw boxes, export.
- **[LabelImg](https://github.com/HumanSignal/labelImg)** — desktop, free. Set output to YOLO format.
- **[CVAT](https://www.cvat.ai/)** — web-based, more advanced.

**Split your data:** roughly 80% to `train/`, 20% to `val/`. Roboflow does this automatically.

---

## 4. Verify the dataset layout

After labelling, your folder should look like:

```
dataset/
├── data.yaml
├── train/
│   ├── images/
│   │   ├── can_001.jpg
│   │   ├── bottle_001.jpg
│   │   └── ...
│   └── labels/
│       ├── can_001.txt
│       ├── bottle_001.txt
│       └── ...
└── val/
    ├── images/
    │   └── ...
    └── labels/
        └── ...
```

Quick sanity check:

```bash
# Count of train images and labels should match
ls dataset/train/images | wc -l
ls dataset/train/labels | wc -l
```

---

## 5. Train the model

From inside the `sortifyx_backend/` directory:

```bash
python train_model.py
```

The script trains `YOLOv8n` (the nano variant — small, fast, good for mobile-targeted projects) for 100 epochs by default. You can edit these values at the top of `train_model.py`:

```python
MODEL_SIZE = 'n'    # n=nano, s=small, m=medium, l=large, x=xlarge
EPOCHS = 100        # more = better, until it stops improving
BATCH_SIZE = 16     # lower this if you run out of GPU memory (try 8 or 4)
IMAGE_SIZE = 640
```

**Training time estimates:**

| Setup               | Per epoch | 100 epochs |
|---------------------|-----------|------------|
| RTX 3060+ GPU       | 30s–1min  | ~1 hour    |
| Mid-range GPU       | 1–2 min   | ~2–3 hours |
| Apple M1/M2         | 2–4 min   | ~4–7 hours |
| CPU only            | 10–20 min | ~20+ hours |

Output during training shows running loss and accuracy (mAP) — accuracy should climb steadily.

---

## 6. Use the trained model

After training finishes, the best checkpoint is saved at:

```
runs/detect/waste_classifier/weights/best.pt
```

Copy it to where the backend expects it:

```bash
cp runs/detect/waste_classifier/weights/best.pt models/waste_yolov8.pt
```

Restart the backend — you should see:

```
[ml_model] Loaded YOLOv8 model from models/waste_yolov8.pt
```

instead of the simulation-mode message. From now on, scans return real classifications and the `simulated: true` flag in API responses goes away (the app stops showing the "(simulated)" tag on scan results).

---

## 7. Verify it works

```bash
curl http://localhost:5000/api/scan/model-info
```

You should see:

```json
{
  "loaded": true,
  "mode": "ai",
  "model_path": "models/waste_yolov8.pt",
  "model_type": "YOLOv8",
  "num_classes": 8,
  "waste_types": ["plastic","metal","glass","paper","organic","cardboard","battery","electronics"]
}
```

---

## 8. Improving accuracy

If your model isn't accurate enough:

1. **More data.** This is by far the most effective change. Double your dataset and retrain.
2. **Better-balanced data.** Make sure each class has roughly equal counts.
3. **More epochs.** Increase to 200–300 if the validation loss is still decreasing at epoch 100.
4. **Bigger model.** Switch `MODEL_SIZE` to `'s'` or `'m'`. (Larger = slower inference.)
5. **Data augmentation.** YOLOv8 enables this by default, but you can add more in `train_model.py`:
   ```python
   model.train(..., hsv_h=0.015, hsv_s=0.7, hsv_v=0.4, degrees=10, translate=0.1, scale=0.5, flipud=0.5)
   ```
6. **Resume from a checkpoint** instead of starting fresh:
   ```python
   model = YOLO('runs/detect/waste_classifier/weights/last.pt')
   model.train(data='dataset/data.yaml', epochs=50, resume=True)
   ```

---

## 9. Troubleshooting

| Symptom                                              | Likely cause / fix                                                                  |
|------------------------------------------------------|-------------------------------------------------------------------------------------|
| `CUDA out of memory`                                 | Lower `BATCH_SIZE` to 8 or 4.                                                       |
| `Dataset not found`                                  | Run training from `sortifyx_backend/` so the relative paths in `data.yaml` resolve. |
| Accuracy stuck very low (< 30%)                      | Check that label files match images and class IDs are correct.                      |
| `ModuleNotFoundError: No module named 'ultralytics'` | `pip install ultralytics opencv-python`.                                            |
| Backend still says "Simulation mode" after copying   | Make sure the path is exactly `sortifyx_backend/models/waste_yolov8.pt`.            |

---

That's the whole pipeline. The simulation mode means you can demo the full end-to-end app today and swap in the real model when training completes.
