# YOLOv8 Models Folder

This folder contains trained YOLOv8 models for waste classification.

## Model File

- `waste_yolov8.pt` - Trained YOLOv8 model for waste detection and classification

## How to Get a Model

### Option 1: Train Your Own Model

1. Prepare your dataset in YOLO format (see `YOLOV8_TRAINING_GUIDE.md`)
2. Run the training script:
   ```bash
   python train_model.py
   ```
3. The trained model will be automatically copied to this folder

### Option 2: Download Pretrained Model

If you have access to a pretrained waste classification model:

1. Download the `.pt` file
2. Place it in this folder as `waste_yolov8.pt`

### Option 3: Use Demo Mode

If you don't have a trained model yet, the backend will run in simulation mode:
- Random classifications (for testing)
- All API endpoints work normally
- Train a real model when ready

## Model Information

The model should detect and classify these waste types:

- Plastic (bottles, containers, bags)
- Metal (cans, aluminum, steel)
- Glass (bottles, jars)
- Paper (newspapers, documents)
- Organic (food waste, plant materials)
- Cardboard (boxes, packaging)
- Battery (batteries, cells)
- Electronics (devices, circuit boards)

## Testing the Model

Test the loaded model:

```python
from ml_model import get_classifier

classifier = get_classifier('models/waste_yolov8.pt')

# Get model info
info = classifier.get_model_info()
print(info)

# Test classification
result = classifier.classify_image('path/to/test_image.jpg')
print(result)
```

## Model Performance

After training, document your model's performance here:

- **mAP50**: TBD
- **mAP50-95**: TBD
- **Precision**: TBD
- **Recall**: TBD
- **Inference Speed**: TBD ms/image
- **Model Size**: TBD MB
- **Training Dataset**: TBD images

## Updating the Model

To update the model:

1. Train a new version
2. Replace `waste_yolov8.pt` with the new model
3. Restart the backend server
4. Test with sample images

## Troubleshooting

### Model not loading
- Check file path in `.env` or `waste_classifier.py`
- Verify model file exists and is not corrupted
- Check file permissions

### Low accuracy
- Retrain with more data
- Use larger model variant (yolov8m, yolov8l)
- Increase training epochs
- Improve data quality

### Slow inference
- Use smaller model (yolov8n, yolov8s)
- Enable GPU acceleration
- Export to ONNX or TensorRT format
- Reduce image size

For more help, see `YOLOV8_TRAINING_GUIDE.md`
