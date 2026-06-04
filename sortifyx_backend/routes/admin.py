"""Admin routes: dashboard, user management, statistics."""
from datetime import datetime, timedelta

from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required
from sqlalchemy import func

from database import db, User, Scan, UserBadge, PointsTransaction
from ._helpers import admin_required

admin_bp = Blueprint('admin', __name__)


@admin_bp.route('/dashboard', methods=['GET'])
@jwt_required()
@admin_required
def get_dashboard_stats():
    """Aggregate stats for the admin home screen."""
    try:
        total_users = User.query.filter_by(is_admin=False).count()

        thirty_days_ago = datetime.utcnow() - timedelta(days=30)
        active_users = db.session.query(
            func.count(func.distinct(Scan.user_id))
        ).filter(Scan.created_at >= thirty_days_ago).scalar() or 0

        total_scans = Scan.query.count()

        today = datetime.utcnow().date()
        scans_today = Scan.query.filter(
            func.date(Scan.created_at) == today
        ).count()

        avg_accuracy = db.session.query(func.avg(User.accuracy)).filter(
            User.is_admin == False  # noqa: E712
        ).scalar() or 0

        first_day_of_month = datetime.utcnow().replace(
            day=1, hour=0, minute=0, second=0, microsecond=0
        )
        new_users_this_month = User.query.filter(
            User.is_admin == False,  # noqa: E712
            User.created_at >= first_day_of_month,
        ).count()

        last_month_start = (
            first_day_of_month - timedelta(days=1)
        ).replace(day=1)
        last_month_users = User.query.filter(
            User.is_admin == False,  # noqa: E712
            User.created_at >= last_month_start,
            User.created_at < first_day_of_month,
        ).count()

        growth_percentage = 0.0
        if last_month_users > 0:
            growth_percentage = (
                (new_users_this_month - last_month_users) / last_month_users
            ) * 100

        return jsonify({
            'total_users': total_users,
            'active_users': int(active_users),
            'inactive_users': total_users - int(active_users),
            'total_scans': total_scans,
            'scans_today': scans_today,
            'accuracy': float(round(avg_accuracy, 2)),
            'new_users_this_month': new_users_this_month,
            'growth_percentage': float(round(growth_percentage, 2)),
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@admin_bp.route('/users', methods=['GET'])
@jwt_required()
@admin_required
def get_users():
    """List all non-admin users, paginated."""
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 50, type=int)

        paginated = (
            User.query.filter_by(is_admin=False)
            .order_by(User.created_at.desc())
            .paginate(page=page, per_page=per_page, error_out=False)
        )

        return jsonify({
            'users': [u.to_dict() for u in paginated.items],
            'total': paginated.total,
            'pages': paginated.pages,
            'current_page': page,
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@admin_bp.route('/users/<int:user_id>', methods=['GET'])
@jwt_required()
@admin_required
def get_user_details(user_id):
    """Detailed view of a single user, with recent activity."""
    try:
        user = User.query.filter_by(id=user_id, is_admin=False).first()
        if not user:
            return jsonify({'error': 'User not found'}), 404

        recent_scans = (
            Scan.query.filter_by(user_id=user_id)
            .order_by(Scan.created_at.desc())
            .limit(10)
            .all()
        )
        earned_badges = UserBadge.query.filter_by(user_id=user_id).count()
        recent_transactions = (
            PointsTransaction.query.filter_by(user_id=user_id)
            .order_by(PointsTransaction.created_at.desc())
            .limit(10)
            .all()
        )

        return jsonify({
            'user': user.to_dict(),
            'recent_scans': [s.to_dict() for s in recent_scans],
            'earned_badges': earned_badges,
            'recent_transactions': [t.to_dict() for t in recent_transactions],
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@admin_bp.route('/users/<int:user_id>/toggle-status', methods=['PUT'])
@jwt_required()
@admin_required
def toggle_user_status(user_id):
    """Activate or deactivate a user account."""
    try:
        user = User.query.filter_by(id=user_id, is_admin=False).first()
        if not user:
            return jsonify({'error': 'User not found'}), 404

        user.is_active = not user.is_active
        user.updated_at = datetime.utcnow()
        db.session.commit()

        status = 'activated' if user.is_active else 'deactivated'
        return jsonify({
            'message': f'User {status} successfully',
            'user': user.to_dict(),
        }), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


@admin_bp.route('/statistics/users', methods=['GET'])
@jwt_required()
@admin_required
def get_user_statistics():
    """Detailed user statistics with weekly registration chart data."""
    try:
        total_users = User.query.filter_by(is_admin=False).count()
        active_users = User.query.filter_by(
            is_admin=False, is_active=True
        ).count()
        inactive_users = total_users - active_users

        verified_users = db.session.query(
            func.count(func.distinct(User.id))
        ).join(Scan).filter(User.is_admin == False).scalar() or 0  # noqa: E712

        week_ago = datetime.utcnow() - timedelta(days=7)
        new_this_week = User.query.filter(
            User.is_admin == False,  # noqa: E712
            User.created_at >= week_ago,
        ).count()

        weekly_data = []
        for i in range(6, -1, -1):  # last 7 days
            day = datetime.utcnow() - timedelta(days=i)
            day_start = day.replace(hour=0, minute=0, second=0, microsecond=0)
            day_end = day_start + timedelta(days=1)
            count = User.query.filter(
                User.is_admin == False,  # noqa: E712
                User.created_at >= day_start,
                User.created_at < day_end,
            ).count()
            weekly_data.append({'day': day.strftime('%a'), 'count': count})

        top_users = (
            User.query.filter_by(is_admin=False)
            .order_by(User.total_points.desc())
            .limit(10)
            .all()
        )

        return jsonify({
            'total_users': total_users,
            'active_users': active_users,
            'inactive_users': inactive_users,
            'verified_users': int(verified_users),
            'new_this_week': new_this_week,
            'weekly_registrations': weekly_data,
            'top_users': [{
                'id': u.id,
                'username': u.username,
                'total_points': u.total_points,
                'total_scans': u.total_scans,
            } for u in top_users],
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@admin_bp.route('/statistics/scans', methods=['GET'])
@jwt_required()
@admin_required
def get_scan_statistics():
    """Scan-related statistics."""
    try:
        total_scans = Scan.query.count()

        scans_by_type = db.session.query(
            Scan.waste_type, func.count(Scan.id).label('count')
        ).group_by(Scan.waste_type).all()

        avg_confidence = db.session.query(func.avg(Scan.confidence)).scalar() or 0

        daily_scans = []
        for i in range(6, -1, -1):
            day = datetime.utcnow() - timedelta(days=i)
            day_start = day.replace(hour=0, minute=0, second=0, microsecond=0)
            day_end = day_start + timedelta(days=1)
            count = Scan.query.filter(
                Scan.created_at >= day_start,
                Scan.created_at < day_end,
            ).count()
            daily_scans.append({
                'date': day.strftime('%Y-%m-%d'),
                'count': count,
            })

        return jsonify({
            'total_scans': total_scans,
            'scans_by_type': [
                {'type': t[0], 'count': t[1]} for t in scans_by_type
            ],
            'average_confidence': float(round(avg_confidence * 100, 2)),
            'daily_scans': daily_scans,
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
