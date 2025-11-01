import mysql.connector
from mysql.connector import Error
import os
from dotenv import load_dotenv

load_dotenv()

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

def generate_workout_recommendations(member_id):
    """Generate personalized workout recommendations using rule-based logic"""
    conn = get_db_connection()
    if not conn:
        return []
    cursor = conn.cursor(dictionary=True)
    try:
        # Get member's recent performance
        cursor.execute("""
            SELECT Exercise, AVG(CaloriesBurnt) as avg_calories,
                   AVG(Duration) as avg_duration, COUNT(*) as frequency
            FROM WorkoutLog
            WHERE M_ID = %s AND Date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
            GROUP BY Exercise
            ORDER BY frequency DESC
        """, (member_id,))
        workout_patterns = cursor.fetchall()

        # Get current health metrics
        cursor.execute("""
            SELECT Weight, Height, SleepHours, Steps
            FROM HealthMetrics
            WHERE M_ID = %s
            ORDER BY Date DESC LIMIT 1
        """, (member_id,))
        health_data = cursor.fetchone()

        # Get total workouts in last 7 days
        cursor.execute("""
            SELECT COUNT(*) as weekly_workouts
            FROM WorkoutLog
            WHERE M_ID = %s AND Date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
        """, (member_id,))
        weekly_data = cursor.fetchone()

        recommendations = []

        # Rule 1: Step count recommendation
        if health_data and health_data.get('Steps') is not None:
            if health_data['Steps'] < 5000:
                recommendations.append({
                    'type': 'cardio',
                    'message': 'Your step count is below the recommended 10,000 daily steps. Try adding a 30-minute brisk walk.',
                    'exercise': 'Brisk Walking',
                    'duration': 30
                })
            elif health_data['Steps'] < 8000:
                recommendations.append({
                    'type': 'cardio',
                    'message': 'Great progress on steps! Aim for 10,000 steps daily with an additional 20-minute walk.',
                    'exercise': 'Walking',
                    'duration': 20
                })

        # Rule 2: Sleep recommendation
        if health_data and health_data.get('SleepHours') is not None:
            if health_data['SleepHours'] < 6:
                recommendations.append({
                    'type': 'recovery',
                    'message': 'Your sleep is below optimal levels. Consider a light yoga session to improve sleep quality.',
                    'exercise': 'Evening Yoga',
                    'duration': 20
                })

        # Rule 3: Workout frequency recommendation
        if weekly_data:
            weekly_workouts = weekly_data.get('weekly_workouts', 0)
            if weekly_workouts < 3:
                recommendations.append({
                    'type': 'general',
                    'message': 'You\'ve worked out less than 3 times this week. Try adding a 45-minute cardio or strength training session.',
                    'exercise': 'Mixed Cardio & Strength',
                    'duration': 45
                })
            elif weekly_workouts >= 5:
                recommendations.append({
                    'type': 'recovery',
                    'message': 'Excellent workout frequency! Consider a recovery session with stretching or light yoga.',
                    'exercise': 'Recovery Stretching',
                    'duration': 30
                })

        # Rule 4: Exercise variety recommendation
        if workout_patterns:
            unique_exercises = len(workout_patterns)
            if unique_exercises < 2:
                recommendations.append({
                    'type': 'variety',
                    'message': 'Mix up your routine! Try adding strength training or HIIT to complement your current workouts.',
                    'exercise': 'HIIT Training',
                    'duration': 30
                })

        # Rule 5: Calories burned recommendation
        if workout_patterns:
            avg_calories = sum(w['avg_calories'] or 0 for w in workout_patterns) / len(workout_patterns)
            if avg_calories < 200:
                recommendations.append({
                    'type': 'intensity',
                    'message': 'Increase your workout intensity to burn more calories. Try interval training.',
                    'exercise': 'Interval Training',
                    'duration': 40
                })

        # If no recommendations, provide a general one
        if not recommendations:
            recommendations.append({
                'type': 'general',
                'message': 'You\'re doing great! Keep maintaining your current routine and consider progressive overload.',
                'exercise': 'Current Routine',
                'duration': 45
            })

        # Return maximum 3 recommendations
        return recommendations[:3]

    except Error as e:
        print(f"Error generating recommendations: {e}")
        return [{
            'type': 'general',
            'message': 'Stay consistent with your workouts and maintain a balanced routine.',
            'exercise': 'General Fitness',
            'duration': 30
        }]
    finally:
        cursor.close()
        conn.close()