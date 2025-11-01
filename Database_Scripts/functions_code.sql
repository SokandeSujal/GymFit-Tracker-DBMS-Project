-- ============================================================================
-- GymFit Tracker System - Functions Code
-- Database Management System Mini Project
-- Group Members: Sujal Sokande, Kavya Rane, Megha Mahesh, Raya Gangopadhyay
-- ============================================================================

-- Set the database
USE GymFitDB;

-- ============================================================================
-- SECTION 1: Membership Management Functions
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Function 1: Check Membership Expiry Days
-- Purpose: Calculate days remaining until membership expires
-- Returns: Number of days (negative if expired)
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS CheckMembershipExpiry;

DELIMITER //
CREATE FUNCTION CheckMembershipExpiry(member_id INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE days_left INT;
    DECLARE join_date DATE;
    DECLARE duration_months INT;
    DECLARE expiry_date DATE;
    
    -- Get member's join date and membership duration
    SELECT m.JoinDate, mt.Duration 
    INTO join_date, duration_months
    FROM Member m
    JOIN MembershipType mt ON m.MembershipType_ID = mt.Type_ID
    WHERE m.M_ID = member_id;
    
    -- Calculate expiry date
    SET expiry_date = DATE_ADD(join_date, INTERVAL duration_months MONTH);
    
    -- Calculate days left
    SET days_left = DATEDIFF(expiry_date, CURDATE());
    
    RETURN days_left;
END //
DELIMITER ;

-- Test the function
-- SELECT M_ID, Name, CheckMembershipExpiry(M_ID) AS DaysUntilExpiry FROM Member;

-- ----------------------------------------------------------------------------
-- Function 2: Calculate Member BMI
-- Purpose: Calculate Body Mass Index from latest health metrics
-- Returns: BMI value as DECIMAL(5,2)
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS CalculateMemberBMI;

DELIMITER //
CREATE FUNCTION CalculateMemberBMI(member_id INT)
RETURNS DECIMAL(5,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE bmi_value DECIMAL(5,2);
    DECLARE member_weight DECIMAL(5,2);
    DECLARE member_height DECIMAL(5,2);
    
    -- Get latest weight and height
    SELECT Weight, Height 
    INTO member_weight, member_height
    FROM HealthMetrics
    WHERE M_ID = member_id
    ORDER BY Date DESC
    LIMIT 1;
    
    -- Calculate BMI (weight in kg / (height in cm / 100)^2)
    IF member_weight IS NOT NULL AND member_height IS NOT NULL AND member_height > 0 THEN
        SET bmi_value = member_weight / POWER(member_height / 100, 2);
    ELSE
        SET bmi_value = 0;
    END IF;
    
    RETURN bmi_value;
END //
DELIMITER ;

-- Test the function
-- SELECT M_ID, Name, CalculateMemberBMI(M_ID) AS BMI FROM Member;

-- ----------------------------------------------------------------------------
-- Function 3: Get Total Calories Burned
-- Purpose: Calculate total calories burned by member in specified period
-- Returns: Total calories as DECIMAL(10,2)
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS GetTotalCaloriesBurned;

DELIMITER //
CREATE FUNCTION GetTotalCaloriesBurned(
    member_id INT,
    days_back INT
)
RETURNS DECIMAL(10,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE total_calories DECIMAL(10,2);
    
    SELECT COALESCE(SUM(CaloriesBurnt), 0)
    INTO total_calories
    FROM WorkoutLog
    WHERE M_ID = member_id
        AND Date >= DATE_SUB(CURDATE(), INTERVAL days_back DAY)
        AND CaloriesBurnt IS NOT NULL;
    
    RETURN total_calories;
END //
DELIMITER ;

-- Test the function
-- SELECT M_ID, Name, GetTotalCaloriesBurned(M_ID, 30) AS CaloriesLast30Days FROM Member;

-- ============================================================================
-- SECTION 2: Workout Analysis Functions
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Function 4: Calculate Workout Consistency Score
-- Purpose: Calculate workout consistency percentage for member
-- Returns: Consistency score (0-100)
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS CalculateWorkoutConsistency;

DELIMITER //
CREATE FUNCTION CalculateWorkoutConsistency(
    member_id INT,
    days_period INT
)
RETURNS DECIMAL(5,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE total_days INT;
    DECLARE workout_days INT;
    DECLARE consistency_score DECIMAL(5,2);
    
    -- Count unique days with workouts
    SELECT COUNT(DISTINCT Date)
    INTO workout_days
    FROM WorkoutLog
    WHERE M_ID = member_id
        AND Date >= DATE_SUB(CURDATE(), INTERVAL days_period DAY);
    
    SET total_days = days_period;
    
    -- Calculate percentage
    IF total_days > 0 THEN
        SET consistency_score = (workout_days / total_days) * 100;
    ELSE
        SET consistency_score = 0;
    END IF;
    
    RETURN consistency_score;
END //
DELIMITER ;

-- Test the function
-- SELECT M_ID, Name, CalculateWorkoutConsistency(M_ID, 30) AS ConsistencyPercent FROM Member;

-- ----------------------------------------------------------------------------
-- Function 5: Get Average Workout Duration
-- Purpose: Calculate average workout duration for member
-- Returns: Average duration in minutes
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS GetAvgWorkoutDuration;

DELIMITER //
CREATE FUNCTION GetAvgWorkoutDuration(
    member_id INT,
    days_back INT
)
RETURNS DECIMAL(6,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE avg_duration DECIMAL(6,2);
    
    SELECT COALESCE(AVG(Duration), 0)
    INTO avg_duration
    FROM WorkoutLog
    WHERE M_ID = member_id
        AND Date >= DATE_SUB(CURDATE(), INTERVAL days_back DAY)
        AND Duration IS NOT NULL
        AND Exercise != 'Session Booking';
    
    RETURN avg_duration;
END //
DELIMITER ;

-- Test the function
-- SELECT M_ID, Name, GetAvgWorkoutDuration(M_ID, 30) AS AvgDuration FROM Member;

-- ============================================================================
-- SECTION 3: Session Management Functions
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Function 6: Check Session Availability
-- Purpose: Check if session has available spots
-- Returns: 1 if available, 0 if full
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS IsSessionAvailable;

DELIMITER //
CREATE FUNCTION IsSessionAvailable(session_id INT)
RETURNS BOOLEAN
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE current_participants INT;
    DECLARE max_participants INT;
    DECLARE is_available BOOLEAN;
    
    -- Get current and max participants
    SELECT COUNT(*), s.MaxParticipants
    INTO current_participants, max_participants
    FROM WorkoutLog wl
    JOIN Session s ON wl.S_ID = s.S_ID
    WHERE wl.S_ID = session_id 
        AND wl.Exercise = 'Session Booking'
    GROUP BY s.MaxParticipants;
    
    -- Handle case where no one has booked yet
    IF current_participants IS NULL THEN
        SELECT MaxParticipants INTO max_participants
        FROM Session WHERE S_ID = session_id;
        SET current_participants = 0;
    END IF;
    
    -- Check availability
    IF current_participants < max_participants THEN
        SET is_available = TRUE;
    ELSE
        SET is_available = FALSE;
    END IF;
    
    RETURN is_available;
END //
DELIMITER ;

-- Test the function
-- SELECT S_ID, Details, IsSessionAvailable(S_ID) AS IsAvailable FROM Session;

-- ----------------------------------------------------------------------------
-- Function 7: Count Trainer's Active Sessions
-- Purpose: Count upcoming sessions for a trainer
-- Returns: Number of active sessions
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS CountTrainerActiveSessions;

DELIMITER //
CREATE FUNCTION CountTrainerActiveSessions(trainer_id INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE session_count INT;
    
    SELECT COUNT(*)
    INTO session_count
    FROM Session
    WHERE T_ID = trainer_id
        AND SessionDate >= CURDATE()
        AND Status = 'scheduled';
    
    RETURN session_count;
END //
DELIMITER ;

-- Test the function
-- SELECT T_ID, Name, CountTrainerActiveSessions(T_ID) AS ActiveSessions FROM Trainer;

-- ============================================================================
-- SECTION 4: Health & Progress Functions
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Function 8: Calculate Weight Change
-- Purpose: Calculate weight change over specified period
-- Returns: Weight change in kg (negative means loss)
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS CalculateWeightChange;

DELIMITER //
CREATE FUNCTION CalculateWeightChange(
    member_id INT,
    days_period INT
)
RETURNS DECIMAL(5,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE current_weight DECIMAL(5,2);
    DECLARE past_weight DECIMAL(5,2);
    DECLARE weight_change DECIMAL(5,2);
    
    -- Get current weight
    SELECT Weight INTO current_weight
    FROM HealthMetrics
    WHERE M_ID = member_id
    ORDER BY Date DESC
    LIMIT 1;
    
    -- Get weight from specified days ago
    SELECT Weight INTO past_weight
    FROM HealthMetrics
    WHERE M_ID = member_id
        AND Date <= DATE_SUB(CURDATE(), INTERVAL days_period DAY)
    ORDER BY Date DESC
    LIMIT 1;
    
    -- Calculate change
    IF current_weight IS NOT NULL AND past_weight IS NOT NULL THEN
        SET weight_change = current_weight - past_weight;
    ELSE
        SET weight_change = 0;
    END IF;
    
    RETURN weight_change;
END //
DELIMITER ;

-- Test the function
-- SELECT M_ID, Name, CalculateWeightChange(M_ID, 30) AS WeightChangeLast30Days FROM Member;

-- ----------------------------------------------------------------------------
-- Function 9: Get Average Daily Steps
-- Purpose: Calculate average daily steps for member
-- Returns: Average steps count
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS GetAvgDailySteps;

DELIMITER //
CREATE FUNCTION GetAvgDailySteps(
    member_id INT,
    days_back INT
)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE avg_steps INT;
    
    SELECT COALESCE(AVG(Steps), 0)
    INTO avg_steps
    FROM HealthMetrics
    WHERE M_ID = member_id
        AND Date >= DATE_SUB(CURDATE(), INTERVAL days_back DAY)
        AND Steps IS NOT NULL;
    
    RETURN avg_steps;
END //
DELIMITER ;

-- Test the function
-- SELECT M_ID, Name, GetAvgDailySteps(M_ID, 7) AS AvgStepsLastWeek FROM Member;

-- ============================================================================
-- SECTION 5: Membership Revenue Functions
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Function 10: Calculate Total Revenue for Gym
-- Purpose: Calculate total revenue from active memberships
-- Returns: Total revenue as DECIMAL(12,2)
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS CalculateGymRevenue;

DELIMITER //
CREATE FUNCTION CalculateGymRevenue(gym_id INT)
RETURNS DECIMAL(12,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE total_revenue DECIMAL(12,2);
    
    SELECT COALESCE(SUM(mt.Price), 0)
    INTO total_revenue
    FROM Member m
    JOIN MembershipType mt ON m.MembershipType_ID = mt.Type_ID
    WHERE m.Gym_ID = gym_id
        AND m.IsActive = TRUE;
    
    RETURN total_revenue;
END //
DELIMITER ;

-- Test the function
-- SELECT Gym_ID, Location, CalculateGymRevenue(Gym_ID) AS TotalRevenue FROM Gym;

-- ============================================================================
-- SECTION 6: Utility Functions
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Function 11: Get Member Age Group
-- Purpose: Categorize member into age group
-- Returns: Age group as VARCHAR(20)
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS GetMemberAgeGroup;

DELIMITER //
CREATE FUNCTION GetMemberAgeGroup(member_age INT)
RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
    DECLARE age_group VARCHAR(20);
    
    CASE
        WHEN member_age < 18 THEN SET age_group = 'Teen';
        WHEN member_age BETWEEN 18 AND 25 THEN SET age_group = 'Young Adult';
        WHEN member_age BETWEEN 26 AND 40 THEN SET age_group = 'Adult';
        WHEN member_age BETWEEN 41 AND 60 THEN SET age_group = 'Middle Age';
        ELSE SET age_group = 'Senior';
    END CASE;
    
    RETURN age_group;
END //
DELIMITER ;

-- Test the function
-- SELECT M_ID, Name, Age, GetMemberAgeGroup(Age) AS AgeGroup FROM Member;

-- ----------------------------------------------------------------------------
-- Function 12: Format Duration to Time String
-- Purpose: Convert minutes to HH:MM format
-- Returns: Time string as VARCHAR(10)
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS FormatDurationToTime;

DELIMITER //
CREATE FUNCTION FormatDurationToTime(minutes INT)
RETURNS VARCHAR(10)
DETERMINISTIC
BEGIN
    DECLARE hours INT;
    DECLARE mins INT;
    DECLARE time_string VARCHAR(10);
    
    SET hours = FLOOR(minutes / 60);
    SET mins = minutes MOD 60;
    
    SET time_string = CONCAT(
        LPAD(hours, 2, '0'), 
        ':', 
        LPAD(mins, 2, '0')
    );
    
    RETURN time_string;
END //
DELIMITER ;

-- Test the function
-- SELECT Duration, FormatDurationToTime(Duration) AS FormattedTime FROM WorkoutLog LIMIT 10;

-- ============================================================================
-- COMPREHENSIVE TESTING QUERIES
-- ============================================================================

-- Test all membership functions
SELECT 
    M_ID,
    Name,
    CheckMembershipExpiry(M_ID) AS DaysUntilExpiry,
    CalculateMemberBMI(M_ID) AS BMI,
    GetTotalCaloriesBurned(M_ID, 30) AS CaloriesLast30Days,
    CalculateWorkoutConsistency(M_ID, 30) AS ConsistencyPercent,
    GetAvgWorkoutDuration(M_ID, 30) AS AvgWorkoutDuration
FROM Member
LIMIT 5;

-- Test health and progress functions
SELECT 
    M_ID,
    Name,
    CalculateWeightChange(M_ID, 30) AS WeightChange30Days,
    GetAvgDailySteps(M_ID, 7) AS AvgStepsLastWeek,
    GetMemberAgeGroup(Age) AS AgeGroup
FROM Member
LIMIT 5;

-- Test session functions
SELECT 
    S_ID,
    Details,
    SessionDate,
    IsSessionAvailable(S_ID) AS IsAvailable,
    MaxParticipants
FROM Session
WHERE SessionDate >= CURDATE()
LIMIT 5;

-- Test trainer functions
SELECT 
    T_ID,
    Name,
    Specialization,
    CountTrainerActiveSessions(T_ID) AS ActiveSessions
FROM Trainer;

-- Test gym revenue function
SELECT 
    Gym_ID,
    Location,
    CalculateGymRevenue(Gym_ID) AS EstimatedRevenue
FROM Gym;

-- ============================================================================
-- End of Functions Code
-- ============================================================================

/*
SUMMARY OF FUNCTIONS CREATED:

1. CheckMembershipExpiry(member_id) - Calculate days until membership expires
2. CalculateMemberBMI(member_id) - Calculate Body Mass Index
3. GetTotalCaloriesBurned(member_id, days) - Total calories in period
4. CalculateWorkoutConsistency(member_id, days) - Workout consistency %
5. GetAvgWorkoutDuration(member_id, days) - Average workout duration
6. IsSessionAvailable(session_id) - Check session availability
7. CountTrainerActiveSessions(trainer_id) - Count upcoming sessions
8. CalculateWeightChange(member_id, days) - Weight change over period
9. GetAvgDailySteps(member_id, days) - Average daily steps
10. CalculateGymRevenue(gym_id) - Total revenue from memberships
11. GetMemberAgeGroup(age) - Categorize member by age
12. FormatDurationToTime(minutes) - Convert minutes to HH:MM format

All functions are tested and ready for use in the GymFit Tracker System.
*/