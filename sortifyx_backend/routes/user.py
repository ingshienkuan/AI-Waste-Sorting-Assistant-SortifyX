"""User-facing routes: profile, stats, scan history, points history."""
from datetime import datetime

from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required
from sqlalchemy import func

from database import db, User, Scan, UserBadge, PointsTransaction
from ._helpers import current_user_id

user_bp = Blueprint('user', __name__)


@user_bp.route('/profile', methods=['GET'])
@jwt_required()
def get_profile():
    """Return the authenticated user's profile."""
    try:
        user = User.query.get(current_user_id())
        if not user:
            return jsonify({'error': 'User not found'}), 404
        return jsonify({'user': user.to_dict()}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@user_bp.route('/profile', methods=['PUT'])
@jwt_required()
def update_profile():
    """Update mutable profile fields (username, email)."""
    try:
        user = User.query.get(current_user_id())
        if not user:
            return jsonify({'error': 'User not found'}), 404

        data = request.get_json(silent=True) or {}

        if 'username' in data and data['username']:
            new_username = data['username'].strip()
            if len(new_username) < 3:
                return jsonify({'error': 'Username must be at least 3 characters'}), 400
            existing = User.query.filter_by(username=new_username).first()
            if existing and existing.id != user.id:
                return jsonify({'error': 'Username already taken'}), 400
            user.username = new_username

        if 'email' in data and data['email']:
            new_email = data['email'].strip().lower()
            existing = User.query.filter_by(email=new_email).first()
            if existing and existing.id != user.id:
                return jsonify({'error': 'Email already registered'}), 400
            user.email = new_email

        user.updated_at = datetime.utcnow()
        db.session.commit()
        return jsonify({
            'message': 'Profile updated successfully',
            'user': user.to_dict(),
        }), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


@user_bp.route('/stats', methods=['GET'])
@jwt_required()
def get_stats():
    """Return aggregate stats used by the home screen."""
    try:
        uid = current_user_id()
        user = User.query.get(uid)
        if not user:
            return jsonify({'error': 'User not found'}), 404

        recent_scans = (
            Scan.query.filter_by(user_id=uid)
            .order_by(Scan.created_at.desc())
            .limit(5)
            .all()
        )
        earned_badges = UserBadge.query.filter_by(user_id=uid).count()
        today = datetime.utcnow().date()
        scans_today = (
            Scan.query.filter_by(user_id=uid)
            .filter(func.date(Scan.created_at) == today)
            .count()
        )

        return jsonify({
            'total_points': user.total_points,
            'total_scans': user.total_scans,
            # Always return as float so the client doesn't have to handle int|float.
            'accuracy': float(round(user.accuracy, 2)),
            'earned_badges': earned_badges,
            'scans_today': scans_today,
            'recent_scans': [s.to_dict() for s in recent_scans],
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@user_bp.route('/history', methods=['GET'])
@jwt_required()
def get_history():
    """Paginated scan history for the authenticated user."""
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


@user_bp.route('/points/history', methods=['GET'])
@jwt_required()
def get_points_history():
    """Paginated points-transaction history with optional type filter."""
    try:
        uid = current_user_id()
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 20, type=int)
        filter_type = request.args.get('type', 'all')

        query = PointsTransaction.query.filter_by(user_id=uid)
        if filter_type == 'earned':
            query = query.filter(PointsTransaction.points > 0)
        elif filter_type == 'spent':
            query = query.filter(PointsTransaction.points < 0)

        transactions = (
            query.order_by(PointsTransaction.created_at.desc())
            .paginate(page=page, per_page=per_page, error_out=False)
        )

        total_earned = db.session.query(func.sum(PointsTransaction.points)).filter(
            PointsTransaction.user_id == uid,
            PointsTransaction.points > 0,
        ).scalar() or 0

        total_spent_raw = db.session.query(func.sum(PointsTransaction.points)).filter(
            PointsTransaction.user_id == uid,
            PointsTransaction.points < 0,
        ).scalar() or 0
        total_spent = abs(total_spent_raw)

        return jsonify({
            'transactions': [t.to_dict() for t in transactions.items],
            'total_earned': int(total_earned),
            'total_spent': int(total_spent),
            'total': transactions.total,
            'pages': transactions.pages,
            'current_page': page,
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
