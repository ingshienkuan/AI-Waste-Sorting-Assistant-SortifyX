"""Rewards routes: summary, available rewards, redeem points."""
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required

from database import db, User, PointsTransaction, UserBadge, Badge
from ._helpers import current_user_id

rewards_bp = Blueprint('rewards', __name__)


# Static catalogue (would normally live in the database)
_AVAILABLE_REWARDS = [
    {'id': 1, 'name': 'RM5 Touch n Go eWallet', 'points_required': 150,
     'description': 'RM5 credit for your Touch n Go eWallet',
     'category': 'voucher', 'icon': 'card_giftcard'},
    {'id': 2, 'name': 'RM10 Grab Voucher', 'points_required': 300,
     'description': 'RM10 off your next GrabFood / GrabCar order',
     'category': 'voucher', 'icon': 'local_taxi'},
    {'id': 3, 'name': 'RM20 Shopee Voucher', 'points_required': 600,
     'description': 'RM20 off on eco-friendly products at Shopee',
     'category': 'voucher', 'icon': 'shopping_bag'},
    {'id': 4, 'name': 'Reusable Water Bottle', 'points_required': 400,
     'description': 'Premium stainless steel water bottle (500ml)',
     'category': 'product', 'icon': 'water_drop'},
    {'id': 5, 'name': 'Eco Tote Bag', 'points_required': 200,
     'description': 'Reusable shopping bag made from recycled materials',
     'category': 'product', 'icon': 'shopping_basket'},
    {'id': 6, 'name': 'Plant a Tree', 'points_required': 500,
     'description': 'We plant a tree on your behalf via a partner NGO',
     'category': 'impact', 'icon': 'park'},
]


@rewards_bp.route('/summary', methods=['GET'])
@jwt_required()
def get_rewards_summary():
    """Quick stats used by the Rewards screen."""
    try:
        uid = current_user_id()
        user = User.query.get(uid)
        if not user:
            return jsonify({'error': 'User not found'}), 404

        earned_badges = UserBadge.query.filter_by(user_id=uid).count()
        total_badges = Badge.query.count()

        return jsonify({
            'total_points': user.total_points,
            'total_scans': user.total_scans,
            'earned_badges': earned_badges,
            'total_badges': total_badges,
            'accuracy': float(round(user.accuracy, 2)),
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@rewards_bp.route('/available', methods=['GET'])
def get_available_rewards():
    """Catalogue of rewards a user can redeem points for."""
    return jsonify({'rewards': _AVAILABLE_REWARDS}), 200


@rewards_bp.route('/redeem', methods=['POST'])
@jwt_required()
def redeem_points():
    """Subtract points from the caller's balance and record a transaction."""
    try:
        uid = current_user_id()
        user = User.query.get(uid)
        if not user:
            return jsonify({'error': 'User not found'}), 404

        data = request.get_json(silent=True) or {}
        if 'points' not in data or 'reward_name' not in data:
            return jsonify({'error': 'Missing required fields'}), 400

        try:
            points_to_redeem = int(data['points'])
        except (TypeError, ValueError):
            return jsonify({'error': 'points must be an integer'}), 400
        if points_to_redeem <= 0:
            return jsonify({'error': 'points must be positive'}), 400

        if user.total_points < points_to_redeem:
            return jsonify({'error': 'Insufficient points'}), 400

        user.total_points -= points_to_redeem
        transaction = PointsTransaction(
            user_id=uid,
            points=-points_to_redeem,
            transaction_type='redemption',
            description=f"Redeemed: {data['reward_name']}",
        )
        db.session.add(transaction)
        db.session.commit()

        return jsonify({
            'message': 'Points redeemed successfully',
            'remaining_points': user.total_points,
            'transaction': transaction.to_dict(),
        }), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500
