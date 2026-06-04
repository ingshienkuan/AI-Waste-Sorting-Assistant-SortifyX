"""Authentication routes: register, login, current user, change password."""
from datetime import datetime

from flask import Blueprint, request, jsonify
from flask_jwt_extended import create_access_token, jwt_required

from database import db, User
from ._helpers import current_user_id

auth_bp = Blueprint('auth', __name__)


def _require_fields(data, fields):
    """Return (missing_field_name, response) or (None, None)."""
    if not isinstance(data, dict):
        return 'body', (jsonify({'error': 'Request body must be JSON'}), 400)
    for f in fields:
        if f not in data or data[f] in (None, ''):
            return f, (jsonify({'error': f'Missing required field: {f}'}), 400)
    return None, None


@auth_bp.route('/register', methods=['POST'])
def register():
    """Create a new (non-admin) account and return an access token."""
    try:
        data = request.get_json(silent=True)
        missing, err = _require_fields(data, ('username', 'email', 'password'))
        if missing:
            return err

        username = data['username'].strip()
        email = data['email'].strip().lower()
        password = data['password']

        if len(username) < 3:
            return jsonify({'error': 'Username must be at least 3 characters'}), 400
        if len(password) < 6:
            return jsonify({'error': 'Password must be at least 6 characters'}), 400

        if User.query.filter_by(email=email).first():
            return jsonify({'error': 'Email already registered'}), 400
        if User.query.filter_by(username=username).first():
            return jsonify({'error': 'Username already taken'}), 400

        user = User(
            username=username,
            email=email,
            is_admin=False,
            is_active=True,
        )
        user.set_password(password)
        db.session.add(user)
        db.session.commit()

        # identity loader stringifies for us
        token = create_access_token(identity=user)
        return jsonify({
            'message': 'User registered successfully',
            'access_token': token,
            'user': user.to_dict(),
        }), 201

    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


@auth_bp.route('/login', methods=['POST'])
def login():
    """Authenticate a user (or admin) and return an access token."""
    try:
        data = request.get_json(silent=True)
        missing, err = _require_fields(data, ('email', 'password'))
        if missing:
            return err

        email = data['email'].strip().lower()
        password = data['password']
        is_admin_login = bool(data.get('is_admin', False))

        user = User.query.filter_by(email=email).first()
        if not user or not user.check_password(password):
            return jsonify({'error': 'Invalid email or password'}), 401

        if not user.is_active:
            return jsonify({'error': 'Account is inactive'}), 403

        if is_admin_login and not user.is_admin:
            return jsonify({'error': 'Unauthorized admin access'}), 403

        user.updated_at = datetime.utcnow()
        db.session.commit()

        token = create_access_token(identity=user)
        return jsonify({
            'message': 'Login successful',
            'access_token': token,
            'user': user.to_dict(),
        }), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


@auth_bp.route('/me', methods=['GET'])
@jwt_required()
def get_current_user():
    """Return the currently authenticated user."""
    user = User.query.get(current_user_id())
    if not user:
        return jsonify({'error': 'User not found'}), 404
    return jsonify({'user': user.to_dict()}), 200


@auth_bp.route('/change-password', methods=['POST'])
@jwt_required()
def change_password():
    """Change the authenticated user's password."""
    try:
        user = User.query.get(current_user_id())
        if not user:
            return jsonify({'error': 'User not found'}), 404

        data = request.get_json(silent=True)
        missing, err = _require_fields(data, ('current_password', 'new_password'))
        if missing:
            return err

        if not user.check_password(data['current_password']):
            return jsonify({'error': 'Current password is incorrect'}), 401
        if len(data['new_password']) < 6:
            return jsonify({'error': 'New password must be at least 6 characters'}), 400

        user.set_password(data['new_password'])
        user.updated_at = datetime.utcnow()
        db.session.commit()

        return jsonify({'message': 'Password changed successfully'}), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500
