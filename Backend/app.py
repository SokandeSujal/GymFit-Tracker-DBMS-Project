from flask import Flask, render_template, request, jsonify, session
from flask_cors import CORS
import mysql.connector
from mysql.connector import Error
from datetime import datetime, timedelta
from functools import wraps
import os
from werkzeug.security import generate_password_hash, check_password_hash
from dotenv import load_dotenv
from recommendations import generate_workout_recommendations
from notifications import check_membership_renewals
from ai_chatbot import generate_smart_ai_response

load_dotenv()

app = Flask(__name__)

# In production, this should be a secure, randomly generated key managed as an environment variable.
app.secret_key = os.getenv('SECRET_KEY', 'dev-secret-key-for-gymfit-tracker')

# Configure session to work with CORS
app.config['SESSION_COOKIE_SAMESITE'] = 'Lax'
app.config['SESSION_COOKIE_SECURE'] = False  # Set to True in production with HTTPS
app.config['SESSION_COOKIE_HTTPONLY'] = True
app.config['PERMANENT_SESSION_LIFETIME'] = timedelta(hours=24)
app.config['SESSION_TYPE'] = 'filesystem'  # Add this line

# CORS configuration - allow credentials
CORS(app, supports_credentials=True, origins=['http://localhost:5000', 'http://127.0.0.1:5000'])

# --- Database Configuration ---
# It is recommended to use environment variables for database credentials in production.
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'user': os.getenv('DB_USER', 'root'),
    'password': os.getenv('DB_PASSWORD', ''),
    'database': os.getenv('DB_NAME', 'GymFitDB')
}

def get_db_connection():
    """Create and return a new database connection."""
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        return conn
    except Error as e:
        print(f"Error connecting to MySQL: {e}")
        return None

# --- Utilities & Decorators ---

def json_serial(obj):
    """JSON serializer for objects not serializable by default json code"""
    if isinstance(obj, (datetime, datetime.date)):
        return obj.isoformat()
    if isinstance(obj, timedelta):
        return str(obj)
    raise TypeError(f"Type {type(obj)} not serializable")

def login_required(f):
    """Decorator to ensure a user is logged in."""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            print(f"Session data: {dict(session)}")  # Debug logging
            return jsonify({'error': 'Authentication required. Please log in.'}), 401
        return f(*args, **kwargs)
    return decorated_function

def role_required(required_role):
    """Decorator to ensure a user has the specified role."""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if 'user_role' not in session or session['user_role'] != required_role:
                return jsonify({'error': 'Insufficient permissions for this action.'}), 403
            return f(*args, **kwargs)
        return decorated_function
    return decorator

# --- Main Routes ---

@app.route('/')
def index():
    """Serve the main page."""
    return render_template('index.html')

@app.route('/api/login', methods=['POST'])
def login():
    """Handle user login for all roles."""
    data = request.json
    email = data.get('email')
    password = data.get('password')
    role = data.get('role')

    if not all([email, password, role]):
        return jsonify({'error': 'Email, password, and role are required.'}), 400

    conn = get_db_connection()
    if not conn:
        return jsonify({'error': 'Database connection failed.'}), 500
    
    cursor = conn.cursor(dictionary=True)
    
    try:
        table_map = {
            'member': ('Member', 'M_ID'),
            'trainer': ('Trainer', 'T_ID'),
            'admin': ('Admin', 'A_ID')
        }
        
        if role not in table_map:
            return jsonify({'error': 'Invalid role specified.'}), 400

        table_name, id_column = table_map[role]
        
        # Passwords are now hashed.
        query = f"SELECT {id_column} as user_id, Name, Email, Password FROM {table_name} WHERE Email = %s"
        cursor.execute(query, (email,))
        user_data = cursor.fetchone()

        if user_data and check_password_hash(user_data['Password'], password):
            # Clear any existing session data first
            session.clear()
            
            # Set session data
            session['user_id'] = user_data['user_id']
            session['user_name'] = user_data['Name']
            session['user_role'] = role
            session.permanent = True  # Make session permanent
            
            # Force session to be saved
            session.modified = True
            
            response = jsonify({
                'success': True,
                'user_id': user_data['user_id'],
                'name': user_data['Name'],
                'role': role
            })
            
            return response
        else:
            return jsonify({'error': 'Invalid credentials or role.'}), 401
            
    except Error as e:
        return jsonify({'error': f'Database query failed: {e}'}), 500
    finally:
        cursor.close()
        conn.close()

@app.route('/api/logout', methods=['POST'])
def logout():
    """Handle user logout."""
    session.clear()
    return jsonify({'success': True, 'message': 'You have been logged out.'})

# --- Member Dashboard ---
@app.route('/api/dashboard/member/<int:member_id>', methods=['GET'])
@login_required
@role_required('member')
def get_member_dashboard(member_id):
    """Get member dashboard data."""
    if session['user_id'] != member_id:
        return jsonify({'error': 'You are not authorized to access this resource.'}), 403

    conn = get_db_connection()
    if not conn:
        return jsonify({'error': 'Database connection failed'}), 500
    
    cursor = conn.cursor(dictionary=True)
    
    try:
        # Get member info
        cursor.execute("""
            SELECT m.M_ID, m.Name, m.Email, m.Age, m.JoinDate, mt.Name AS MembershipType, g.Location AS GymLocation
            FROM Member m
            LEFT JOIN MembershipType mt ON m.MembershipType_ID = mt.Type_ID
            LEFT JOIN Gym g ON m.Gym_ID = g.Gym_ID
            WHERE m.M_ID = %s
        """, (member_id,))
        member_info = cursor.fetchone()
        
        # Get today's workout stats
        cursor.execute("""
            SELECT 
                COALESCE(SUM(CaloriesBurnt), 0) AS TodayCalories,
                COALESCE(SUM(Distance), 0) AS TodayDistance,
                COUNT(*) AS TodayWorkouts
            FROM WorkoutLog
            WHERE M_ID = %s AND Date = CURDATE()
        """, (member_id,))
        today_stats = cursor.fetchone()
        
        # Get latest health metrics for today
        cursor.execute("""
            SELECT Weight, Height, SleepHours, WaterLiters, Steps 
            FROM HealthMetrics
            WHERE M_ID = %s AND Date = CURDATE()
            ORDER BY Metric_ID DESC LIMIT 1
        """, (member_id,))
        health_metrics = cursor.fetchone()
        
        # Get recent workout logs
        cursor.execute("""
            SELECT wl.L_ID, wl.Exercise, wl.Date, wl.Duration, wl.CaloriesBurnt, s.Details AS SessionDetails
            FROM WorkoutLog wl
            LEFT JOIN Session s ON wl.S_ID = s.S_ID
            WHERE wl.M_ID = %s
            ORDER BY wl.Date DESC, wl.L_ID DESC
            LIMIT 5
        """, (member_id,))
        recent_workouts = cursor.fetchall()
        
        # Get upcoming booked sessions
        cursor.execute("""
            SELECT s.S_ID, s.Details, s.SessionDate, s.SessionTime, t.Name AS TrainerName, wl.L_ID as BookingID
            FROM WorkoutLog wl
            JOIN Session s ON wl.S_ID = s.S_ID
            JOIN Trainer t ON s.T_ID = t.T_ID
            WHERE wl.M_ID = %s AND s.SessionDate >= CURDATE() AND wl.Exercise = 'Session Booking'
            ORDER BY s.SessionDate, s.SessionTime
            LIMIT 5
        """, (member_id,))
        upcoming_sessions = cursor.fetchall()
        
        return jsonify({
            'member': member_info,
            'todayStats': today_stats,
            'healthMetrics': health_metrics,
            'recentWorkouts': [dict(row) for row in recent_workouts],
            'upcomingSessions': [dict(row) for row in upcoming_sessions]
        })
        
    except Error as e:
        return jsonify({'error': str(e)}), 500
    finally:
        cursor.close()
        conn.close()

@app.route('/api/member/<int:member_id>/progress', methods=['GET'])
@login_required
@role_required('member')
def get_member_progress(member_id):
    """Get comprehensive progress data for charts"""
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        # Weekly workout frequency
        cursor.execute("""
            SELECT Date, COUNT(*) as workout_count
            FROM WorkoutLog
            WHERE M_ID = %s AND Date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
            GROUP BY Date
            ORDER BY Date
        """, (member_id,))
        workout_frequency = cursor.fetchall()

        # Weight progress
        cursor.execute("""
            SELECT Date, Weight
            FROM HealthMetrics
            WHERE M_ID = %s AND Weight IS NOT NULL
            ORDER BY Date
        """, (member_id,))
        weight_progress = cursor.fetchall()

        # Calories burned trend
        cursor.execute("""
            SELECT Date, SUM(CaloriesBurnt) as daily_calories
            FROM WorkoutLog
            WHERE M_ID = %s AND CaloriesBurnt IS NOT NULL
            GROUP BY Date
            ORDER BY Date
        """, (member_id,))
        calorie_trend = cursor.fetchall()

        return jsonify({
            'workoutFrequency': [dict(row) for row in workout_frequency],
            'weightProgress': [dict(row) for row in weight_progress],
            'calorieTrend': [dict(row) for row in calorie_trend]
        })
    except Error as e:
        return jsonify({'error': str(e)}), 500
    finally:
        cursor.close()
        conn.close()

@app.route('/api/member/<int:member_id>/recommendations', methods=['GET'])
@login_required
@role_required('member')
def get_recommendations(member_id):
    """Get personalized workout recommendations"""
    if session['user_id'] != member_id:
        return jsonify({'error': 'You are not authorized to access this resource.'}), 403
    
    recommendations = generate_workout_recommendations(member_id)
    return jsonify({'recommendations': recommendations})

@app.route('/api/admin/member', methods=['POST'])
@login_required
@role_required('admin')
def add_member():
    """Admin action to add a new member."""
    data = request.json
    
    required_fields = ['name', 'email', 'password', 'age', 'membership_type_id', 'gym_id']
    if not all(field in data for field in required_fields):
        return jsonify({'error': 'Missing required fields'}), 400
    
    conn = get_db_connection()
    if not conn:
        return jsonify({'error': 'Database connection failed'}), 500
    
    cursor = conn.cursor()
    try:
        # Hash the password
        hashed_password = generate_password_hash(data['password'])
        join_date = datetime.now().strftime('%Y-%m-%d')
        
        cursor.execute("""
            INSERT INTO Member (Name, Email, Password, Age, JoinDate, Phone, MembershipType_ID, Gym_ID, IsActive)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, TRUE)
        """, (
            data['name'], data['email'], hashed_password, data['age'],
            join_date, data.get('phone', ''), data['membership_type_id'], data['gym_id']
        ))
        
        conn.commit()
        return jsonify({'success': True, 'member_id': cursor.lastrowid, 'message': 'Member added successfully.'})
    except Error as e:
        conn.rollback()
        if 'Duplicate entry' in str(e):
            return jsonify({'error': 'Email already exists'}), 400
        return jsonify({'error': str(e)}), 500
    finally:
        cursor.close()
        conn.close()

@app.route('/api/admin/trainer', methods=['POST'])
@login_required
@role_required('admin')
def add_trainer():
    """Admin action to add a new trainer."""
    data = request.json
    
    required_fields = ['name', 'email', 'password', 'specialization', 'gym_id']
    if not all(field in data for field in required_fields):
        return jsonify({'error': 'Missing required fields'}), 400
    
    conn = get_db_connection()
    if not conn:
        return jsonify({'error': 'Database connection failed'}), 500
    
    cursor = conn.cursor()
    try:
        # Hash the password
        hashed_password = generate_password_hash(data['password'])
        
        cursor.execute("""
            INSERT INTO Trainer (Name, Email, Password, Specialization, Gym_ID)
            VALUES (%s, %s, %s, %s, %s)
        """, (data['name'], data['email'], hashed_password, data['specialization'], data['gym_id']))
        
        conn.commit()
        return jsonify({'success': True, 'trainer_id': cursor.lastrowid, 'message': 'Trainer added successfully.'})
    except Error as e:
        conn.rollback()
        if 'Duplicate entry' in str(e):
            return jsonify({'error': 'Email already exists'}), 400
        return jsonify({'error': str(e)}), 500
    finally:
        cursor.close()
        conn.close()

# Replace the chat endpoint
@app.route('/api/member/<int:member_id>/chat', methods=['POST'])
@login_required
@role_required('member')
def chat_with_ai(member_id):
    """AI chatbot for Gold members only."""
    if session['user_id'] != member_id:
        return jsonify({'error': 'You are not authorized to access this resource.'}), 403
    
    conn = get_db_connection()
    if not conn:
        return jsonify({'error': 'Database connection failed'}), 500
    
    cursor = conn.cursor(dictionary=True)
    
    try:
        # Check if member has Gold membership
        cursor.execute("""
            SELECT mt.Name as MembershipType
            FROM Member m
            JOIN MembershipType mt ON m.MembershipType_ID = mt.Type_ID
            WHERE m.M_ID = %s
        """, (member_id,))
        
        member_data = cursor.fetchone()
        
        if not member_data or member_data['MembershipType'] != 'Gold':
            return jsonify({'error': 'AI Chatbot is only available for Gold members. Please upgrade your membership to access this feature.'}), 403
        
        # Get user question
        question = request.json.get('question', '').strip()
        
        if not question:
            return jsonify({'error': 'Please provide a question'}), 400
        
        # Get comprehensive member data for context
        cursor.execute("""
            SELECT m.M_ID, m.Name, m.Age, m.JoinDate, mt.Name as MembershipType
            FROM Member m
            JOIN MembershipType mt ON m.MembershipType_ID = mt.Type_ID
            WHERE m.M_ID = %s
        """, (member_id,))
        member_info = cursor.fetchone()
        
        # Get recent workouts (last 30 days)
        cursor.execute("""
            SELECT Exercise, Date, Duration, CaloriesBurnt, Distance
            FROM WorkoutLog
            WHERE M_ID = %s AND Date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
            ORDER BY Date DESC
        """, (member_id,))
        recent_workouts = cursor.fetchall()
        
        # Get latest health metrics (last 5 entries)
        cursor.execute("""
            SELECT Weight, Height, SleepHours, WaterLiters, Steps, Date
            FROM HealthMetrics
            WHERE M_ID = %s
            ORDER BY Date DESC LIMIT 5
        """, (member_id,))
        health_metrics = cursor.fetchall()
        
        # Get upcoming sessions
        cursor.execute("""
            SELECT s.Details, s.SessionDate, s.SessionTime
            FROM WorkoutLog wl
            JOIN Session s ON wl.S_ID = s.S_ID
            WHERE wl.M_ID = %s AND s.SessionDate >= CURDATE() AND wl.Exercise = 'Session Booking'
            ORDER BY s.SessionDate
            LIMIT 5
        """, (member_id,))
        upcoming_sessions = cursor.fetchall()
        
        # Generate AI response using OpenAI
        response = generate_smart_ai_response(question, member_info, recent_workouts, health_metrics, upcoming_sessions)
        
        return jsonify({'success': True, 'response': response, 'isMarkdown': True})
        
    except Exception as e:
        print(f"Chat error: {e}")
        return jsonify({'error': 'An error occurred while processing your request. Please try again.'}), 500
    finally:
        cursor.close()
        conn.close()

def generate_ai_response(question, member_info, workouts, health_metrics, sessions):
    """Generate rule-based AI responses based on member data."""
    
    # Calculate statistics
    total_workouts = len(workouts)
    avg_duration = sum(w['Duration'] or 0 for w in workouts) / len(workouts) if workouts else 0
    total_calories = sum(w['CaloriesBurnt'] or 0 for w in workouts)
    
    latest_health = health_metrics[0] if health_metrics else {}
    current_weight = latest_health.get('Weight', 'N/A')
    current_steps = latest_health.get('Steps', 'N/A')
    current_sleep = latest_health.get('SleepHours', 'N/A')
    
    # Question matching and responses
    if any(word in question for word in ['progress', 'doing', 'performance', 'improvement']):
        return f"""Based on your last 30 days of activity:
        
📊 **Workout Summary:**
- Total workouts: {total_workouts}
- Average duration: {avg_duration:.1f} minutes
- Total calories burned: {total_calories:.0f} kcal

💪 **Health Metrics:**
- Current weight: {current_weight} kg
- Daily steps: {current_steps}
- Sleep hours: {current_sleep}

{'You are doing great! Keep up the consistent effort.' if total_workouts >= 12 else 'Try to increase your workout frequency to at least 3-4 times per week for better results.'}"""

    elif any(word in question for word in ['weight', 'lose', 'gain', 'body']):
        if health_metrics and len(health_metrics) >= 2:
            weight_change = health_metrics[0]['Weight'] - health_metrics[-1]['Weight']
            trend = "lost" if weight_change < 0 else "gained"
            return f"""**Weight Analysis:**

Current weight: {current_weight} kg
Weight change: {abs(weight_change):.1f} kg {trend}

**Recommendations:**
- {'Great job on your weight loss! Maintain your current routine.' if weight_change < 0 else 'Focus on calorie deficit and cardio exercises for weight loss.'}
- Aim for 150 minutes of moderate cardio per week
- Stay hydrated with at least 3 liters of water daily
- Get 7-8 hours of quality sleep"""
        else:
            return "I need more health metric data to analyze your weight progress. Please log your weight regularly!"

    elif any(word in question for word in ['workout', 'exercise', 'train', 'routine']):
        exercise_types = set(w['Exercise'] for w in workouts)
        return f"""**Your Workout Pattern:**

Recent exercises: {', '.join(exercise_types) if exercise_types else 'No recent workouts'}

**Recommendations:**
- Mix cardio (running, cycling) with strength training (weights, resistance)
- Try HIIT workouts for better calorie burn
- Include flexibility exercises like yoga
- Rest days are important - don't overtrain!

{'Consider adding more variety to your routine for balanced fitness.' if len(exercise_types) < 3 else 'Great exercise variety!'}"""

    elif any(word in question for word in ['session', 'class', 'trainer', 'book']):
        if sessions:
            session_list = '\n'.join([f"- {s['Details']} on {s['SessionDate'].strftime('%B %d, %Y')}" for s in sessions[:3]])
            return f"""**Your Upcoming Sessions:**

{session_list}

These sessions will help you stay motivated and learn proper techniques. Make sure to attend regularly!"""
        else:
            return """You don't have any upcoming sessions booked.

**Why book a session?**
- Get personalized guidance from expert trainers
- Learn proper form and technique
- Stay motivated with group classes
- Access specialized training programs

Use the "Book Session" button to schedule one!"""

    elif any(word in question for word in ['sleep', 'rest', 'recovery']):
        return f"""**Sleep & Recovery Analysis:**

Current sleep: {current_sleep} hours/night

**Recommendations:**
- Aim for 7-9 hours of sleep for optimal recovery
- {'Excellent! Your sleep is on track.' if isinstance(current_sleep, int) and current_sleep >= 7 else 'Try to improve sleep quality - it is crucial for muscle recovery.'}
- Avoid screens 1 hour before bed
- Consider yoga or stretching before bedtime
- Rest days are as important as workout days"""

    elif any(word in question for word in ['calorie', 'burn', 'diet', 'nutrition']):
        return f"""**Calorie & Nutrition Insights:**

Total calories burned (30 days): {total_calories:.0f} kcal
Average per workout: {total_calories/total_workouts:.0f} kcal

**Nutrition Tips:**
- Maintain a balanced diet with adequate protein
- Stay hydrated: {latest_health.get('WaterLiters', 0)} liters logged today
- Eat complex carbs before workouts
- Post-workout protein helps muscle recovery
- Consider consulting our nutrition experts for personalized diet plans"""

    elif any(word in question for word in ['goal', 'target', 'aim', 'plan']):
        return f"""**Setting Goals Based on Your Data:**

Current status: {total_workouts} workouts in 30 days

**Recommended Goals:**
1. **Short-term (1 month):**
   - Workout 4-5 times per week
   - Burn 2000+ calories per week
   - Increase workout duration by 10%

2. **Medium-term (3 months):**
   - Master 5 different exercises
   - Improve strength by 20%
   - Achieve target weight (discuss with trainer)

3. **Long-term (6+ months):**
   - Complete fitness transformation
   - Build sustainable healthy habits
   - Participate in fitness events

Track your progress regularly to stay motivated!"""

    elif any(word in question for word in ['membership', 'renew', 'upgrade', 'plan']):
        return f"""**Your Membership:**

Type: {member_info['MembershipType']}
Member since: {member_info['JoinDate'].strftime('%B %Y')}

**Gold Membership Benefits:**
✅ Unlimited gym access
✅ All group classes included
✅ AI Chatbot assistance (you're using it now!)
✅ Priority session booking
✅ Personalized workout plans

Keep enjoying your premium benefits!"""

    else:
        return f"""Hello {member_info['Name']}! I'm your AI fitness assistant.

**I can help you with:**
- 📊 Progress tracking and performance analysis
- 🏋️ Workout and exercise recommendations
- ⚖️ Weight and body composition insights
- 📅 Session scheduling and reminders
- 💤 Sleep and recovery guidance
- 🔥 Calorie and nutrition tips
- 🎯 Goal setting and planning

**Quick stats:**
- Workouts (30 days): {total_workouts}
- Current weight: {current_weight} kg
- Average workout: {avg_duration:.1f} minutes

Ask me anything about your fitness journey!"""

# --- Notifications ---

@app.route('/api/notifications', methods=['GET'])
@login_required
def get_notifications():
    """Get user notifications"""
    user_id = session['user_id']
    user_role = session['user_role']

    conn = get_db_connection()
    if not conn:
        return jsonify({'error': 'Database connection failed'}), 500
    
    cursor = conn.cursor(dictionary=True)
    
    try:
        if user_role == 'member':
            cursor.execute("""
                SELECT * FROM Notifications
                WHERE M_ID = %s
                ORDER BY CreatedAt DESC
                LIMIT 10
            """, (user_id,))
        else:
            # Admin/Trainer notifications logic (not specified in the plan)
            # For now, return an empty list for other roles
            return jsonify({'notifications': []})

        notifications = cursor.fetchall()
        # Convert datetime objects to string
        for notification in notifications:
            notification['CreatedAt'] = notification['CreatedAt'].isoformat()

        return jsonify({'notifications': notifications})
    except Error as e:
        return jsonify({'error': str(e)}), 500
    finally:
        cursor.close()
        conn.close()

@app.route('/api/admin/check_renewals', methods=['POST'])
@login_required
@role_required('admin')
def run_check_renewals():
    """Manually trigger the membership renewal check."""
    try:
        check_membership_renewals()
        return jsonify({'success': True, 'message': 'Membership renewal check completed.'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# --- Trainer Dashboard ---
@app.route('/api/dashboard/trainer/<int:trainer_id>', methods=['GET'])
@login_required
@role_required('trainer')
def get_trainer_dashboard(trainer_id):
    """Get trainer dashboard data."""
    if session['user_id'] != trainer_id:
        return jsonify({'error': 'You are not authorized to access this resource.'}), 403
        
    conn = get_db_connection()
    if not conn:
        return jsonify({'error': 'Database connection failed'}), 500
    
    cursor = conn.cursor(dictionary=True)
    
    try:
        cursor.execute("SELECT T_ID, Name, Email, Specialization FROM Trainer WHERE T_ID = %s", (trainer_id,))
        trainer_info = cursor.fetchone()
        
        cursor.execute("""
            SELECT 
                COUNT(DISTINCT wl.M_ID) as totalClients
            FROM Session s
            JOIN WorkoutLog wl ON s.S_ID = wl.S_ID
            WHERE s.T_ID = %s
        """, (trainer_id,))
        total_clients = cursor.fetchone()

        cursor.execute("""
            SELECT COUNT(*) as sessionsToday FROM Session s
            WHERE s.T_ID = %s AND s.SessionDate = CURDATE()
        """, (trainer_id,))
        sessions_today = cursor.fetchone()
        
        stats = {
            'totalClients': total_clients.get('totalClients', 0),
            'sessionsToday': sessions_today.get('sessionsToday', 0)
        }
        
        cursor.execute("""
            SELECT s.*, 
                   (SELECT COUNT(*) FROM WorkoutLog wl WHERE wl.S_ID = s.S_ID AND wl.Exercise = 'Session Booking') as participantCount
            FROM Session s
            WHERE s.T_ID = %s AND s.SessionDate >= CURDATE()
            ORDER BY s.SessionDate, s.SessionTime
        """, (trainer_id,))
        sessions = cursor.fetchall()
        
        cursor.execute("""
            SELECT DISTINCT m.M_ID, m.Name, m.Email, 
                   (SELECT MAX(Date) FROM WorkoutLog wl WHERE wl.M_ID = m.M_ID) as lastWorkout
            FROM Member m
            JOIN WorkoutLog wl ON m.M_ID = wl.M_ID
            JOIN Session s ON wl.S_ID = s.S_ID
            WHERE s.T_ID = %s
            ORDER BY m.Name
        """, (trainer_id,))
        clients = cursor.fetchall()
        
        return jsonify({
            'trainer': trainer_info,
            'stats': stats,
            'sessions': [dict(row) for row in sessions],
            'clients': [dict(row) for row in clients]
        })
        
    except Error as e:
        return jsonify({'error': str(e)}), 500
    finally:
        cursor.close()
        conn.close()

# --- Admin Dashboard & Actions ---
@app.route('/api/dashboard/admin/<int:admin_id>', methods=['GET'])
@login_required
@role_required('admin')
def get_admin_dashboard(admin_id):
    """Get admin dashboard data."""
    if session['user_id'] != admin_id:
        return jsonify({'error': 'You are not authorized to access this resource.'}), 403

    conn = get_db_connection()
    if not conn:
        return jsonify({'error': 'Database connection failed'}), 500
    
    cursor = conn.cursor(dictionary=True)
    
    try:
        cursor.execute("SELECT (SELECT COUNT(*) FROM Member) as totalMembers")
        total_members = cursor.fetchone()
        cursor.execute("SELECT (SELECT COUNT(*) FROM Trainer) as totalTrainers")
        total_trainers = cursor.fetchone()
        cursor.execute("SELECT (SELECT COUNT(*) FROM Session WHERE SessionDate >= CURDATE()) as activeSessions")
        active_sessions = cursor.fetchone()
        cursor.execute("""
            SELECT COALESCE(SUM(mt.Price), 0) as totalRevenue
            FROM Member m
            JOIN MembershipType mt ON m.MembershipType_ID = mt.Type_ID
        """)
        total_revenue = cursor.fetchone()

        stats = {**total_members, **total_trainers, **active_sessions, **total_revenue}
        
        cursor.execute("""
            SELECT m.M_ID, m.Name, m.Email, m.JoinDate, mt.Name as MembershipType, g.Location as GymLocation
            FROM Member m
            LEFT JOIN MembershipType mt ON m.MembershipType_ID = mt.Type_ID
            LEFT JOIN Gym g ON m.Gym_ID = g.Gym_ID
            ORDER BY m.JoinDate DESC
        """)
        members = cursor.fetchall()
        
        cursor.execute("""
            SELECT t.T_ID, t.Name, t.Email, t.Specialization, g.Location as GymLocation,
                   (SELECT COUNT(DISTINCT wl.M_ID) 
                    FROM Session s 
                    JOIN WorkoutLog wl ON s.S_ID = wl.S_ID 
                    WHERE s.T_ID = t.T_ID) as clientCount
            FROM Trainer t
            LEFT JOIN Gym g ON t.Gym_ID = g.Gym_ID
            ORDER BY t.Name
        """)
        trainers = cursor.fetchall()
        
        return jsonify({
            'stats': stats,
            'members': [dict(row) for row in members],
            'trainers': [dict(row) for row in trainers]
        })
        
    except Error as e:
        return jsonify({'error': str(e)}), 500
    finally:
        cursor.close()
        conn.close()

@app.route('/api/admin/member/<int:member_id>', methods=['DELETE'])
@login_required
@role_required('admin')
def delete_member(member_id):
    """Admin action to delete a member."""
    conn = get_db_connection()
    if not conn: return jsonify({'error': 'Database connection failed'}), 500
    cursor = conn.cursor()
    try:
        cursor.execute("DELETE FROM Member WHERE M_ID = %s", (member_id,))
        conn.commit()
        if cursor.rowcount == 0:
            return jsonify({'error': 'Member not found'}), 404
        return jsonify({'success': True, 'message': 'Member deleted successfully.'})
    except Error as e:
        conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        cursor.close()
        conn.close()

@app.route('/api/admin/trainer/<int:trainer_id_to_delete>', methods=['DELETE'])
@login_required
@role_required('admin')
def delete_trainer(trainer_id_to_delete):
    """Admin action to delete a trainer."""
    conn = get_db_connection()
    if not conn: return jsonify({'error': 'Database connection failed'}), 500
    cursor = conn.cursor()
    try:
        cursor.execute("DELETE FROM Trainer WHERE T_ID = %s", (trainer_id_to_delete,))
        conn.commit()
        if cursor.rowcount == 0:
            return jsonify({'error': 'Trainer not found'}), 404
        return jsonify({'success': True, 'message': 'Trainer deleted successfully.'})
    except Error as e:
        conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        cursor.close()
        conn.close()

# --- Workout & Session Management ---

@app.route('/api/workouts', methods=['POST'])
@login_required
@role_required('member')
def add_workout():
    """Add a new workout log for the logged-in member."""
    member_id = session['user_id']
    data = request.json
    if not all(field in data for field in ['exercise', 'date', 'duration']):
        return jsonify({'error': 'Missing required fields: exercise, date, duration.'}), 400
    
    conn = get_db_connection()
    if not conn: return jsonify({'error': 'Database connection failed'}), 500
    cursor = conn.cursor()
    try:
        cursor.execute("""
            INSERT INTO WorkoutLog (M_ID, Exercise, Date, Duration, CaloriesBurnt, Distance, Progress)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """, (
            member_id, data['exercise'], data['date'], data['duration'],
            data.get('calories'), data.get('distance'), data.get('progress')
        ))
        conn.commit()
        return jsonify({'success': True, 'workout_id': cursor.lastrowid})
    except Error as e:
        conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        cursor.close()
        conn.close()

@app.route('/api/sessions/available', methods=['GET'])
@login_required
def get_available_sessions():
    """Get available sessions for booking."""
    conn = get_db_connection()
    if not conn: return jsonify({'error': 'Database connection failed'}), 500
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("""
            SELECT s.*, t.Name AS TrainerName, t.Specialization,
                   (SELECT COUNT(*) FROM WorkoutLog wl WHERE wl.S_ID = s.S_ID AND wl.Exercise = 'Session Booking') as participantCount
            FROM Session s
            JOIN Trainer t ON s.T_ID = t.T_ID
            WHERE s.SessionDate >= CURDATE() 
            AND (SELECT COUNT(*) FROM WorkoutLog wl WHERE wl.S_ID = s.S_ID AND wl.Exercise = 'Session Booking') < s.MaxParticipants
            ORDER BY s.SessionDate, s.SessionTime
        """)
        sessions = cursor.fetchall()
        return jsonify({'sessions': [dict(row) for row in sessions]})
    except Error as e:
        return jsonify({'error': str(e)}), 500
    finally:
        cursor.close()
        conn.close()

@app.route('/api/sessions/book', methods=['POST'])
@login_required
@role_required('member')
def book_session():
    """Book a session for the logged-in member."""
    member_id = session['user_id']
    session_id = request.json.get('session_id')
    if not session_id: return jsonify({'error': 'Session ID required'}), 400
    
    conn = get_db_connection()
    if not conn: return jsonify({'error': 'Database connection failed'}), 500
    cursor = conn.cursor(dictionary=True)
    try:
        # Check if session exists, is not full, and get its details
        cursor.execute("""
            SELECT Details, SessionDate, Duration, MaxParticipants,
                   (SELECT COUNT(*) FROM WorkoutLog WHERE S_ID = %s AND Exercise = 'Session Booking') as currentParticipants
            FROM Session WHERE S_ID = %s
        """, (session_id, session_id))
        session_info = cursor.fetchone()

        if not session_info:
            return jsonify({'error': 'Session not found'}), 404
        if session_info['currentParticipants'] >= session_info['MaxParticipants']:
            return jsonify({'error': 'Session is full'}), 400
        
        # Check if already booked
        cursor.execute("SELECT L_ID FROM WorkoutLog WHERE M_ID = %s AND S_ID = %s AND Exercise = 'Session Booking'", (member_id, session_id))
        if cursor.fetchone():
            return jsonify({'error': 'You have already booked this session'}), 400

        # Book the session by creating a workout log entry
        cursor.execute("""
            INSERT INTO WorkoutLog (M_ID, S_ID, Exercise, Date, Duration, Progress)
            VALUES (%s, %s, %s, %s, %s, %s)
        """, (member_id, session_id, 'Session Booking', session_info['SessionDate'], session_info['Duration'], 'Booked'))
        
        conn.commit()
        return jsonify({'success': True, 'message': 'Session booked successfully.'})
    except Error as e:
        conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        cursor.close()
        conn.close()

@app.route('/api/sessions/cancel', methods=['POST'])
@login_required
@role_required('member')
def cancel_session():
    """Cancel a session booking for the logged-in member."""
    member_id = session['user_id']
    booking_id = request.json.get('booking_id') # This is the L_ID from WorkoutLog
    if not booking_id: return jsonify({'error': 'Booking ID required'}), 400

    conn = get_db_connection()
    if not conn: return jsonify({'error': 'Database connection failed'}), 500
    cursor = conn.cursor()
    try:
        # Ensure the user is canceling their own booking
        cursor.execute("DELETE FROM WorkoutLog WHERE L_ID = %s AND M_ID = %s AND Exercise = 'Session Booking'", (booking_id, member_id))
        conn.commit()
        if cursor.rowcount == 0:
            return jsonify({'error': 'Booking not found or you do not have permission to cancel it'}), 404
        return jsonify({'success': True, 'message': 'Session booking canceled.'})
    except Error as e:
        conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        cursor.close()
        conn.close()

# --- Error Handlers ---
@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Not Found'}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Internal Server Error'}), 500

# --- Main Execution ---
if __name__ == '__main__':
    app.run(debug=True, port=5000, host='0.0.0.0')
