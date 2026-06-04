"""
YOLOv8 Waste Classification Training Script
This script trains a YOLOv8 model for waste classification
"""

from ultralytics import YOLO
import os

def train_yolov8_waste_classifier():
    """
    Train YOLOv8 model for waste classification
    """
    
    # Configuration
    MODEL_SIZE = 'n'  # Options: n (nano), s (small), m (medium), l (large), x (extra large)
    DATA_YAML = 'dataset/data.yaml'  # Path to your data.yaml file
    EPOCHS = 100
    BATCH_SIZE = 16
    IMAGE_SIZE = 640
    PROJECT_NAME = 'waste_classifier'
    
    print("=" * 60)
    print("YOLOv8 Waste Classification Training")
    print("=" * 60)
    print(f"Model: YOLOv8{MODEL_SIZE}")
    print(f"Dataset: {DATA_YAML}")
    print(f"Epochs: {EPOCHS}")
    print(f"Batch Size: {BATCH_SIZE}")
    print(f"Image Size: {IMAGE_SIZE}x{IMAGE_SIZE}")
    print("=" * 60)
    
    # Check if dataset exists
    if not os.path.exists(DATA_YAML):
        print(f"\n❌ Error: Dataset file not found at {DATA_YAML}")
        print("\nPlease prepare your dataset in YOLO format:")
        print("1. Create dataset/train/images and dataset/train/labels folders")
        print("2. Create dataset/val/images and dataset/val/labels folders")
        print("3. Create dataset/data.yaml with class information")
        print("\nSee YOLOV8_TRAINING_GUIDE.md for detailed instructions")
        return
    
    # Load pretrained model
    print(f"\nLoading YOLOv8{MODEL_SIZE} pretrained model...")
    model = YOLO(f'yolov8{MODEL_SIZE}.pt')
    
    # Train the model
    # Auto-detect device (GPU if available, else CPU)
    try:
        import torch
        if torch.cuda.is_available():
            device = 0
            workers = 8
            print(f"Using GPU: {torch.cuda.get_device_name(0)}")
        else:
            device = 'cpu'
            workers = 2
            BATCH_SIZE = 8
            print("Using CPU (no GPU available)")
            print("WARNING: Training on CPU will be much slower (10+ hours).")
    except ImportError:
        device = 'cpu'
        workers = 2

    # Train the model
    print("\nStarting training...\n")
    results = model.train(
        data=DATA_YAML,
        epochs=EPOCHS,
        imgsz=IMAGE_SIZE,
        batch=BATCH_SIZE,
        name=PROJECT_NAME,
        hsv_h=0.015,
        hsv_s=0.7,
        hsv_v=0.4,
        degrees=10,
        translate=0.1,
        scale=0.5,
        flipud=0.0,
        fliplr=0.5,
        mosaic=1.0,
        patience=50,
        save=True,
        save_period=10,
        val=True,
        plots=True,
        device=device,
        workers=workers,
    )
    
    print("\n" + "=" * 60)
    print("Training Complete!")
    print("=" * 60)
    
    # Get best model path
    best_model_path = f'runs/detect/{PROJECT_NAME}/weights/best.pt'
    
    print(f"\nBest model saved to: {best_model_path}")
    
    # Validate the model
    print("\nValidating model...")
    metrics = model.val()
    
    print("\n" + "=" * 60)
    print("Validation Results:")
    print("=" * 60)
    print(f"mAP50: {metrics.box.map50:.4f}")
    print(f"mAP50-95: {metrics.box.map:.4f}")
    print(f"Precision: {metrics.box.mp:.4f}")
    print(f"Recall: {metrics.box.mr:.4f}")
    
    # Copy model to models folder
    print("\n" + "=" * 60)
    print("Copying model to backend...")
    print("=" * 60)
    
    import shutil
    os.makedirs('models', exist_ok=True)
    destination = 'models/waste_yolov8.pt'
    shutil.copy(best_model_path, destination)
    
    print(f"✓ Model copied to: {destination}")
    print("\nYou can now use this model with the SortifyX backend!")
    print("Start the backend server with: python app.py")
    
    return results


def test_model(model_path='models/waste_yolov8.pt', test_images='test_images/'):
    """
    Test the trained model on sample images
    """
    
    print("=" * 60)
    print("Testing YOLOv8 Model")
    print("=" * 60)
    
    if not os.path.exists(model_path):
        print(f"\n❌ Error: Model not found at {model_path}")
        print("Please train the model first using train_yolov8_waste_classifier()")
        return
    
    if not os.path.exists(test_images):
        print(f"\n❌ Error: Test images folder not found at {test_images}")
        print("Please create a test_images folder with sample images")
        return
    
    # Load model
    print(f"\nLoading model from {model_path}...")
    model = YOLO(model_path)
    
    # Run predictions
    print(f"\nRunning predictions on images in {test_images}...")
    results = model.predict(
        source=test_images,
        conf=0.25,
        save=True,
        save_txt=True,
        save_conf=True
    )
    
    print("\n" + "=" * 60)
    print("Predictions Complete!")
    print("=" * 60)
    print(f"\nResults saved to: runs/detect/predict/")
    
    # Show results summary
    print("\nDetection Summary:")
    print("-" * 60)
    
    for i, result in enumerate(results):
        print(f"\nImage {i+1}:")
        if len(result.boxes) > 0:
            for box in result.boxes:
                cls = int(box.cls[0])
                conf = float(box.conf[0])
                print(f"  - Class {cls}, Confidence: {conf:.2%}")
        else:
            print("  - No detections")


if __name__ == "__main__":
    import sys
    
    print("\nYOLOv8 Waste Classification")
    print("=" * 60)
    print("1. Train new model")
    print("2. Test existing model")
    print("=" * 60)
    
    choice = input("\nEnter your choice (1 or 2): ").strip()
    
    if choice == "1":
        print("\nStarting training...")
        train_yolov8_waste_classifier()
    elif choice == "2":
        print("\nStarting testing...")
        test_model()
    else:
        print("\n❌ Invalid choice. Please run again and select 1 or 2.")
