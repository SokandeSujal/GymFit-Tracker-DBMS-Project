-- ============================================================================
-- GymFit Tracker System - Cursor Implementations
-- Database Management System Mini Project
-- Group Members: Sujal Sokande, Kavya Rane, Megha Mahesh, Raya Gangopadhyay
-- ============================================================================

USE GymFitDB;

-- ============================================================================
-- CURSOR 1: CheckAllMembershipRenewals (Main Cursor)
-- Purpose: Iterate through members with upcoming renewals and create notifications
-- Type: Explicit Cursor with Loop
-- ============================================================================

DELIMITER //

DROP PROCEDURE IF EXISTS CheckAllMembershipRenewals//

CREATE PROCEDURE CheckAllMembershipRenewals()
BEGIN
    -- Declare variables for cursor data
    DECLARE done INT DEFAULT FALSE;
    DECLARE member_id INT;
    DECLARE member_name VARCHAR(100);
    DECLARE renewal_date DATE;
    DECLARE days_until_renewal INT;
    DECLARE notification_count INT DEFAULT 0;
    
    -- Declare cursor for members with upcoming renewals (within 7 days)
    DECLARE member_cursor CURSOR FOR 
        SELECT m.M_ID, 
               m.Name, 
               DATE_ADD(m.JoinDate, INTERVAL mt.Duration MONTH) AS RenewalDate
        FROM Member m
        JOIN MembershipType mt ON m.MembershipType_ID = mt.Type_ID
        WHERE m.IsActive = TRUE
          AND DATE_ADD(m.JoinDate, INTERVAL mt.Duration MONTH) 
              BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 7 DAY);
    
    -- Declare handler for end of cursor
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    -- Open the cursor
    OPEN member_cursor;
    
    -- Loop through all members
    renewal_loop: LOOP
        -- Fetch next row
        FETCH member_cursor INTO member_id, member_name, renewal_date;
        
        -- Exit loop if no more rows
        IF done THEN
            LEAVE renewal_loop;
        END IF;
        
        -- Calculate days until renewal
        SET days_until_renewal = DATEDIFF(renewal_date, CURDATE());
        
        -- Check if notification already exists (avoid duplicates)
        IF NOT EXISTS (
            SELECT 1 FROM Notifications
            WHERE M_ID = member_id 
              AND Type = 'renewal'
              AND CreatedAt >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
        ) THEN
            -- Create personalized renewal notification
            INSERT INTO Notifications (M_ID, Message, Type)
            VALUES (
                member_id, 
                CONCAT('Hello ', member_name, '! Your membership renews in ', 
                       days_until_renewal, ' day', 
                       IF(days_until_renewal > 1, 's', ''), 
                       ' on ', DATE_FORMAT(renewal_date, '%M %d, %Y'), 
                       '. Please contact us to renew your membership.'), 
                'renewal'
            );
            
            -- Increment counter
            SET notification_count = notification_count + 1;
        END IF;
    END LOOP;
    
    -- Close the cursor
    CLOSE member_cursor;
    
    -- Return summary result
    SELECT CONCAT('Membership renewal check completed. ', 
                  notification_count, 
                  ' notification(s) created.') AS Result;
END//

DELIMITER ;

-- Usage: CALL CheckAllMembershipRenewals();

-- ============================================================================
-- CURSOR 2: ProcessInactiveMembers
-- Purpose: Iterate through inactive members and generate re-engagement reports
-- Type: Cursor with conditional processing
-- ============================================================================

DELIMITER //

DROP PROCEDURE IF EXISTS ProcessInactiveMembers//

CREATE PROCEDURE ProcessInactiveMembers()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE member_id INT;
    DECLARE member_name VARCHAR(100);
    DECLARE member_email VARCHAR(100);
    DECLARE last_workout DATE;
    DECLARE days_inactive INT;
    DECLARE processed_count INT DEFAULT 0;
    
    -- Cursor for members inactive for 14+ days
    DECLARE inactive_cursor CURSOR FOR
        SELECT 
            m.M_ID,
            m.Name,
            m.Email,
            MAX(wl.Date) AS LastWorkout,
            DATEDIFF(CURDATE(), MAX(wl.Date)) AS DaysInactive
        FROM Member m
        LEFT JOIN WorkoutLog wl ON m.M_ID = wl.M_ID
        WHERE m.IsActive = TRUE
        GROUP BY m.M_ID, m.Name, m.Email
        HAVING DaysInactive >= 14 OR LastWorkout IS NULL;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    -- Temporary table to store results
    CREATE TEMPORARY TABLE IF NOT EXISTS InactiveReport (
        Member_ID INT,
        Member_Name VARCHAR(100),
        Email VARCHAR(100),
        Days_Inactive INT,
        Action_Taken VARCHAR(100)
    );
    
    OPEN inactive_cursor;
    
    inactive_loop: LOOP
        FETCH inactive_cursor INTO member_id, member_name, member_email, 
                                   last_workout, days_inactive;
        
        IF done THEN
            LEAVE inactive_loop;
        END IF;
        
        -- Create re-engagement notification
        IF NOT EXISTS (
            SELECT 1 FROM Notifications
            WHERE M_ID = member_id
              AND Type = 'system'
              AND Message LIKE '%We miss you%'
              AND CreatedAt >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
        ) THEN
            INSERT INTO Notifications (M_ID, Message, Type)
            VALUES (
                member_id,
                CONCAT('We miss you, ', member_name, 
                       '! It has been ', days_inactive, 
                       ' days since your last workout. ',
                       'Come back and continue your fitness journey!'),
                'system'
            );
            
            -- Log in temporary report
            INSERT INTO InactiveReport VALUES (
                member_id, member_name, member_email, days_inactive, 
                'Notification Sent'
            );
            
            SET processed_count = processed_count + 1;
        END IF;
    END LOOP;
    
    CLOSE inactive_cursor;
    
    -- Return report
    SELECT * FROM InactiveReport;
    
    SELECT CONCAT('Processed ', processed_count, 
                  ' inactive member(s)') AS Summary;
    
    -- Clean up
    DROP TEMPORARY TABLE IF EXISTS InactiveReport;
END//

DELIMITER ;

-- Usage: CALL ProcessInactiveMembers();

-- ============================================================================
-- CURSOR 3: GenerateTrainerReport
-- Purpose: Generate comprehensive report for all trainers with cursor iteration
-- Type: Cursor with aggregation and calculations
-- ============================================================================

DELIMITER //

DROP PROCEDURE IF EXISTS GenerateTrainerReport//

CREATE PROCEDURE GenerateTrainerReport()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE trainer_id INT;
    DECLARE trainer_name VARCHAR(100);
    DECLARE specialization VARCHAR(50);
    DECLARE total_sessions INT;
    DECLARE total_clients INT;
    DECLARE avg_session_duration DECIMAL(5,2);
    
    -- Cursor for all trainers
    DECLARE trainer_cursor CURSOR FOR
        SELECT T_ID, Name, Specialization
        FROM Trainer;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    -- Create temporary table for report
    CREATE TEMPORARY TABLE IF NOT EXISTS TrainerPerformanceReport (
        Trainer_ID INT,
        Trainer_Name VARCHAR(100),
        Specialization VARCHAR(50),
        Total_Sessions INT,
        Unique_Clients INT,
        Avg_Session_Duration DECIMAL(5,2),
        Performance_Rating VARCHAR(20)
    );
    
    OPEN trainer_cursor;
    
    trainer_loop: LOOP
        FETCH trainer_cursor INTO trainer_id, trainer_name, specialization;
        
        IF done THEN
            LEAVE trainer_loop;
        END IF;
        
        -- Calculate total sessions
        SELECT COUNT(DISTINCT s.S_ID)
        INTO total_sessions
        FROM Session s
        WHERE s.T_ID = trainer_id;
        
        -- Calculate unique clients
        SELECT COUNT(DISTINCT wl.M_ID)
        INTO total_clients
        FROM Session s
        JOIN WorkoutLog wl ON s.S_ID = wl.S_ID
        WHERE s.T_ID = trainer_id;
        
        -- Calculate average session duration
        SELECT AVG(s.Duration)
        INTO avg_session_duration
        FROM Session s
        WHERE s.T_ID = trainer_id;
        
        -- Insert into report with performance rating
        INSERT INTO TrainerPerformanceReport VALUES (
            trainer_id,
            trainer_name,
            specialization,
            IFNULL(total_sessions, 0),
            IFNULL(total_clients, 0),
            IFNULL(avg_session_duration, 0),
            CASE
                WHEN total_sessions >= 20 AND total_clients >= 10 THEN 'Excellent'
                WHEN total_sessions >= 10 AND total_clients >= 5 THEN 'Good'
                WHEN total_sessions >= 5 THEN 'Average'
                ELSE 'Needs Improvement'
            END
        );
    END LOOP;
    
    CLOSE trainer_cursor;
    
    -- Return report ordered by performance
    SELECT * FROM TrainerPerformanceReport
    ORDER BY Total_Sessions DESC, Unique_Clients DESC;
    
    -- Clean up
    DROP TEMPORARY TABLE IF EXISTS TrainerPerformanceReport;
END//

DELIMITER ;

-- Usage: CALL GenerateTrainerReport();

-- ============================================================================
-- CURSOR 4: BulkUpdateMembershipEndDates
-- Purpose: Bulk update membership end dates for all members using cursor
-- Type: Cursor with UPDATE operations
-- ============================================================================

DELIMITER //

DROP PROCEDURE IF EXISTS BulkUpdateMembershipEndDates//

CREATE PROCEDURE BulkUpdateMembershipEndDates()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE member_id INT;
    DECLARE join_date DATE;
    DECLARE duration_months INT;
    DECLARE calculated_end_date DATE;
    DECLARE updated_count INT DEFAULT 0;
    
    -- Cursor for members without end date
    DECLARE member_cursor CURSOR FOR
        SELECT m.M_ID, m.JoinDate, mt.Duration
        FROM Member m
        JOIN MembershipType mt ON m.MembershipType_ID = mt.Type_ID
        WHERE m.MembershipEndDate IS NULL;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    OPEN member_cursor;
    
    update_loop: LOOP
        FETCH member_cursor INTO member_id, join_date, duration_months;
        
        IF done THEN
            LEAVE update_loop;
        END IF;
        
        -- Calculate end date
        SET calculated_end_date = DATE_ADD(join_date, 
                                          INTERVAL duration_months MONTH);
        
        -- Update member record
        UPDATE Member
        SET MembershipEndDate = calculated_end_date
        WHERE M_ID = member_id;
        
        SET updated_count = updated_count + 1;
    END LOOP;
    
    CLOSE member_cursor;
    
    SELECT CONCAT('Updated ', updated_count, 
                  ' member(s) with membership end dates') AS Result;
END//

DELIMITER ;

-- Usage: CALL BulkUpdateMembershipEndDates();

-- ============================================================================
-- CURSOR 5: GenerateMemberEngagementReport
-- Purpose: Generate engagement report for all members using cursor
-- Type: Cursor with complex calculations
-- ============================================================================

DELIMITER //

DROP PROCEDURE IF EXISTS GenerateMemberEngagementReport//

CREATE PROCEDURE GenerateMemberEngagementReport()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE member_id INT;
    DECLARE member_name VARCHAR(100);
    DECLARE membership_type VARCHAR(30);
    DECLARE workout_count INT;
    DECLARE engagement_score DECIMAL(5,2);
    DECLARE last_activity DATE;
    
    -- Cursor for all active members
    DECLARE member_cursor CURSOR FOR
        SELECT m.M_ID, m.Name, mt.Name
        FROM Member m
        JOIN MembershipType mt ON m.MembershipType_ID = mt.Type_ID
        WHERE m.IsActive = TRUE;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    -- Create report table
    CREATE TEMPORARY TABLE IF NOT EXISTS EngagementReport (
        Member_ID INT,
        Member_Name VARCHAR(100),
        Membership_Type VARCHAR(30),
        Workouts_30Days INT,
        Engagement_Score DECIMAL(5,2),
        Last_Activity DATE,
        Engagement_Level VARCHAR(20)
    );
    
    OPEN member_cursor;
    
    engagement_loop: LOOP
        FETCH member_cursor INTO member_id, member_name, membership_type;
        
        IF done THEN
            LEAVE engagement_loop;
        END IF;
        
        -- Get workout count (last 30 days)
        SELECT COUNT(*) INTO workout_count
        FROM WorkoutLog
        WHERE M_ID = member_id
          AND Date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
          AND Exercise != 'Session Booking';
        
        -- Calculate engagement score using function
        SET engagement_score = CalculateMemberEngagement(member_id);
        
        -- Get last activity date
        SELECT MAX(Date) INTO last_activity
        FROM WorkoutLog
        WHERE M_ID = member_id;
        
        -- Insert into report
        INSERT INTO EngagementReport VALUES (
            member_id,
            member_name,
            membership_type,
            IFNULL(workout_count, 0),
            IFNULL(engagement_score, 0),
            last_activity,
            CASE
                WHEN engagement_score >= 70 THEN 'Highly Engaged'
                WHEN engagement_score >= 40 THEN 'Moderately Engaged'
                WHEN engagement_score >= 20 THEN 'Low Engagement'
                ELSE 'Inactive'
            END
        );
    END LOOP;
    
    CLOSE member_cursor;
    
    -- Return report ordered by engagement
    SELECT * FROM EngagementReport
    ORDER BY Engagement_Score DESC;
    
    -- Summary statistics
    SELECT 
        COUNT(*) as Total_Members,
        AVG(Engagement_Score) as Avg_Engagement,
        SUM(CASE WHEN Engagement_Level = 'Highly Engaged' THEN 1 ELSE 0 END) as Highly_Engaged,
        SUM(CASE WHEN Engagement_Level = 'Moderately Engaged' THEN 1 ELSE 0 END) as Moderately_Engaged,
        SUM(CASE WHEN Engagement_Level = 'Low Engagement' THEN 1 ELSE 0 END) as Low_Engagement,
        SUM(CASE WHEN Engagement_Level = 'Inactive' THEN 1 ELSE 0 END) as Inactive
    FROM EngagementReport;
    
    -- Clean up
    DROP TEMPORARY TABLE IF EXISTS EngagementReport;
END//

DELIMITER ;

-- Usage: CALL GenerateMemberEngagementReport();

-- ============================================================================
-- CURSOR 6: CleanupOldNotifications
-- Purpose: Archive and delete old notifications using cursor
-- Type: Cursor with DELETE operations
-- ============================================================================

DELIMITER //

DROP PROCEDURE IF EXISTS CleanupOldNotifications//

CREATE PROCEDURE CleanupOldNotifications(IN days_old INT)
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE notif_id INT;
    DECLARE member_id INT;
    DECLARE notif_message TEXT;
    DECLARE notif_type VARCHAR(20);
    DECLARE created_at TIMESTAMP;
    DECLARE deleted_count INT DEFAULT 0;
    
    -- Cursor for old read notifications
    DECLARE notif_cursor CURSOR FOR
        SELECT Notif_ID, M_ID, Message, Type, CreatedAt
        FROM Notifications
        WHERE IsRead = TRUE
          AND CreatedAt < DATE_SUB(CURDATE(), INTERVAL days_old DAY);
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    -- Optional: Create archive table (uncomment if needed)
    -- CREATE TABLE IF NOT EXISTS Notifications_Archive LIKE Notifications;
    
    OPEN notif_cursor;
    
    cleanup_loop: LOOP
        FETCH notif_cursor INTO notif_id, member_id, notif_message, 
                                notif_type, created_at;
        
        IF done THEN
            LEAVE cleanup_loop;
        END IF;
        
        -- Optional: Archive before deleting (uncomment if needed)
        -- INSERT INTO Notifications_Archive 
        -- VALUES (notif_id, member_id, notif_message, notif_type, TRUE, created_at);
        
        -- Delete notification
        DELETE FROM Notifications WHERE Notif_ID = notif_id;
        
        SET deleted_count = deleted_count + 1;
    END LOOP;
    
    CLOSE notif_cursor;
    
    SELECT CONCAT('Cleaned up ', deleted_count, 
                  ' old notification(s)') AS Result;
END//

DELIMITER ;

-- Usage: CALL CleanupOldNotifications(90);

-- ============================================================================
-- End of Cursor Implementations
-- ============================================================================

/*
CURSOR IMPLEMENTATION SUMMARY:

1. CheckAllMembershipRenewals - Main cursor for renewal notifications
   - Demonstrates: Basic cursor loop, FETCH, handlers, conditional INSERT

2. ProcessInactiveMembers - Re-engagement notifications for inactive members
   - Demonstrates: Cursor with calculations, temporary tables, conditional logic

3. GenerateTrainerReport - Comprehensive trainer performance report
   - Demonstrates: Cursor with multiple aggregations, performance ratings

4. BulkUpdateMembershipEndDates - Bulk update using cursor
   - Demonstrates: Cursor with UPDATE operations, date calculations

5. GenerateMemberEngagementReport - Member engagement analysis
   - Demonstrates: Cursor with function calls, complex categorization

6. CleanupOldNotifications - Archive and cleanup old data
   - Demonstrates: Cursor with DELETE operations, optional archiving

CURSOR FEATURES DEMONSTRATED:
- DECLARE CURSOR FOR (cursor declaration)
- OPEN cursor (cursor opening)
- FETCH cursor INTO (fetching data)
- CLOSE cursor (cursor closing)
- DECLARE CONTINUE HANDLER FOR NOT FOUND (end-of-data handling)
- Loop control (LOOP, LEAVE, IF-THEN)
- Variable declarations and assignments
- Conditional logic within cursors
- Temporary table creation and manipulation
- Complex calculations within cursor loops
- Transaction-like batch processing
- Error handling and result reporting

BEST PRACTICES IMPLEMENTED:
- Always declare CONTINUE HANDLER for NOT FOUND
- Close cursors after use
- Use meaningful variable names
- Include result reporting
- Clean up temporary tables
- Validate data before processing
- Use conditional logic for business rules
- Provide summary statistics
*/