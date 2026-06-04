"""Scan / classification routes."""
import os
import base64
from datetime import datetime

from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required
from werkzeug.utils import secure_filename
from PIL import Image

from database import db, User, Scan, PointsTransaction, DisposalTip, UserBadge, Badge
from ml_model import get_classifier
from ._helpers import current_user_id

scan_bp = Blueprint('scan', __name__)

UPLOAD_FOLDER = 'uploads/scans'
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg'}

os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# Single classifier instance (loads YOLOv8 model if available, else simulation).
classifier = get_classifier()


def _allowed_file(filename: str) -> bool:
    return (
        '.' in filename
        and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS
    )


def _classify_waste(image_path: str) -> dict:
    """Wrap classifier output into a uniform dict the route can rely on."""
    try:
        result = classifier.classify_image(image_path, conf_threshold=0.25)
        if result.get('waste_type') in ('unknown', 'error', None):
            return {
                'waste_type': None,
                'confidence': 0.0,
                'points': 0,
                'error': result.get('error', 'No waste detected in image'),
                'bbox': result.get('bbox'),
            }
        return {
            'waste_type': result['waste_type'],
            'confidence': float(result['confidence']),
            'points': int(result['points']),
            'bbox': result.get('bbox'),
            'all_detections': result.get('all_detections', []),
            'simulated': result.get('simulated', False),
        }
    except Exception as e:
        print(f'[classify] {e}')
        return {
            'waste_type': None,
            'confidence': 0.0,
            'points': 0,
            'error': str(e),
        }


def _check_and_award_badges(user: User) -> list:
    """Award any badges the user newly qualifies for. Returns list of awarded dicts."""
    awarded = []
    user_badge_ids = [
        ub.badge_id
        for ub in UserBadge.query.filter_by(user_id=user.id).all()
    ]
    available = Badge.query.filter(~Badge.id.in_(user_badge_ids)).all()
    for badge in available:
        if (user.total_points >= badge.points_required
                and user.total_scans >= badge.scans_required):
            db.session.add(UserBadge(user_id=user.id, badge_id=badge.id))
            # Bonus points equal to badge's points_required
            user.total_points += badge.points_required
            db.session.add(PointsTransaction(
                user_id=user.id,
                points=badge.points_required,
                transaction_type='badge',
                description=f'Badge: {badge.name}',
            ))
            awarded.append(badge.to_dict())
    return awarded


def _save_base64_image(uid: int, b64: str) -> str:
    """Decode a base64 (optionally data-URL) string and save it. Returns path."""
    if ',' in b64:
        b64 = b64.split(',', 1)[1]
    filename = f'{uid}_{int(datetime.utcnow().timestamp() * 1000)}.jpg'
    path = os.path.join(UPLOAD_FOLDER, filename)
    with open(path, 'wb') as f:
        f.write(base64.b64decode(b64))
    return path

def _center_crop_to_frame(image_path: str, frame_ratio: float = 0.6) -> str:
    """Crop the image to a centered square matching the on-screen green frame."""
    try:
        with Image.open(image_path) as im:
            im = im.convert('RGB')
            w, h = im.size
            short = min(w, h)
            crop_size = int(short * frame_ratio)
            left = (w - crop_size) // 2
            top = (h - crop_size) // 2
            right = left + crop_size
            bottom = top + crop_size
            cropped = im.crop((left, top, right, bottom))
            cropped.save(image_path, 'JPEG', quality=92)
    except Exception as e:
        print(f'[scan] crop failed, using uncropped image: {e}')
    return image_path

@scan_bp.route('/classify', methods=['POST'])
@jwt_required()
def classify_scan():
    """Accept an image, classify it, record a scan, award badges if any."""
    try:
        uid = current_user_id()
        user = User.query.get(uid)
        if not user:
            return jsonify({'error': 'User not found'}), 404

        # Locate the image (multipart 'image' or form field 'image_base64')
        if 'image' not in request.files and 'image_base64' not in request.form:
            return jsonify({'error': 'No image provided'}), 400

        # `source` form field signals whether we should center-crop:
        #   source=camera   -> crop to the green frame (default)
        #   source=gallery  -> use the image as-is
        source = (request.form.get('source') or 'camera').lower()

        image_path = None
        if 'image' in request.files:
            file = request.files['image']
            if not file.filename:
                return jsonify({'error': 'No selected file'}), 400
            if not _allowed_file(file.filename):
                return jsonify({
                    'error': 'Unsupported file type (png, jpg, jpeg only)',
                }), 400
            ts = int(datetime.utcnow().timestamp() * 1000)
            filename = secure_filename(f'{uid}_{ts}_{file.filename}')
            image_path = os.path.join(UPLOAD_FOLDER, filename)
            file.save(image_path)
        else:
            try:
                image_path = _save_base64_image(uid, request.form['image_base64'])
            except (ValueError, base64.binascii.Error) as e:
                return jsonify({'error': f'Invalid base64 image: {e}'}), 400

        # Crop to the on-screen green frame for camera captures
        if source == 'camera':
            _center_crop_to_frame(image_path)

        # Run inference
        result = _classify_waste(image_path)
        if result['waste_type'] is None:
            return jsonify({
                'error': result.get('error', 'Failed to classify waste'),
                'message': 'Please try again with a clearer image.',
            }), 400

        # Persist scan
        scan = Scan(
            user_id=uid,
            waste_type=result['waste_type'],
            confidence=result['confidence'],
            points_earned=result['points'],
            image_path=image_path,
        )
        db.session.add(scan)

        # Update user aggregates
        user.total_scans += 1
        user.total_points += result['points']
        if user.total_scans == 1:
            user.accuracy = result['confidence'] * 100
        else:
            user.accuracy = (
                (user.accuracy * (user.total_scans - 1))
                + (result['confidence'] * 100)
            ) / user.total_scans

        db.session.add(PointsTransaction(
            user_id=uid,
            points=result['points'],
            transaction_type='scan',
            description=f"{result['waste_type'].capitalize()} scan",
        ))

        tips = DisposalTip.query.filter_by(
            waste_type=result['waste_type']
        ).first()
        awarded_badges = _check_and_award_badges(user)
        db.session.commit()

        return jsonify({
            'message': 'Scan classified successfully',
            'scan': scan.to_dict(),
            'detection': {
                'waste_type': result['waste_type'],
                'confidence': result['confidence'],
                'bbox': result.get('bbox'),
                'all_detections': result.get('all_detections', []),
                'simulated': result.get('simulated', False),
            },
            'disposal_tips': tips.to_dict() if tips else None,
            'user_stats': {
                'total_points': user.total_points,
                'total_scans': user.total_scans,
                'accuracy': float(round(user.accuracy, 2)),
            },
            'awarded_badges': awarded_badges,
        }), 201

    except Exception as e:
        db.session.rollback()
        print(f'[classify_scan] {e}')
        return jsonify({'error': str(e)}), 500


@scan_bp.route('/history', methods=['GET'])
@jwt_required()
def get_scan_history():
    """Mirror of /user/history (kept for backwards compatibility)."""
    try:
        uid = current_user_id()
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 20, type=int)
        scans = (
            Scan.query.filter_by(user_id=uid)
            .order_by(Scan.created_at.desc())
            .paginate(page=page, per_page=per_page, error_out=False)
        )
        return jsonify({
            'scans': [s.to_dict() for s in scans.items],
            'total': scans.total,
            'pages': scans.pages,
            'current_page': page,
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@scan_bp.route('/<int:scan_id>', methods=['GET'])
@jwt_required()
def get_scan_details(scan_id):
    """Details of one scan owned by the caller."""
    try:
        uid = current_user_id()
        scan = Scan.query.filter_by(id=scan_id, user_id=uid).first()
        if not scan:
            return jsonify({'error': 'Scan not found'}), 404
        tips = DisposalTip.query.filter_by(waste_type=scan.waste_type).first()
        return jsonify({
            'scan': scan.to_dict(),
            'disposal_tips': tips.to_dict() if tips else None,
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@scan_bp.route('/model-info', methods=['GET'])
def get_model_info():
    """Surface info about the loaded model (or simulation mode)."""
    try:
        return jsonify(classifier.get_model_info()), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
