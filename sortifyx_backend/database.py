from flask_sqlalchemy import SQLAlchemy
from datetime import datetime
from werkzeug.security import generate_password_hash, check_password_hash

db = SQLAlchemy()

class User(db.Model):
    __tablename__ = 'users'
    
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    is_admin = db.Column(db.Boolean, default=False)
    is_active = db.Column(db.Boolean, default=True)
    total_points = db.Column(db.Integer, default=0)
    total_scans = db.Column(db.Integer, default=0)
    accuracy = db.Column(db.Float, default=0.0)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    scans = db.relationship('Scan', backref='user', lazy=True, cascade='all, delete-orphan')
    badges = db.relationship('UserBadge', backref='user', lazy=True, cascade='all, delete-orphan')
    transactions = db.relationship('PointsTransaction', backref='user', lazy=True, cascade='all, delete-orphan')
    
    def set_password(self, password):
        self.password_hash = generate_password_hash(password)
    
    def check_password(self, password):
        return check_password_hash(self.password_hash, password)
    
    def to_dict(self):
        return {
            'id': self.id,
            'username': self.username,
            'email': self.email,
            'is_admin': self.is_admin,
            'is_active': self.is_active,
            'total_points': self.total_points,
            'total_scans': self.total_scans,
            'accuracy': round(self.accuracy, 2),
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat()
        }

class Scan(db.Model):
    __tablename__ = 'scans'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    waste_type = db.Column(db.String(50), nullable=False)  # plastic, metal, glass, paper, organic
    confidence = db.Column(db.Float, nullable=False)
    points_earned = db.Column(db.Integer, nullable=False)
    image_path = db.Column(db.String(255), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'waste_type': self.waste_type,
            'confidence': round(self.confidence, 2),
            'points_earned': self.points_earned,
            'image_path': self.image_path,
            'created_at': self.created_at.isoformat()
        }

class Badge(db.Model):
    __tablename__ = 'badges'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), unique=True, nullable=False)
    description = db.Column(db.Text, nullable=False)
    icon = db.Column(db.String(50), nullable=False)
    points_required = db.Column(db.Integer, nullable=False)
    scans_required = db.Column(db.Integer, default=0)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'description': self.description,
            'icon': self.icon,
            'points_required': self.points_required,
            'scans_required': self.scans_required,
            'created_at': self.created_at.isoformat()
        }

class UserBadge(db.Model):
    __tablename__ = 'user_badges'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    badge_id = db.Column(db.Integer, db.ForeignKey('badges.id'), nullable=False)
    earned_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    badge = db.relationship('Badge', backref='user_badges')
    
    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'badge': self.badge.to_dict(),
            'earned_at': self.earned_at.isoformat()
        }

class PointsTransaction(db.Model):
    __tablename__ = 'points_transactions'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    points = db.Column(db.Integer, nullable=False)  # positive for earned, negative for spent
    transaction_type = db.Column(db.String(50), nullable=False)  # scan, badge, redemption
    description = db.Column(db.String(255), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'points': self.points,
            'transaction_type': self.transaction_type,
            'description': self.description,
            'created_at': self.created_at.isoformat()
        }

class DisposalTip(db.Model):
    __tablename__ = 'disposal_tips'
    
    id = db.Column(db.Integer, primary_key=True)
    waste_type = db.Column(db.String(50), nullable=False)
    tips = db.Column(db.JSON, nullable=False)  # List of tips
    bin_color = db.Column(db.String(20), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        return {
            'id': self.id,
            'waste_type': self.waste_type,
            'tips': self.tips,
            'bin_color': self.bin_color,
            'created_at': self.created_at.isoformat()
        }

def init_db():
    """Initialize database with tables and seed data"""
    db.create_all()
    
    # Seed badges if not exist
    if Badge.query.count() == 0:
        badges = [
            Badge(name='Beginner', description='Successfully classified 10 items correctly.', 
                  icon='energy_savings_leaf', points_required=100, scans_required=10),
            Badge(name='Recycler', description='Successfully classified 25 recyclable items correctly.', 
                  icon='recycling', points_required=250, scans_required=25),
            Badge(name='Eco Hero', description='Successfully classified 50 items correctly.', 
                  icon='public', points_required=500, scans_required=50),
            Badge(name='Dedicated', description='Successfully classified 75 items correctly.', 
                  icon='volunteer_activism', points_required=750, scans_required=75),
            Badge(name='Master', description='Successfully classified 100 items correctly.', 
                  icon='workspace_premium', points_required=1000, scans_required=100),
            Badge(name='Star', description='Successfully classified 150 items correctly.', 
                  icon='star', points_required=1500, scans_required=150),
            Badge(name='Champion', description='Successfully classified 200 items correctly.', 
                  icon='emoji_events', points_required=2000, scans_required=200),
        ]
        db.session.bulk_save_objects(badges)
        db.session.commit()
    
    # Seed disposal tips if not exist
    if DisposalTip.query.count() == 0:
        tips = [
            DisposalTip(
                waste_type='plastic',
                tips=['Use BLUE recycling bin', 'Rinse before disposing', 'Remove caps and label'],
                bin_color='BLUE'
            ),
            DisposalTip(
                waste_type='metal',
                tips=['Use BLUE recycling bin', 'Clean and dry before disposal', 'Flatten cans to save space'],
                bin_color='BLUE'
            ),
            DisposalTip(
                waste_type='glass',
                tips=['Use BLUE recycling bin', 'Rinse thoroughly', 'Remove lids and caps'],
                bin_color='BLUE'
            ),
            DisposalTip(
                waste_type='paper',
                tips=['Use BLUE recycling bin', 'Keep dry and clean', 'Remove any plastic coating'],
                bin_color='BLUE'
            ),
            DisposalTip(
                waste_type='cardboard',
                tips=['Use BLUE recycling bin', 'Flatten boxes to save space', 'Remove tape and staples'],
                bin_color='BLUE'
            ),
            DisposalTip(
                waste_type='organic',
                tips=['Use GREEN composting bin', 'No plastic bags', 'Keep separate from recyclables'],
                bin_color='GREEN'
            ),
            DisposalTip(
                waste_type='non_recyclable',
                tips=['Use BLACK general waste bin', 'Do not mix with recyclables', 'Tie bags securely'],
                bin_color='BLACK'
            ),
        ]
        db.session.bulk_save_objects(tips)
        db.session.commit()
    
    # Create admin user if not exist
    if not User.query.filter_by(email='admin@sortifyx.com').first():
        admin = User(
            username='admin',
            email='admin@sortifyx.com',
            is_admin=True,
            is_active=True
        )
        admin.set_password('admin123')
        db.session.add(admin)
        db.session.commit()
