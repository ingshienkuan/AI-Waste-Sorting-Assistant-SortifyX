"""
YOLOv8 Waste Classification Model.

Detects and classifies waste items in an image. Gracefully falls back
to a simulation mode if YOLOv8 (ultralytics) or the trained model file
is not available, so the rest of the backend remains usable for
development.
"""
import os
import random
from typing import Dict, List

import numpy as np

# Optional heavyweight deps — backend stays usable without them
try:
    from ultralytics import YOLO
    import cv2  # noqa: F401  (used indirectly via ultralytics)
    YOLOV8_AVAILABLE = True
except ImportError:
    YOLOV8_AVAILABLE = False
    print('[ml_model] YOLOv8 not installed; running in simulation mode.')
    print('           Install with: pip install ultralytics opencv-python')


class WasteClassifier:
    """Wrapper around YOLOv8 with a simulation fallback."""

    def __init__(self, model_path: str = 'models/waste_yolov8.pt'):
        self.model_path = model_path
        self.model = None

        # Class id -> waste type label. Must match data.yaml exactly.
        self.waste_types = {
            0: 'plastic',
            1: 'metal',
            2: 'glass',
            3: 'paper',
            4: 'cardboard',
            5: 'organic',
            6: 'non_recyclable',
        }

        # Reward points per waste type
        self.points_map = {
            'plastic': 10,
            'metal': 15,
            'glass': 15,
            'paper': 10,
            'cardboard': 10,
            'organic': 5,
            'non_recyclable': 3,
        }

        if YOLOV8_AVAILABLE and os.path.exists(model_path):
            self._load_model()
        elif not YOLOV8_AVAILABLE:
            print('[ml_model] Simulation mode (ultralytics not installed).')
        else:
            print(f'[ml_model] Simulation mode (no model at {model_path}).')

    # ------------------- model loading -------------------

    def _load_model(self):
        try:
            self.model = YOLO(self.model_path)
            print(f'[ml_model] Loaded YOLOv8 model from {self.model_path}')
        except Exception as e:
            print(f'[ml_model] Failed to load model: {e}')
            self.model = None

    # ------------------- inference -------------------

    def classify_image(
        self,
        image_path: str,
        conf_threshold: float = 0.25,
    ) -> Dict:
        """Classify the dominant waste item in `image_path`."""
        if self.model is None or not YOLOV8_AVAILABLE:
            return self._simulate_classification()

        try:
            results = self.model.predict(
                source=image_path,
                conf=conf_threshold,
                save=False,
                verbose=False,
            )
            if not results or len(results[0].boxes) == 0:
                return {
                    'waste_type': 'unknown',
                    'confidence': 0.0,
                    'points': 0,
                    'bbox': None,
                    'error': 'No waste detected in image',
                }

            boxes = results[0].boxes
            confidences = boxes.conf.cpu().numpy()
            classes = boxes.cls.cpu().numpy()
            best_idx = int(np.argmax(confidences))
            best_class = int(classes[best_idx])
            best_conf = float(confidences[best_idx])
            box = boxes.xyxy[best_idx].cpu().numpy()
            waste_type = self.waste_types.get(best_class, 'unknown')

            return {
                'waste_type': waste_type,
                'confidence': round(best_conf, 4),
                'points': self.points_map.get(waste_type, 5),
                'bbox': {
                    'x1': float(box[0]),
                    'y1': float(box[1]),
                    'x2': float(box[2]),
                    'y2': float(box[3]),
                },
                'all_detections': self._format_all_detections(results[0]),
            }
        except Exception as e:
            print(f'[ml_model] Inference error: {e}')
            return {
                'waste_type': 'error',
                'confidence': 0.0,
                'points': 0,
                'bbox': None,
                'error': str(e),
            }

    def _format_all_detections(self, result) -> List[Dict]:
        out = []
        boxes = result.boxes
        for i in range(len(boxes)):
            cls = int(boxes.cls[i].cpu().numpy())
            conf = float(boxes.conf[i].cpu().numpy())
            box = boxes.xyxy[i].cpu().numpy()
            out.append({
                'waste_type': self.waste_types.get(cls, 'unknown'),
                'confidence': round(conf, 4),
                'bbox': {
                    'x1': float(box[0]),
                    'y1': float(box[1]),
                    'x2': float(box[2]),
                    'y2': float(box[3]),
                },
            })
        return out

    def classify_batch(
        self,
        image_paths: List[str],
        conf_threshold: float = 0.25,
    ) -> List[Dict]:
        return [self.classify_image(p, conf_threshold) for p in image_paths]

    # ------------------- simulation -------------------

    def _simulate_classification(self) -> Dict:
        waste_type = random.choice(list(self.waste_types.values()))
        confidence = round(random.uniform(0.75, 0.98), 4)
        return {
            'waste_type': waste_type,
            'confidence': confidence,
            'points': self.points_map[waste_type],
            'bbox': {'x1': 100, 'y1': 100, 'x2': 300, 'y2': 300},
            'simulated': True,
        }

    # ------------------- info -------------------

    def get_model_info(self) -> Dict:
        if self.model is None:
            return {
                'loaded': False,
                'model_path': self.model_path,
                'yolov8_available': YOLOV8_AVAILABLE,
                'mode': 'simulation',
                'error': 'Model not loaded - running in simulation mode',
            }
        return {
            'loaded': True,
            'model_path': self.model_path,
            'model_type': 'YOLOv8',
            'yolov8_available': YOLOV8_AVAILABLE,
            'mode': 'ai',
            'num_classes': len(self.waste_types),
            'waste_types': list(self.waste_types.values()),
        }


_classifier_singleton: WasteClassifier = None


def get_classifier(
    model_path: str = 'models/waste_yolov8.pt',
) -> WasteClassifier:
    """Process-global classifier (lazy-instantiated)."""
    global _classifier_singleton
    if _classifier_singleton is None:
        _classifier_singleton = WasteClassifier(model_path)
    return _classifier_singleton
