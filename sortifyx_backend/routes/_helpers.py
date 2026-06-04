"""Shared helpers for blueprint route handlers."""
from functools import wraps
from flask import jsonify
from flask_jwt_extended import get_jwt_identity
from database import User


def current_user_id() -> int:
    """Return the integer id of the JWT subject.

    JWT subjects are stored as strings (flask-jwt-extended 4.x requirement)
    but the rest of the app uses int ids.
    """
    raw = get_jwt_identity()
    if raw is None:
        return None
    try:
        return int(raw)
    except (TypeError, ValueError):
        return None


def admin_required(view):
    """Decorator that 403s if the JWT identity does not belong to an admin.

    Usage:
        @admin_bp.route('/...')
        @jwt_required()
        @admin_required
        def handler(): ...
    """
    @wraps(view)
    def wrapper(*args, **kwargs):
        uid = current_user_id()
        user = User.query.get(uid) if uid is not None else None
        if not user or not user.is_admin:
            return jsonify({'error': 'Admin access required'}), 403
        return view(*args, **kwargs)
    return wrapper
