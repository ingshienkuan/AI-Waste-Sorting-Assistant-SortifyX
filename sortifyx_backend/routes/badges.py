"""Badge routes: list all badges, list earned badges, badge details."""
from flask import Blueprint, jsonify
from flask_jwt_extended import jwt_required

from database import Badge, UserBadge, User
from ._helpers import current_user_id

badges_bp = Blueprint('badges', __name__)


def _progress(user_points: int, user_scans: int, badge: Badge) -> dict:
    if badge.points_required > 0:
        points_pct = min(100.0, (user_points / badge.points_required) * 100)
    else:
        points_pct = 100.0
    if badge.scans_required > 0:
        scans_pct = min(100.0, (user_scans / badge.scans_required) * 100)
    else:
        scans_pct = 100.0
    return {
        'points': round(points_pct, 2),
        'scans': round(scans_pct, 2),
        'overall': round(min(points_pct, scans_pct), 2),
        'points_needed': max(0, badge.points_required - user_points),
        'scans_needed': max(0, badge.scans_required - user_scans),
    }


@badges_bp.route('/all', methods=['GET'])
@jwt_required()
def get_all_badges():
    """All badges with earned/progress info for the caller."""
    try:
        uid = current_user_id()
        all_badges = Badge.query.order_by(Badge.points_required.asc()).all()
        user_badges = UserBadge.query.filter_by(user_id=uid).all()
        earned_ids = {ub.badge_id for ub in user_badges}
        user = User.query.get(uid)
        user_points = user.total_points if user else 0
        user_scans = user.total_scans if user else 0

        badges_data = []
        for b in all_badges:
            d = b.to_dict()
            d['earned'] = b.id in earned_ids
            if b.id in earned_ids:
                ub = next(x for x in user_badges if x.badge_id == b.id)
                d['earned_at'] = ub.earned_at.isoformat()
            else:
                d['progress'] = _progress(user_points, user_scans, b)
            badges_data.append(d)

        return jsonify({'badges': badges_data}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@badges_bp.route('/earned', methods=['GET'])
@jwt_required()
def get_earned_badges():
    """Only the badges the caller has earned."""
    try:
        uid = current_user_id()
        user_badges = (
            UserBadge.query.filter_by(user_id=uid)
            .order_by(UserBadge.earned_at.desc())
            .all()
        )
        return jsonify({
            'badges': [ub.to_dict() for ub in user_badges],
            'total': len(user_badges),
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@badges_bp.route('/<int:badge_id>', methods=['GET'])
@jwt_required()
def get_badge_details(badge_id):
    """Single badge with progress info for the caller."""
    try:
        uid = current_user_id()
        badge = Badge.query.get(badge_id)
        if not badge:
            return jsonify({'error': 'Badge not found'}), 404

        user_badge = UserBadge.query.filter_by(
            user_id=uid, badge_id=badge_id
        ).first()
        d = badge.to_dict()
        d['earned'] = user_badge is not None
        if user_badge:
            d['earned_at'] = user_badge.earned_at.isoformat()
        else:
            user = User.query.get(uid)
            d['progress'] = _progress(
                user.total_points if user else 0,
                user.total_scans if user else 0,
                badge,
            )
        return jsonify({'badge': d}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
