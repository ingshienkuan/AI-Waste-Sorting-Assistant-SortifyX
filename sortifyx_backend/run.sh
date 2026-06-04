#!/bin/bash

# SortifyX Backend Startup Script

echo "========================================="
echo "    SortifyX Backend Server Startup"
echo "========================================="
echo ""

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Virtual environment not found. Creating one..."
    python3 -m venv venv
    echo "✓ Virtual environment created"
fi

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate
echo "✓ Virtual environment activated"

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "⚠ .env file not found. Copying from .env.example..."
    cp .env.example .env
    echo "✓ .env file created. Please update it with your settings."
fi

# Install dependencies
echo ""
echo "Installing/Updating dependencies..."
pip install -r requirements.txt
echo "✓ Dependencies installed"

# Initialize database
echo ""
echo "Initializing database..."
python -c "from app import app; from database import init_db; app.app_context().push(); init_db()"
echo "✓ Database initialized"

# Start server
echo ""
echo "========================================="
echo "Starting Flask server on http://localhost:5000"
echo "Default admin login:"
echo "  Email: admin@sortifyx.com"
echo "  Password: admin123"
echo "========================================="
echo ""
python app.py
