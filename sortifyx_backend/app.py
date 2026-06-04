"""
SortifyX Backend - Application entry point.

Run:
    python app.py

First-time setup (creates tables + seeds admin user, badges, tips):
    python -c "from app import app; from database import init_db; \\
               app.app_context().push(); init_db()"

Default admin:  admin@sortifyx.com / admin123
"""
from datetime import timedelta
import os

from flask import Flask, jsonify
from flask_cors import CORS
from flask_jwt_extended import JWTManager
from dotenv import load_dotenv

# Blueprints
from routes.auth import auth_bp
from routes.user import user_bp
from routes.admin import admin_bp
from routes.scan import scan_bp
from routes.rewards import rewards_bp
from routes.badges import badges_bp

# Database
from database import db, User, init_db

load_dotenv()

app = Flask(__name__)

# --- Configuration ---
app.config['SECRET_KEY'] = os.getenv(
    'SECRET_KEY', 'dev-secret-change-in-production'
)
app.config['JWT_SECRET_KEY'] = os.getenv(
    'JWT_SECRET_KEY', 'dev-jwt-secret-change-in-production'
)
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(days=7)
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv(
    'DATABASE_URL', 'sqlite:///sortifyx.db'
)
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16 MB upload cap
app.config['JSON_SORT_KEYS'] = False

# --- Extensions ---
CORS(app, resources={r"/api/*": {"origins": "*"}})
jwt = JWTManager(app)
db.init_app(app)


# ----------------------------------------------------------------------
# JWT identity handling.
# flask-jwt-extended 4.6+ requires the JWT `sub` claim to be a string.
# We keep using int user IDs everywhere in the app and just stringify
# them at the boundary. The user_lookup_loader below converts the
# string identity back to a User instance so views can do
# `current_user.id` (or, with the kept compatibility, get_jwt_identity()
# returns an int).
# ----------------------------------------------------------------------
@jwt.user_identity_loader
def _user_identity_lookup(user):
    """Accept either a User, an int id, or a str id and emit a string."""
    if hasattr(user, 'id'):
        return str(user.id)
    return str(user)


@jwt.user_lookup_loader
def _user_lookup_callback(_jwt_header, jwt_data):
    identity = jwt_data['sub']
    try:
        return User.query.get(int(identity))
    except (TypeError, ValueError):
        return None


# Friendly JSON errors for common JWT failures
@jwt.unauthorized_loader
def _missing_token(reason):
    return jsonify({'error': f'Missing or invalid token: {reason}'}), 401


@jwt.invalid_token_loader
def _invalid_token(reason):
    return jsonify({'error': f'Invalid token: {reason}'}), 422


@jwt.expired_token_loader
def _expired_token(_header, _payload):
    return jsonify({'error': 'Token has expired'}), 401


# --- Blueprints ---
app.register_blueprint(auth_bp, url_prefix='/api/auth')
app.register_blueprint(user_bp, url_prefix='/api/user')
app.register_blueprint(admin_bp, url_prefix='/api/admin')
app.register_blueprint(scan_bp, url_prefix='/api/scan')
app.register_blueprint(rewards_bp, url_prefix='/api/rewards')
app.register_blueprint(badges_bp, url_prefix='/api/badges')


# --- Health check ---
@app.route('/api/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'healthy', 'message': 'SortifyX API is running'}), 200


# --- Error handlers ---
@app.errorhandler(404)
def _not_found(_error):
    return jsonify({'error': 'Endpoint not found'}), 404


@app.errorhandler(413)
def _too_large(_error):
    return jsonify({'error': 'File too large (max 16 MB)'}), 413


@app.errorhandler(500)
def _internal_error(_error):
    return jsonify({'error': 'Internal server error'}), 500


# Auto-initialize the database on first run so users don't have to
# remember the bootstrap command.
with app.app_context():
    init_db()


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
