@echo off
REM SortifyX Backend Startup Script for Windows

echo =========================================
echo     SortifyX Backend Server Startup
echo =========================================
echo.

REM Check if virtual environment exists
if not exist "venv" (
    echo Virtual environment not found. Creating one...
    python -m venv venv
    echo Virtual environment created
)

REM Activate virtual environment
echo Activating virtual environment...
call venv\Scripts\activate
echo Virtual environment activated

REM Check if .env file exists
if not exist ".env" (
    echo .env file not found. Copying from .env.example...
    copy .env.example .env
    echo .env file created. Please update it with your settings.
)

REM Install dependencies
echo.
echo Installing/Updating dependencies...
pip install -r requirements.txt
echo Dependencies installed

REM Initialize database
echo.
echo Initializing database...
python -c "from app import app; from database import init_db; app.app_context().push(); init_db()"
echo Database initialized

REM Start server
echo.
echo =========================================
echo Starting Flask server on http://localhost:5000
echo Default admin login:
echo   Email: admin@sortifyx.com
echo   Password: admin123
echo =========================================
echo.
python app.py

pause
