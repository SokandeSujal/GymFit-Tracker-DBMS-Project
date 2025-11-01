-- ============================================================================
-- GymFit Tracker System - Database Triggers
-- Database Management System Mini Project
-- Group Members: Sujal Sokande, Kavya Rane, Megha Mahesh, Raya Gangopadhyay
-- ============================================================================

USE GymFitDB;

-- ============================================================================
-- TRIGGER 1: CheckSessionCapacity
-- Type: BEFORE INSERT
-- Purpose: Prevent session booking if capacity is full
-- Table: WorkoutLog
-- ============================================================================

DELIMITER //

DROP TRIGGER IF EXISTS CheckSessionCapacity//

CREATE TRIGGER CheckSessionCapacity
BEFORE INSERT ON WorkoutLog
FOR EACH ROW
BEGIN
    DECLARE current_participants INT;
    DECLARE max_participants INT;
    
    -- Only check if this is a session booking
    IF NEW.S_ID IS NOT NULL AND NEW.Exercise = 'Session Booking' THEN
        
        -- Get current participant count and max capacity
        SELECT COUNT(*), s.MaxParticipants
        INTO current_participants, max_participants
        FROM WorkoutLog wl
        JOIN Session s ON wl.S_ID = s.S_ID
        WHERE wl.S_ID = NEW.S_ID 
          AND wl.Exercise = 'Session Booking';
        
        -- Prevent booking if session is full
        IF current_participants >= max_participants THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Session is already full. Cannot book this session.';
        END IF;
    END IF;
END//

DELIMITER ;

-- Test: Try to book a session that's at capacity
-- INSERT INTO WorkoutLog (M_ID, S_ID, Exercise, Date, Duration)
-- VALUES (2, 1, 'Session Booking', CURDATE(), 60);

-- ============================================================================
-- TRIGGER 2: CheckMembershipRenewal
-- Type: BEFORE UPDATE
-- Purpose: Auto-generate renewal notifications and deactivate expired memberships
-- Table: Member
-- ============================================================================

DELIMITER //

DROP TRIGGER IF EXISTS CheckMembershipRenewal//

CREATE TRIGGER CheckMembershipRenewal 
BEFORE UPDATE ON Member
FOR EACH ROW
BEGIN
    DECLARE membership_duration INT;
    DECLARE renewal_date DATE;
    
    -- Get membership duration
    SELECT Duration INTO membership_duration 
    FROM MembershipType 
    WHERE Type_ID = NEW.MembershipType_ID;
    
    -- Calculate renewal date
    SET renewal_date = DATE_ADD(NEW.JoinDate, INTERVAL membership_duration MONTH);
    
    -- Check if membership is expiring within 7 days
    IF renewal_date BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 7 DAY) THEN
        
        -- Create renewal notification if not already exists
        IF NOT EXISTS (
            SELECT 1 FROM Notifications 
            WHERE M_ID = NEW.M_ID 
              AND Type = 'renewal'
              AND CreatedAt >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
        ) THEN
            INSERT INTO Notifications (M_ID, Message, Type)
            VALUES (
                NEW.M_ID, 
                CONCAT('Your membership expires on ', renewal_date, 
                       '. Please renew to continue enjoying our services.'), 
                'renewal'
            );
        END IF;
    END IF;
    
    -- Auto-deactivate if membership has expired
    IF renewal_date < CURDATE() THEN
        SET NEW.IsActive = FALSE;
    END IF;
END//

DELIMITER ;

-- Test: Update a member to trigger renewal check
-- UPDATE Member SET Name = Name WHERE M_ID = 1;

-- ============================================================================
-- TRIGGER 3: TrackWorkoutProgress
-- Type: AFTER INSERT
-- Purpose: Create progress milestone notifications
-- Table: WorkoutLog
-- ============================================================================

DELIMITER //

DROP TRIGGER IF EXISTS TrackWorkoutProgress//

CREATE TRIGGER TrackWorkoutProgress 
AFTER INSERT ON WorkoutLog
FOR EACH ROW
BEGIN
    DECLARE total_workouts INT;
    DECLARE progress_message VARCHAR(255);
    
    -- Count total workouts for this member (excluding session bookings)
    SELECT COUNT(*) INTO total_workouts 
    FROM WorkoutLog 
    WHERE M_ID = NEW.M_ID 
      AND Exercise != 'Session Booking';
    
    -- Set milestone messages
    IF total_workouts = 10 THEN
        SET progress_message = 'Congratulations! You have completed 10 workouts. Keep up the great work!';
    ELSEIF total_workouts = 25 THEN
        SET progress_message = 'Amazing! 25 workouts completed. You are making excellent progress!';
    ELSEIF total_workouts = 50 THEN
        SET progress_message = 'Incredible milestone! 50 workouts completed. You are a fitness champion!';
    ELSEIF total_workouts = 100 THEN
        SET progress_message = 'Legendary achievement! 100 workouts completed. Outstanding dedication!';
    END IF;
    
    -- Insert progress notification if milestone reached
    IF progress_message IS NOT NULL THEN
        INSERT INTO Notifications (M_ID, Message, Type)
        VALUES (NEW.M_ID, progress_message, 'progress');
    END IF;
END//

DELIMITER ;

-- Test: Add workout logs to reach milestone
-- INSERT INTO WorkoutLog (M_ID, Exercise, Date, Duration, CaloriesBurnt)
-- VALUES (1, 'Running', CURDATE(), 30, 300);

-- ============================================================================
-- TRIGGER 4: ValidateHealthMetrics
-- Type: BEFORE INSERT
-- Purpose: Validate health metric values are within reasonable ranges
-- Table: HealthMetrics
-- ============================================================================

DELIMITER //

DROP TRIGGER IF EXISTS ValidateHealthMetrics//

CREATE TRIGGER ValidateHealthMetrics
BEFORE INSERT ON HealthMetrics
FOR EACH ROW
BEGIN
    -- Validate Weight (20 kg to 300 kg)
    IF NEW.Weight IS NOT NULL AND (NEW.Weight < 20 OR NEW.Weight > 300) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Weight must be between 20 and 300 kg';
    END IF;
    
    -- Validate Height (100 cm to 250 cm)
    IF NEW.Height IS NOT NULL AND (NEW.Height < 100 OR NEW.Height > 250) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Height must be between 100 and 250 cm';
    END IF;
    
    -- Validate Sleep Hours (0 to 24 hours)
    IF NEW.SleepHours IS NOT NULL AND (NEW.SleepHours < 0 OR NEW.SleepHours > 24) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Sleep hours must be between 0 and 24';
    END IF;
    
    -- Validate Water Intake (0 to 10 liters)
    IF NEW.WaterLiters IS NOT NULL AND (NEW.WaterLiters < 0 OR NEW.WaterLiters > 10) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Water intake must be between 0 and 10 liters';
    END IF;
    
    -- Validate Steps (0 to 100,000)
    IF NEW.Steps IS NOT NULL AND (NEW.Steps < 0 OR NEW.Steps > 100000) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Steps must be between 0 and 100,000';
    END IF;
END//

DELIMITER ;

-- Test: Try to insert invalid health metrics
-- INSERT INTO HealthMetrics (M_ID, Date, Weight) VALUES (1, CURDATE(), 500);

-- ============================================================================
-- TRIGGER 5: ValidateWorkoutData
-- Type: BEFORE INSERT
-- Purpose: Validate workout log data before insertion
-- Table: WorkoutLog
-- ============================================================================

DELIMITER //

DROP TRIGGER IF EXISTS ValidateWorkoutData//

CREATE TRIGGER ValidateWorkoutData
BEFORE INSERT ON WorkoutLog
FOR EACH ROW
BEGIN
    -- Validate Duration (5 to 300 minutes)
    IF NEW.Duration IS NOT NULL AND (NEW.Duration < 5 OR NEW.Duration > 300) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Workout duration must be between 5 and 300 minutes';
    END IF;
    
    -- Validate Calories Burnt (0 to 2000 per session)
    IF NEW.CaloriesBurnt IS NOT NULL AND (NEW.CaloriesBurnt < 0 OR NEW.CaloriesBurnt > 2000) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Calories burnt must be between 0 and 2000';
    END IF;
    
    -- Validate Distance (0 to 50 km per session)
    IF NEW.Distance IS NOT NULL AND (NEW.Distance < 0 OR NEW.Distance > 50) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Distance must be between 0 and 50 km';
    END IF;
    
    -- Ensure workout date is not in future
    IF NEW.Date > CURDATE() THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Workout date cannot be in the future';
    END IF;
END//

DELIMITER ;

-- Test: Try to insert invalid workout data
-- INSERT INTO WorkoutLog (M_ID, Exercise, Date, Duration)
-- VALUES (1, 'Running', DATE_ADD(CURDATE(), INTERVAL 1 DAY), 30);

-- ============================================================================
-- TRIGGER 6: UpdateSessionStatus
-- Type: AFTER UPDATE
-- Purpose: Auto-update session status based on date
-- Table: Session
-- ============================================================================

DELIMITER //

DROP TRIGGER IF EXISTS UpdateSessionStatus//

CREATE TRIGGER UpdateSessionStatus
AFTER UPDATE ON Session
FOR EACH ROW
BEGIN
    -- If session date has passed and status is still scheduled, mark as completed
    IF NEW.SessionDate < CURDATE() AND NEW.Status = 'scheduled' THEN
        UPDATE Session 
        SET Status = 'completed'
        WHERE S_ID = NEW.S_ID;
    END IF;
END//

DELIMITER ;

-- ============================================================================
-- TRIGGER 7: LogMemberActivity
-- Type: AFTER INSERT
-- Purpose: Track last activity date for member engagement
-- Table: WorkoutLog
-- ============================================================================

DELIMITER //

DROP TRIGGER IF EXISTS LogMemberActivity//

CREATE TRIGGER LogMemberActivity
AFTER INSERT ON WorkoutLog
FOR EACH ROW
BEGIN
    -- Update member's last activity (could be used for engagement tracking)
    -- This would require an additional LastActivity column in Member table
    -- For demonstration, we'll create a system notification instead
    
    IF (SELECT COUNT(*) FROM WorkoutLog WHERE M_ID = NEW.M_ID) = 1 THEN
        -- First workout - welcome message
        INSERT INTO Notifications (M_ID, Message, Type)
        VALUES (NEW.M_ID, 
                'Welcome to GymFit! You have logged your first workout. Great start!', 
                'system');
    END IF;
END//

DELIMITER ;

-- ============================================================================
-- TRIGGER 8: PreventPastSessionBooking
-- Type: BEFORE INSERT
-- Purpose: Prevent booking sessions that have already passed
-- Table: WorkoutLog
-- ============================================================================

DELIMITER //

DROP TRIGGER IF EXISTS PreventPastSessionBooking//

CREATE TRIGGER PreventPastSessionBooking
BEFORE INSERT ON WorkoutLog
FOR EACH ROW
BEGIN
    DECLARE session_date DATE;
    
    -- Only check for session bookings
    IF NEW.S_ID IS NOT NULL AND NEW.Exercise = 'Session Booking' THEN
        
        -- Get session date
        SELECT SessionDate INTO session_date
        FROM Session
        WHERE S_ID = NEW.S_ID;
        
        -- Prevent booking past sessions
        IF session_date < CURDATE() THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot book sessions that have already passed';
        END IF;
    END IF;
END//

DELIMITER ;

-- ============================================================================
-- TRIGGER 9: ValidateMemberAge
-- Type: BEFORE INSERT and BEFORE UPDATE
-- Purpose: Ensure member age is within acceptable range
-- Table: Member
-- ============================================================================

DELIMITER //

DROP TRIGGER IF EXISTS ValidateMemberAgeInsert//

CREATE TRIGGER ValidateMemberAgeInsert
BEFORE INSERT ON Member
FOR EACH ROW
BEGIN
    IF NEW.Age < 10 OR NEW.Age > 100 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Member age must be between 10 and 100 years';
    END IF;
END//

DROP TRIGGER IF EXISTS ValidateMemberAgeUpdate//

CREATE TRIGGER ValidateMemberAgeUpdate
BEFORE UPDATE ON Member
FOR EACH ROW
BEGIN
    IF NEW.Age < 10 OR NEW.Age > 100 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Member age must be between 10 and 100 years';
    END IF;
END//

DELIMITER ;

-- ============================================================================
-- TRIGGER 10: NotifyLowEngagement
-- Type: AFTER UPDATE
-- Purpose: Notify members with declining engagement
-- Table: HealthMetrics
-- ============================================================================

DELIMITER //

DROP TRIGGER IF EXISTS NotifyLowEngagement//

CREATE TRIGGER NotifyLowEngagement
AFTER UPDATE ON HealthMetrics
FOR EACH ROW
BEGIN
    DECLARE last_workout_date DATE;
    DECLARE days_since_workout INT;
    
    -- Get last workout date
    SELECT MAX(Date) INTO last_workout_date
    FROM WorkoutLog
    WHERE M_ID = NEW.M_ID 
      AND Exercise != 'Session Booking';
    
    -- Calculate days since last workout
    IF last_workout_date IS NOT NULL THEN
        SET days_since_workout = DATEDIFF(CURDATE(), last_workout_date);
        
        -- If no workout in 7 days, send notification (only once)
        IF days_since_workout >= 7 THEN
            IF NOT EXISTS (
                SELECT 1 FROM Notifications
                WHERE M_ID = NEW.M_ID
                  AND Type = 'system'
                  AND Message LIKE '%missed you%'
                  AND CreatedAt >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
            ) THEN
                INSERT INTO Notifications (M_ID, Message, Type)
                VALUES (NEW.M_ID,
                        'We have missed you! It has been a week since your last workout. Come back and continue your fitness journey!',
                        'system');
            END IF;
        END IF;
    END IF;
END//

DELIMITER ;

-- ============================================================================
-- End of Triggers
-- ============================================================================

/*
TRIGGER SUMMARY:

1. CheckSessionCapacity - Prevent overbooking sessions (BEFORE INSERT)
2. CheckMembershipRenewal - Auto-renewal notifications (BEFORE UPDATE)
3. TrackWorkoutProgress - Milestone notifications (AFTER INSERT)
4. ValidateHealthMetrics - Validate health data ranges (BEFORE INSERT)
5. ValidateWorkoutData - Validate workout data (BEFORE INSERT)
6. UpdateSessionStatus - Auto-update session status (AFTER UPDATE)
7. LogMemberActivity - Track member engagement (AFTER INSERT)
8. PreventPastSessionBooking - Block past session bookings (BEFORE INSERT)
9. ValidateMemberAge - Validate age constraints (BEFORE INSERT/UPDATE)
10. NotifyLowEngagement - Re-engagement notifications (AFTER UPDATE)

Trigger Types Demonstrated:
- BEFORE INSERT: Data validation before insertion
- AFTER INSERT: Post-insertion actions and notifications
- BEFORE UPDATE: Pre-update validations
- AFTER UPDATE: Post-update processing

Features Implemented:
- Business rule enforcement
- Data validation
- Automated notifications
- Referential integrity checks
- Capacity management
- User engagement tracking
- Error prevention

All triggers include:
- Proper error handling with SIGNAL
- Clear error messages
- Conditional logic
- Data validation
- Automated business processes
*/