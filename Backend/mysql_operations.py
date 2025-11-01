import mysql.connector
from mysql.connector import Error
from datetime import datetime

# MySQL configuration
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': '729654',
    'database': 'GymFitDB'
}

# Connect to MySQL
def get_db_connection():
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        if conn.is_connected():
            print("✅ Successfully connected to the database")
            return conn
    except Error as e:
        print("❌ Error connecting to database:", e)
    return None

# Save a new member (no Role field)
def save_member(name, age, email, password, phone, membership_type_id, gym_id):
    conn = get_db_connection()
    if not conn:
        return
    try:
        cursor = conn.cursor()
        join_date = datetime.now().strftime('%Y-%m-%d')

        cursor.execute("""
            INSERT INTO Member (Name, Age, Email, Password, JoinDate, Phone, MembershipType_ID, Gym_ID)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """, (name, age, email, password, join_date, phone, membership_type_id, gym_id))

        conn.commit()
        print("✅ Member saved successfully.")
    except Error as e:
        print("❌ Error saving member:", e)
    finally:
        cursor.close()
        conn.close()

# Fetch member by email
def fetch_member_by_email(email):
    conn = get_db_connection()
    if not conn:
        return
    try:
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT * FROM Member WHERE Email = %s", (email,))
        user = cursor.fetchone()
        if user:
            print("👤 Member found:")
            for key, value in user.items():
                print(f"  {key}: {value}")
        else:
            print("ℹ️ No member found with this email.")
    except Error as e:
        print("❌ Error fetching member:", e)
    finally:
        cursor.close()
        conn.close()

# Example usage
if __name__ == '__main__':
    test_email = 'new.member@example.com'

    # Uncomment to insert a new member
    save_member(
        name='New Member',
        age=26,
        email=test_email,
        password='securepass123',
        phone='9876543219',
        membership_type_id=1,
        gym_id=1
    )

    # Fetch member
    fetch_member_by_email(test_email)
