import openai
import os
from dotenv import load_dotenv
from datetime import datetime

load_dotenv()

openai.api_key = os.getenv('OPENAI_API_KEY')

def generate_smart_ai_response(question, member_info, workouts, health_metrics, sessions):
    """Generate intelligent AI responses using OpenAI GPT-4."""
    
    # Calculate statistics
    total_workouts = len(workouts)
    avg_duration = sum(w['Duration'] or 0 for w in workouts) / len(workouts) if workouts else 0
    total_calories = sum(w['CaloriesBurnt'] or 0 for w in workouts)
    avg_calories = total_calories / total_workouts if total_workouts > 0 else 0
    
    # Get exercise variety
    exercise_types = list(set(w['Exercise'] for w in workouts)) if workouts else []
    
    # Latest health metrics
    latest_health = health_metrics[0] if health_metrics else {}
    current_weight = latest_health.get('Weight', 'N/A')
    current_steps = latest_health.get('Steps', 'N/A')
    current_sleep = latest_health.get('SleepHours', 'N/A')
    current_water = latest_health.get('WaterLiters', 'N/A')
    
    # Weight trend analysis
    weight_trend = "stable"
    weight_change = 0
    if health_metrics and len(health_metrics) >= 2:
        weight_change = health_metrics[0]['Weight'] - health_metrics[-1]['Weight']
        if weight_change < -0.5:
            weight_trend = "decreasing"
        elif weight_change > 0.5:
            weight_trend = "increasing"
    
    # Recent workout summary
    recent_workout_summary = []
    for workout in workouts[:5]:
        recent_workout_summary.append({
            'exercise': workout['Exercise'],
            'date': workout['Date'].strftime('%Y-%m-%d') if workout['Date'] else 'N/A',
            'duration': workout['Duration'],
            'calories': workout['CaloriesBurnt']
        })
    
    # Upcoming sessions summary
    upcoming_session_summary = []
    for session in sessions[:3]:
        upcoming_session_summary.append({
            'details': session['Details'],
            'date': session['SessionDate'].strftime('%Y-%m-%d') if session['SessionDate'] else 'N/A',
            'time': str(session['SessionTime']) if session['SessionTime'] else 'N/A'
        })
    
    # Build context for AI
    context = f"""You are an expert AI fitness coach and personal trainer assistant for GymFit. You have access to the member's complete fitness data and should provide personalized, actionable advice.

**Member Profile:**
- Name: {member_info['Name']}
- Age: {member_info['Age']}
- Membership: {member_info['MembershipType']} (member since {member_info['JoinDate'].strftime('%B %Y')})

**Recent Activity (Last 30 Days):**
- Total workouts: {total_workouts}
- Average workout duration: {avg_duration:.1f} minutes
- Total calories burned: {total_calories:.0f} kcal
- Average calories per workout: {avg_calories:.0f} kcal
- Exercise variety: {', '.join(exercise_types) if exercise_types else 'No recent workouts'}

**Recent Workouts:**
{recent_workout_summary}

**Current Health Metrics:**
- Weight: {current_weight} kg (trend: {weight_trend}, change: {weight_change:.1f} kg)
- Daily steps: {current_steps}
- Sleep hours: {current_sleep}
- Water intake: {current_water} liters

**Upcoming Sessions:**
{upcoming_session_summary if upcoming_session_summary else 'No sessions booked'}

**Instructions:**
1. Provide personalized, specific advice based on the member's actual data
2. Use markdown formatting for better readability (headers, lists, bold, etc.)
3. Be motivating, supportive, and professional
4. Include specific numbers and data points from their history
5. When suggesting workout plans, consider their current activity level
6. Always back your advice with reasoning based on their data
7. Use emojis sparingly for visual appeal
8. Keep responses concise but informative (aim for 150-300 words unless asked for detailed plans)
9. If asked about workout plans, create specific day-by-day schedules
10. Reference their actual workout history when making suggestions

Remember: You're talking to {member_info['Name']}, a real person with real goals. Make your advice actionable and personalized."""

    try:
        response = openai.chat.completions.create(
            model="gpt-4o-mini",  # Using GPT-4o mini for cost efficiency
            messages=[
                {"role": "system", "content": context},
                {"role": "user", "content": question}
            ],
            temperature=0.7,
            max_tokens=800
        )
        
        return response.choices[0].message.content
        
    except Exception as e:
        print(f"OpenAI API Error: {e}")
        # Fallback response
        return f"""I apologize, but I'm having trouble connecting to my AI brain right now. 

**However, here's what I can tell you from your data:**

📊 **Your Stats (Last 30 Days):**
- Workouts: {total_workouts}
- Avg Duration: {avg_duration:.1f} minutes
- Total Calories: {total_calories:.0f} kcal

💪 **Current Metrics:**
- Weight: {current_weight} kg
- Steps: {current_steps}
- Sleep: {current_sleep} hours

Please try your question again, or contact support if the issue persists."""