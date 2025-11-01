import mysql.connector
from mysql.connector import Error
import os
from dotenv import load_dotenv
from datetime import datetime, timedelta

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

def check_membership_renewals():
    """Check for upcoming membership renewals and create notifications."""
    conn = get_db_connection()
    if not conn:
        print("Failed to connect to database")
        return
    
    cursor = conn.cursor(dictionary=True)
    
    try:
        # Find members whose membership ends in the next 7 days
        cursor.execute("""
            SELECT m.M_ID, m.Name, m.MembershipEndDate, mt.Name as MembershipType
            FROM Member m
            JOIN MembershipType mt ON m.MembershipType_ID = mt.Type_ID
            WHERE m.IsActive = TRUE
            AND m.MembershipEndDate IS NOT NULL
            AND m.MembershipEndDate BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 7 DAY)
        """)
        
        expiring_members = cursor.fetchall()
        
        notifications_created = 0
        for member in expiring_members:
            days_left = (member['MembershipEndDate'] - datetime.now().date()).days
            
            # Check if notification already exists for this member
            cursor.execute("""
                SELECT Notif_ID FROM Notifications
                WHERE M_ID = %s 
                AND Type = 'renewal'
                AND CreatedAt >= DATE_SUB(NOW(), INTERVAL 7 DAY)
            """, (member['M_ID'],))
            
            existing = cursor.fetchone()
            
            if not existing:
                message = f"Your {member['MembershipType']} membership expires in {days_left} day(s) on {member['MembershipEndDate'].strftime('%B %d, %Y')}. Please renew to continue enjoying our services."
                
                cursor.execute("""
                    INSERT INTO Notifications (M_ID, Message, Type, IsRead)
                    VALUES (%s, %s, 'renewal', FALSE)
                """, (member['M_ID'], message))
                
                notifications_created += 1
        
        conn.commit()
        print(f"Membership renewal check completed. {notifications_created} notification(s) created.")
        
    except Error as e:
        print(f"Error checking membership renewals: {e}")
        conn.rollback()
    finally:
        cursor.close()
        conn.close()

def create_session_reminder(member_id, session_id, session_details, session_date, session_time):
    """Create a reminder notification for an upcoming session."""
    conn = get_db_connection()
    if not conn:
        return False
    
    cursor = conn.cursor()
    
    try:
        message = f"Reminder: You have a session '{session_details}' scheduled for {session_date} at {session_time}."
        
        cursor.execute("""
            INSERT INTO Notifications (M_ID, Message, Type, IsRead)
            VALUES (%s, %s, 'session_reminder', FALSE)
        """, (member_id, message))
        
        conn.commit()
        return True
        
    except Error as e:
        print(f"Error creating session reminder: {e}")
        conn.rollback()
        return False
    finally:
        cursor.close()
        conn.close()

def create_progress_notification(member_id, message):
    """Create a progress milestone notification."""
    conn = get_db_connection()
    if not conn:
        return False
    
    cursor = conn.cursor()
    
    try:
        cursor.execute("""
            INSERT INTO Notifications (M_ID, Message, Type, IsRead)
            VALUES (%s, %s, 'progress', FALSE)
        """, (member_id, message))
        
        conn.commit()
        return True
        
    except Error as e:
        print(f"Error creating progress notification: {e}")
        conn.rollback()
        return False
    finally:
        cursor.close()
        conn.close()

if __name__ == "__main__":
    # Test the function
    check_membership_renewals()