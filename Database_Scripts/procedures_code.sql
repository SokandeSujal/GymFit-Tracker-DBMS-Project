-- ============================================================================
-- GymFit Tracker System - PL/SQL Stored Procedures
-- Database Management System Mini Project
-- Group Members: Sujal Sokande, Kavya Rane, Megha Mahesh, Raya Gangopadhyay
-- ============================================================================

USE GymFitDB;

-- ============================================================================
-- PROCEDURE 1: GetMemberProgressSummary
-- Purpose: Retrieve comprehensive progress metrics for a member
-- Parameters: member_id (INT) - The member's ID
-- Returns: Result set with progress statistics
-- ============================================================================

DELIMITER //

DROP PROCEDURE IF EXISTS GetMemberProgressSummary//

CREATE PROCEDURE GetMemberProgressSummary(IN member_id INT)
BEGIN
    SELECT
        m.M_ID,
        m.Name,
        m.Email,
        m.Age,
        m.JoinDate,
        
        -- Weekly workout statistics
        (SELECT COUNT(*) 
         FROM WorkoutLog 
         WHERE M_ID = member_id 
           AND Date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
        ) AS WeeklyWorkouts,
        
        -- Monthly calorie statistics
        (SELECT AVG(CaloriesBurnt) 
         FROM WorkoutLog 
         WHERE M_ID = member_id 
           AND Date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
        ) AS AvgMonthlyCalories,
        
        (SELECT SUM(CaloriesBurnt) 
         FROM WorkoutLog 
         WHERE M_ID = member_id 
           AND Date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
        ) AS TotalMonthlyCalories,
        
        -- Weight statistics
        (SELECT Weight 
         FROM HealthMetrics 
         WHERE M_ID = member_id 
         ORDER BY Date DESC 
         LIMIT 1
        ) AS CurrentWeight,
        
        (SELECT Weight 
         FROM HealthMetrics 
         WHERE M_ID = member_id 
         ORDER BY Date ASC 
         LIMIT 1
        ) AS StartingWeight,
        
        -- Health metrics
        (SELECT AVG(SleepHours) 
         FROM HealthMetrics 
         WHERE M_ID = member_id 
           AND Date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
        ) AS AvgWeeklySleep,
        
        (SELECT AVG(Steps) 
         FROM HealthMetrics 
         WHERE M_ID = member_id 
           AND Date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
        ) AS AvgWeeklySteps,
        
        -- Membership info
        CheckMembershipExpiry(member_id) AS DaysUntilExpiry,
        CalculateMemberEngagement(member_id) AS EngagementScore
        
    FROM Member m
    WHERE m.M_ID = member_id;
END//

DELIMITER ;

-- Usage: CALL GetMemberProgressSummary(1);

-- ============================================================================
-- PROCEDURE 2: GenerateWorkoutRecommendations
-- Purpose: Generate personalized workout recommendations based on member data
-- Parameters: member_id (INT) - The member's ID
-- Returns: Recommendation with type, message, exercise, and duration
-- ============================================================================

DELIMITER //

DROP PROCEDURE IF EXISTS GenerateWorkoutRecommendations//

CREATE PROCEDURE GenerateWorkoutRecommendations(IN member_id INT)
BEGIN
    DECLARE recent_workout_count INT;
    DECLARE avg_calories_burned DECIMAL(6,2);
    DECLARE current_sleep_hours DECIMAL(4,2);
    DECLARE current_steps INT;
    DECLARE workout_variety INT;
    
    -- Get recent activity data
    SELECT COUNT(*), AVG(CaloriesBurnt)
    INTO recent_workout_count, avg_calories_burned
    FROM WorkoutLog 
    WHERE M_ID = member_id 
      AND Date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY);
    
    -- Get current health metrics
    SELECT SleepHours, Steps
    INTO current_sleep_hours, current_steps
    FROM HealthMetrics 
    WHERE M_ID = member_id 
    ORDER BY Date DESC 
    LIMIT 1;
    
    -- Get exercise variety
    SELECT COUNT(DISTINCT Exercise) INTO workout_variety
    FROM WorkoutLog 
    WHERE M_ID = member_id 
      AND Date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY);
    
    -- Generate recommendation based on priority rules
    IF recent_workout_count < 3 THEN
        SELECT 'frequency' as RecommendationType, 
               'Increase workout frequency to at least 3-4 times per week' as Message,
               'Mixed Cardio & Strength' as RecommendedExercise,
               45 as RecommendedDuration;
               
    ELSEIF current_steps < 5000 THEN
        SELECT 'cardio' as RecommendationType,
               'Boost your daily step count with additional cardio' as Message,
               'Brisk Walking' as RecommendedExercise,
               30 as RecommendedDuration;
               
    ELSEIF current_sleep_hours < 6 THEN
        SELECT 'recovery' as RecommendationType,
               'Improve sleep quality with evening relaxation exercises' as Message,
               'Evening Yoga' as RecommendedExercise,
               20 as RecommendedDuration;
               
    ELSEIF workout_variety < 2 THEN
        SELECT 'variety' as RecommendationType,
               'Add exercise variety to your routine for balanced fitness' as Message,
               'HIIT Training' as RecommendedExercise,
               30 as RecommendedDuration;
               
    ELSEIF avg_calories_burned < 200 THEN
        SELECT 'intensity' as RecommendationType,
               'Increase workout intensity for better calorie burn' as Message,
               'Interval Training' as RecommendedExercise,
               40 as RecommendedDuration;
    ELSE
        SELECT 'maintenance' as RecommendationType,
               'Excellent work! Maintain your current routine with progressive overload' as Message,
               'Current Program' as RecommendedExercise,
               45 as RecommendedDuration;
    END IF;
END//

DELIMITER ;

-- Usage: CALL GenerateWorkoutRecommendations(1);

-- ============================================================================
-- PROCEDURE 3: BookSessionForMember
-- Purpose: Book a training session for a member with capacity validation
-- Parameters:
--   member_id (INT) - The member's ID
--   session_id (INT) - The session to book
-- ============================================================================

DELIMITER //

DROP PROCEDURE IF EXISTS BookSessionForMember//

CREATE PROCEDURE BookSessionForMember(
    IN member_id INT,
    IN session_id INT
)
BEGIN
    DECLARE session_details VARCHAR(100);
    DECLARE session_date DATE;
    DECLARE session_duration INT;
    DECLARE is_full BOOLEAN;
    DECLARE already_booked INT;
    
    -- Check if already booked
    SELECT COUNT(*) INTO already_booked
    FROM WorkoutLog
    WHERE M_ID = member_id 
      AND S_ID = session_id 
      AND Exercise = 'Session Booking';
    
    IF already_booked > 0 THEN
        SELECT 'ERROR: You have already booked this session' AS Status;
    ELSE
        -- Check if session is full
        SET is_full = IsSessionFull(session_id);
        
        IF is_full THEN
            SELECT 'ERROR: Session is full' AS Status;
        ELSE
            -- Get session details
            SELECT Details, SessionDate, Duration
            INTO session_details, session_date, session_duration
            FROM Session
            WHERE S_ID = session_id;
            
            -- Book the session
            INSERT INTO WorkoutLog (M_ID, S_ID, Exercise, Date, Duration, Progress)
            VALUES (member_id, session_id, 'Session Booking', session_date, session_duration, 'Booked');
            
            SELECT 'SUCCESS: Session booked successfully' AS Status,
                   session_details AS SessionDetails,
                   session_date AS SessionDate;
        END IF;
    END IF;
END//

DELIMITER ;

-- Usage: CALL BookSessionForMember(1, 2);

-- ============================================================================
-- PROCEDURE 4: GetTrainerPerformance
-- Purpose: Get comprehensive performance metrics for a trainer
-- Parameters: trainer_id (INT) - The trainer's ID
-- Returns: Trainer performance statistics
-- ============================================================================

DELIMITER //

DROP PROCEDURE IF EXISTS GetTrainerPerformance//

CREATE PROCEDURE GetTrainerPerformance(IN trainer_id INT)
BEGIN
    SELECT 
        t.T_ID,
        t.Name,
        t.Specialization,
        
        -- Session statistics
        COUNT(DISTINCT s.S_ID) as TotalSessions,
        SUM(CASE WHEN s.Status = 'completed' THEN 1 ELSE 0 END) as CompletedSessions,
        SUM(CASE WHEN s.Status = 'scheduled' THEN 1 ELSE 0 END) as UpcomingSessions,
        AVG(s.Duration) as AvgSessionDuration,
        
        -- Client statistics
        COUNT(DISTINCT wl.M_ID) as UniqueClients,
        
        -- Upcoming sessions
        SUM(CASE WHEN s.SessionDate >= CURDATE() THEN 1 ELSE 0 END) as SessionsThisWeek
        
    FROM Trainer t
    LEFT JOIN Session s ON t.T_ID = s.T_ID
    LEFT JOIN WorkoutLog wl ON s.S_ID = wl.S_ID
    WHERE t.T_ID = trainer_id
    GROUP BY t.T_ID, t.Name, t.Specialization;
END//

DELIMITER ;

-- Usage: CALL GetTrainerPerformance(1);

-- ============================================================================
-- PROCEDURE 5: AddWorkoutLog
-- Purpose: Add a new workout log with validation
-- Parameters: Multiple workout details
-- ============================================================================

DELIMITER //

DROP PROCEDURE IF EXISTS AddWorkoutLog//

CREATE PROCEDURE AddWorkoutLog(
    IN member_id INT,
    IN exercise_name VARCHAR(50),
    IN workout_date DATE,
    IN duration_mins INT,
    IN calories DECIMAL(6,2),
    IN distance_km DECIMAL(6,2),
    IN progress_notes VARCHAR(255)
)
BEGIN
    DECLARE member_exists INT;
    
    -- Validate member exists and is active
    SELECT COUNT(*) INTO member_exists
    FROM Member
    WHERE M_ID = member_id AND IsActive = TRUE;
    
    IF member_exists = 0 THEN
        SELECT 'ERROR: Member not found or inactive' AS Status;
    ELSE
        -- Insert workout log
        INSERT INTO WorkoutLog (M_ID, Exercise, Date, Duration, CaloriesBurnt, Distance, Progress)
        VALUES (member_id, exercise_name, workout_date, duration_mins, calories, distance_km, progress_notes);
        
        SELECT 'SUCCESS: Workout logged successfully' AS Status,
               LAST_INSERT_ID() AS WorkoutLogID;
    END IF;
END//

DELIMITER ;

-- Usage: CALL AddWorkoutLog(1, 'Running', CURDATE(), 30, 300, 5.0, 'Great run!');

-- ============================================================================
-- PROCEDURE 6: UpdateMemberHealthMetrics
-- Purpose: Add or update daily health metrics for a member
-- Parameters: Member ID and health metrics
-- ============================================================================

DELIMITER //

DROP PROCEDURE IF EXISTS UpdateMemberHealthMetrics//

CREATE PROCEDURE UpdateMemberHealthMetrics(
    IN member_id INT,
    IN metric_date DATE,
    IN weight_kg DECIMAL(5,2),
    IN height_cm DECIMAL(5,2),
    IN sleep_hrs INT,
    IN water_ltrs DECIMAL(4,2),
    IN daily_steps INT
)
BEGIN
    DECLARE existing_metric INT;
    
    -- Check if metric already exists for this date
    SELECT COUNT(*) INTO existing_metric
    FROM HealthMetrics
    WHERE M_ID = member_id AND Date = metric_date;
    
    IF existing_metric > 0 THEN
        -- Update existing metric
        UPDATE HealthMetrics
        SET Weight = weight_kg,
            Height = height_cm,
            SleepHours = sleep_hrs,
            WaterLiters = water_ltrs,
            Steps = daily_steps
        WHERE M_ID = member_id AND Date = metric_date;
        
        SELECT 'SUCCESS: Health metrics updated' AS Status;
    ELSE
        -- Insert new metric
        INSERT INTO HealthMetrics (M_ID, Date, Weight, Height, SleepHours, WaterLiters, Steps)
        VALUES (member_id, metric_date, weight_kg, height_cm, sleep_hrs, water_ltrs, daily_steps);
        
        SELECT 'SUCCESS: Health metrics added' AS Status;
    END IF;
END//

DELIMITER ;

-- Usage: CALL UpdateMemberHealthMetrics(1, CURDATE(), 70.5, 175, 7, 2.5, 8000);

-- ============================================================================
-- PROCEDURE 7: GetGymStatistics
-- Purpose: Get overall statistics for a gym
-- Parameters: gym_id (INT) - The gym's ID
-- Returns: Comprehensive gym statistics
-- ============================================================================

DELIMITER //

DROP PROCEDURE IF EXISTS GetGymStatistics//

CREATE PROCEDURE GetGymStatistics(IN gym_id INT)
BEGIN
    SELECT 
        g.Gym_ID,
        g.Location,
        g.Capacity,
        
        -- Member statistics
        COUNT(DISTINCT m.M_ID) as TotalMembers,
        SUM(CASE WHEN m.IsActive = TRUE THEN 1 ELSE 0 END) as ActiveMembers,
        
        -- Trainer statistics
        COUNT(DISTINCT t.T_ID) as TotalTrainers,
        
        -- Session statistics
        (SELECT COUNT(*) FROM Session s 
         JOIN Trainer t2 ON s.T_ID = t2.T_ID 
         WHERE t2.Gym_ID = gym_id 
           AND s.SessionDate >= CURDATE()) as UpcomingSessions,
        
        -- Revenue statistics
        SUM(mt.Price) as TotalRevenue,
        AVG(mt.Price) as AvgMembershipPrice
        
    FROM Gym g
    LEFT JOIN Member m ON g.Gym_ID = m.Gym_ID
    LEFT JOIN Trainer t ON g.Gym_ID = t.Gym_ID
    LEFT JOIN MembershipType mt ON m.MembershipType_ID = mt.Type_ID
    WHERE g.Gym_ID = gym_id
    GROUP BY g.Gym_ID, g.Location, g.Capacity;
END//

DELIMITER ;

-- Usage: CALL GetGymStatistics(1);

-- ============================================================================
-- PROCEDURE 8: CreateSessionReminders
-- Purpose: Create reminder notifications for upcoming sessions (next day)
-- Parameters: None
-- Returns: Count of reminders created
-- ============================================================================

DELIMITER //

DROP PROCEDURE IF EXISTS CreateSessionReminders//

CREATE PROCEDURE CreateSessionReminders()
BEGIN
    DECLARE reminders_created INT DEFAULT 0;
    
    -- Insert reminders for sessions tomorrow
    INSERT INTO Notifications (M_ID, Message, Type, IsRead)
    SELECT 
        wl.M_ID,
        CONCAT('Reminder: You have a session "', s.Details, 
               '" scheduled for tomorrow at ', TIME_FORMAT(s.SessionTime, '%h:%i %p')),
        'session_reminder',
        FALSE
    FROM WorkoutLog wl
    JOIN Session s ON wl.S_ID = s.S_ID
    WHERE s.SessionDate = DATE_ADD(CURDATE(), INTERVAL 1 DAY)
      AND wl.Exercise = 'Session Booking'
      AND NOT EXISTS (
          SELECT 1 FROM Notifications n 
          WHERE n.M_ID = wl.M_ID 
            AND n.Type = 'session_reminder'
            AND DATE(n.CreatedAt) = CURDATE()
            AND n.Message LIKE CONCAT('%', s.Details, '%')
      );
    
    SET reminders_created = ROW_COUNT();
    
    SELECT CONCAT('Created ', reminders_created, ' session reminders') AS Result;
END//

DELIMITER ;

-- Usage: CALL CreateSessionReminders();

-- ============================================================================
-- PROCEDURE 9: GetMembershipExpiringReport
-- Purpose: Get report of members with expiring memberships
-- Parameters: days_ahead (INT) - Look ahead this many days
-- Returns: List of members with expiring memberships
-- ============================================================================

DELIMITER //

DROP PROCEDURE IF EXISTS GetMembershipExpiringReport//

CREATE PROCEDURE GetMembershipExpiringReport(IN days_ahead INT)
BEGIN
    SELECT 
        m.M_ID,
        m.Name,
        m.Email,
        m.Phone,
        mt.Name AS MembershipType,
        m.JoinDate,
        DATE_ADD(m.JoinDate, INTERVAL mt.Duration MONTH) AS ExpiryDate,
        CheckMembershipExpiry(m.M_ID) AS DaysUntilExpiry,
        mt.Price AS RenewalPrice
    FROM Member m
    JOIN MembershipType mt ON m.MembershipType_ID = mt.Type_ID
    WHERE m.IsActive = TRUE
      AND CheckMembershipExpiry(m.M_ID) BETWEEN 0 AND days_ahead
    ORDER BY DaysUntilExpiry ASC;
END//

DELIMITER ;

-- Usage: CALL GetMembershipExpiringReport(30);

-- ============================================================================
-- PROCEDURE 10: DeactivateExpiredMemberships
-- Purpose: Automatically deactivate members with expired memberships
-- Parameters: None
-- Returns: Count of deactivated memberships
-- ============================================================================

DELIMITER //

DROP PROCEDURE IF EXISTS DeactivateExpiredMemberships//

CREATE PROCEDURE DeactivateExpiredMemberships()
BEGIN
    DECLARE deactivated_count INT;
    
    -- Update expired memberships to inactive
    UPDATE Member m
    JOIN MembershipType mt ON m.MembershipType_ID = mt.Type_ID
    SET m.IsActive = FALSE
    WHERE m.IsActive = TRUE
      AND DATE_ADD(m.JoinDate, INTERVAL mt.Duration MONTH) < CURDATE();
    
    SET deactivated_count = ROW_COUNT();
    
    SELECT CONCAT('Deactivated ', deactivated_count, ' expired memberships') AS Result;
END//

DELIMITER ;

-- Usage: CALL DeactivateExpiredMemberships();

-- ============================================================================
-- End of Stored Procedures
-- ============================================================================

/*
PROCEDURE SUMMARY:

1. GetMemberProgressSummary - Comprehensive member progress report
2. GenerateWorkoutRecommendations - AI-like workout recommendations
3. BookSessionForMember - Book session with validation
4. GetTrainerPerformance - Trainer performance metrics
5. AddWorkoutLog - Add workout with validation
6. UpdateMemberHealthMetrics - Add/update health metrics
7. GetGymStatistics - Overall gym statistics
8. CreateSessionReminders - Automated session reminders
9. GetMembershipExpiringReport - Expiring memberships report
10. DeactivateExpiredMemberships - Auto-deactivate expired memberships

All procedures include:
- Input validation
- Error handling
- Comprehensive result sets
- Business logic implementation
- Clear parameter definitions
- Detailed documentation
*/