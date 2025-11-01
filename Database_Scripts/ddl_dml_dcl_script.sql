-- ============================================================================
-- GymFit Tracker System - DDL, DML, DCL Scripts
-- Database Management System Mini Project
-- Group Members: Sujal Sokande, Kavya Rane, Megha Mahesh, Raya Gangopadhyay
-- ============================================================================

-- ============================================================================
-- SECTION 1: DDL (Data Definition Language)
-- ============================================================================

-- Drop and Create Database
DROP DATABASE IF EXISTS GymFitDB;
CREATE DATABASE GymFitDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE GymFitDB;

-- ----------------------------------------------------------------------------
-- Table 1: Gym
-- ----------------------------------------------------------------------------
CREATE TABLE Gym (
    Gym_ID INT PRIMARY KEY AUTO_INCREMENT,
    Location VARCHAR(50) NOT NULL,
    Capacity INT CHECK (Capacity > 0),
    COMMENT 'Stores gym location details and capacity'
);

-- ----------------------------------------------------------------------------
-- Table 2: MembershipType
-- ----------------------------------------------------------------------------
CREATE TABLE MembershipType (
    Type_ID INT PRIMARY KEY AUTO_INCREMENT,
    Name VARCHAR(30) NOT NULL,
    Duration INT NOT NULL COMMENT 'Duration in months',
    Price DECIMAL(8, 2) NOT NULL CHECK (Price >= 0),
    Gym_ID INT NOT NULL,
    FOREIGN KEY (Gym_ID) REFERENCES Gym(Gym_ID) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE,
    COMMENT 'Different membership plans offered by gyms'
);

-- ----------------------------------------------------------------------------
-- Table 3: Member
-- ----------------------------------------------------------------------------
CREATE TABLE Member (
    M_ID INT PRIMARY KEY AUTO_INCREMENT,
    Name VARCHAR(50) NOT NULL,
    Email VARCHAR(100) UNIQUE NOT NULL,
    Password VARCHAR(255) NOT NULL,
    Age INT CHECK (Age BETWEEN 10 AND 100),
    JoinDate DATE NOT NULL,
    Phone VARCHAR(15),
    MembershipEndDate DATE,
    IsActive BOOLEAN DEFAULT TRUE,
    MembershipType_ID INT NOT NULL,
    Gym_ID INT NOT NULL,
    FOREIGN KEY (MembershipType_ID) 
        REFERENCES MembershipType(Type_ID) 
        ON DELETE SET NULL 
        ON UPDATE CASCADE,
    FOREIGN KEY (Gym_ID) 
        REFERENCES Gym(Gym_ID) 
        ON DELETE SET NULL 
        ON UPDATE CASCADE,
    COMMENT 'Member profiles with membership details'
);

-- ----------------------------------------------------------------------------
-- Table 4: Trainer
-- ----------------------------------------------------------------------------
CREATE TABLE Trainer (
    T_ID INT PRIMARY KEY AUTO_INCREMENT,
    Name VARCHAR(50) NOT NULL,
    Email VARCHAR(100) UNIQUE NOT NULL,
    Password VARCHAR(255) NOT NULL,
    Specialization VARCHAR(50),
    Gym_ID INT,
    FOREIGN KEY (Gym_ID) 
        REFERENCES Gym(Gym_ID) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE,
    COMMENT 'Trainer details and specializations'
);

-- ----------------------------------------------------------------------------
-- Table 5: Admin
-- ----------------------------------------------------------------------------
CREATE TABLE Admin (
    A_ID INT PRIMARY KEY AUTO_INCREMENT,
    Name VARCHAR(50) NOT NULL,
    Email VARCHAR(100) UNIQUE NOT NULL,
    Password VARCHAR(255) NOT NULL,
    COMMENT 'System administrators'
);

-- ----------------------------------------------------------------------------
-- Table 6: Session
-- ----------------------------------------------------------------------------
CREATE TABLE Session (
    S_ID INT PRIMARY KEY AUTO_INCREMENT,
    Details VARCHAR(100),
    SessionDate DATE,
    SessionTime TIME,
    Duration INT COMMENT 'Duration in minutes',
    T_ID INT,
    MaxParticipants INT DEFAULT 10,
    Status ENUM('scheduled', 'completed', 'cancelled') DEFAULT 'scheduled',
    FOREIGN KEY (T_ID) 
        REFERENCES Trainer(T_ID) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE,
    COMMENT 'Training sessions conducted by trainers'
);

-- ----------------------------------------------------------------------------
-- Table 7: WorkoutLog
-- ----------------------------------------------------------------------------
CREATE TABLE WorkoutLog (
    L_ID INT PRIMARY KEY AUTO_INCREMENT,
    M_ID INT NOT NULL,
    S_ID INT,
    Exercise VARCHAR(50),
    Date DATE,
    Duration INT COMMENT 'Duration in minutes',
    CaloriesBurnt DECIMAL(6,2),
    Distance DECIMAL(6,2) COMMENT 'Distance in km',
    Progress VARCHAR(255),
    FOREIGN KEY (M_ID) 
        REFERENCES Member(M_ID) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE,
    FOREIGN KEY (S_ID) 
        REFERENCES Session(S_ID) 
        ON DELETE SET NULL 
        ON UPDATE CASCADE,
    COMMENT 'Individual workout records and session bookings'
);

-- ----------------------------------------------------------------------------
-- Table 8: HealthMetrics
-- ----------------------------------------------------------------------------
CREATE TABLE HealthMetrics (
    Metric_ID INT PRIMARY KEY AUTO_INCREMENT,
    M_ID INT NOT NULL,
    Date DATE NOT NULL,
    Weight DECIMAL(5,2),
    Height DECIMAL(5,2),
    SleepHours INT,
    WaterLiters DECIMAL(4,2),
    Steps INT,
    FOREIGN KEY (M_ID) 
        REFERENCES Member(M_ID) 
        ON DELETE CASCADE,
    COMMENT 'Daily health and activity metrics'
);

-- ----------------------------------------------------------------------------
-- Table 9: Notifications
-- ----------------------------------------------------------------------------
CREATE TABLE Notifications (
    Notif_ID INT PRIMARY KEY AUTO_INCREMENT,
    M_ID INT,
    Message TEXT,
    Type ENUM('renewal', 'session_reminder', 'progress', 'system'),
    IsRead BOOLEAN DEFAULT FALSE,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (M_ID) 
        REFERENCES Member(M_ID) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE,
    COMMENT 'Automated notifications and alerts'
);

-- ============================================================================
-- SECTION 2: DML (Data Manipulation Language)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- INSERT Operations
-- ----------------------------------------------------------------------------

-- Insert Gym Data
INSERT INTO Gym (Gym_ID, Location, Capacity) VALUES
(1, 'Pune Downtown', 150),
(2, 'Mumbai Seaside', 200);

-- Insert Membership Types
INSERT INTO MembershipType (Type_ID, Name, Duration, Price, Gym_ID) VALUES
(1, 'Gold', 12, 12000.00, 1),
(2, 'Silver', 6, 7000.00, 1),
(3, 'Platinum', 12, 15000.00, 2);

-- Insert Admin User (Password: admin123 - hashed)
INSERT INTO Admin (A_ID, Name, Email, Password) VALUES
(1, 'System Admin', 'admin@gymfit.in', 
    'scrypt:32768:8:1$SKPoYjk1R9m14a6N$e89b5cacb7668387273c10c8f5c7e2bf4263f847f62c63abe4151a69f4cf6ebd324bf1d6938aca70ed79468a72ed67e18327bb541e2fef9024d82e3118dee6a7');

-- Insert Members (Passwords are hashed using scrypt)
INSERT INTO Member (M_ID, Name, Email, Password, Age, JoinDate, MembershipType_ID, Gym_ID) VALUES
(1, 'Sujal Sokande', 'sujal.sokande@gmail.com', 
    'scrypt:32768:8:1$yLd02krVD66uLAwc$b3a849f244d6473252e2b74ce0041c79300e37c6b7ca65a672e1c544d94ca2073fd6f86110c2b0224be66b4a4fbb556ebd8044dfe46066884b2958a3cc9be67a', 
    22, '2024-01-10', 1, 1),
(2, 'Priya Deshmukh', 'priya.d@email.com', 
    'scrypt:32768:8:1$RVb8qiW26oramF5y$ace264c4d5aa422ab65ea6540bbf8b3a5b16a8224918dbe38284b9f91687d8ed66ffac213df4e409ef797c8581f3a0ee5648036c1defa32256d3d5bcdf03f30c', 
    25, '2024-03-15', 2, 1),
(3, 'Kavya Rane', 'kavya.rane@gmail.com',
    'scrypt:32768:8:1$RVb8qiW26oramF5y$ace264c4d5aa422ab65ea6540bbf8b3a5b16a8224918dbe38284b9f91687d8ed66ffac213df4e409ef797c8581f3a0ee5648036c1defa32256d3d5bcdf03f30c',
    19, '2025-01-01', 2, 1);

-- Insert Trainers
INSERT INTO Trainer (T_ID, Name, Email, Password, Specialization, Gym_ID) VALUES
(1, 'Joshua Thompson', 'joshua.t@gymfit.in', 
    'scrypt:32768:8:1$RVb8qiW26oramF5y$ace264c4d5aa422ab65ea6540bbf8b3a5b16a8224918dbe38284b9f91687d8ed66ffac213df4e409ef797c8581f3a0ee5648036c1defa32256d3d5bcdf03f30c', 
    'Strength Training', 1),
(2, 'Anjali Mehta', 'anjali.m@gymfit.in', 
    'scrypt:32768:8:1$RVb8qiW26oramF5y$ace264c4d5aa422ab65ea6540bbf8b3a5b16a8224918dbe38284b9f91687d8ed66ffac213df4e409ef797c8581f3a0ee5648036c1defa32256d3d5bcdf03f30c', 
    'Yoga', 2);

-- Insert Sessions
INSERT INTO Session (S_ID, Details, SessionDate, SessionTime, Duration, T_ID, MaxParticipants) VALUES
(1, 'Morning Cardio', CURDATE(), '07:00:00', 60, 1, 15),
(2, 'Evening Yoga', CURDATE() + INTERVAL 1 DAY, '18:30:00', 45, 2, 10),
(3, 'Advanced Weightlifting', CURDATE() + INTERVAL 2 DAY, '17:00:00', 75, 1, 5);

-- Insert Workout Logs
INSERT INTO WorkoutLog (L_ID, M_ID, S_ID, Exercise, Date, Duration, CaloriesBurnt, Distance, Progress) VALUES
(1, 1, 1, 'Treadmill', CURDATE(), 30, 300, 5, 'Good pace'),
(2, 2, NULL, 'Freestyle Weights', CURDATE() - INTERVAL 1 DAY, 45, 250, NULL, 'Felt strong'),
(3, 1, NULL, 'Cycling', CURDATE() - INTERVAL 2 DAY, 60, 500, 20, 'New personal best');

-- Insert Health Metrics
INSERT INTO HealthMetrics (M_ID, Date, Weight, Height, SleepHours, WaterLiters, Steps) VALUES
(1, CURDATE(), 70.5, 175, 7, 2.5, 8000),
(2, CURDATE(), 60.0, 165, 8, 3.0, 10000),
(3, CURDATE(), 55.0, 160, 7, 2.8, 9500);

-- ----------------------------------------------------------------------------
-- SELECT Operations (Sample Queries)
-- ----------------------------------------------------------------------------

-- Query 1: Retrieve all members with their membership type and gym location
SELECT m.M_ID, m.Name, m.Email, m.Age, m.JoinDate,
       mt.Name AS MembershipType, mt.Price,
       g.Location AS GymLocation
FROM Member m
LEFT JOIN MembershipType mt ON m.MembershipType_ID = mt.Type_ID
LEFT JOIN Gym g ON m.Gym_ID = g.Gym_ID
ORDER BY m.JoinDate DESC;

-- Query 2: Get member's recent workouts with session details
SELECT wl.L_ID, wl.Exercise, wl.Date, wl.Duration, 
       wl.CaloriesBurnt, wl.Distance, wl.Progress,
       s.Details AS SessionDetails, s.SessionDate
FROM WorkoutLog wl
LEFT JOIN Session s ON wl.S_ID = s.S_ID
WHERE wl.M_ID = 1
ORDER BY wl.Date DESC, wl.L_ID DESC
LIMIT 10;

-- Query 3: Trainer performance analytics
SELECT t.T_ID, t.Name, t.Specialization,
       COUNT(DISTINCT s.S_ID) as TotalSessions,
       AVG(s.Duration) as AvgSessionDuration,
       COUNT(DISTINCT wl.M_ID) as UniqueClients
FROM Trainer t
LEFT JOIN Session s ON t.T_ID = s.T_ID
LEFT JOIN WorkoutLog wl ON s.S_ID = wl.S_ID
GROUP BY t.T_ID, t.Name, t.Specialization;

-- Query 4: Member progress summary with analytics
SELECT m.M_ID, m.Name,
       COUNT(wl.L_ID) as TotalWorkouts,
       AVG(wl.Duration) as AvgWorkoutDuration,
       SUM(wl.CaloriesBurnt) as TotalCaloriesBurned,
       MAX(hm.Weight) as CurrentWeight,
       MIN(hm.Weight) as StartingWeight,
       AVG(hm.SleepHours) as AvgSleepHours
FROM Member m
LEFT JOIN WorkoutLog wl ON m.M_ID = wl.M_ID
LEFT JOIN HealthMetrics hm ON m.M_ID = hm.M_ID
WHERE m.M_ID = 1
GROUP BY m.M_ID, m.Name;

-- Query 5: Available sessions with participant count
SELECT s.S_ID, s.Details, s.SessionDate, s.SessionTime, s.Duration,
       t.Name AS TrainerName, t.Specialization,
       COUNT(wl.L_ID) as CurrentParticipants,
       s.MaxParticipants,
       (s.MaxParticipants - COUNT(wl.L_ID)) as AvailableSpots
FROM Session s
JOIN Trainer t ON s.T_ID = t.T_ID
LEFT JOIN WorkoutLog wl ON s.S_ID = wl.S_ID AND wl.Exercise = 'Session Booking'
WHERE s.SessionDate >= CURDATE() AND s.Status = 'scheduled'
GROUP BY s.S_ID, s.Details, s.SessionDate, s.SessionTime, s.Duration, 
         t.Name, t.Specialization, s.MaxParticipants
HAVING AvailableSpots > 0
ORDER BY s.SessionDate, s.SessionTime;

-- Query 6: Upcoming session bookings for a member
SELECT s.S_ID, s.Details, s.SessionDate, s.SessionTime,
       t.Name AS TrainerName, wl.L_ID as BookingID
FROM WorkoutLog wl
JOIN Session s ON wl.S_ID = s.S_ID
JOIN Trainer t ON s.T_ID = t.T_ID
WHERE wl.M_ID = 1 
  AND s.SessionDate >= CURDATE() 
  AND wl.Exercise = 'Session Booking'
ORDER BY s.SessionDate, s.SessionTime;

-- ----------------------------------------------------------------------------
-- UPDATE Operations
-- ----------------------------------------------------------------------------

-- Update 1: Bulk membership renewal dates
UPDATE Member 
SET MembershipEndDate = DATE_ADD(JoinDate, INTERVAL 12 MONTH)
WHERE MembershipType_ID = 1 
  AND MembershipEndDate IS NULL;

-- Update 2: Mark completed sessions
UPDATE Session s
SET Status = 'completed'
WHERE s.SessionDate < CURDATE() 
  AND s.Status = 'scheduled'
  AND EXISTS (SELECT 1 FROM WorkoutLog wl WHERE wl.S_ID = s.S_ID);

-- Update 3: Mark notifications as read
UPDATE Notifications
SET IsRead = TRUE
WHERE M_ID = 1 AND IsRead = FALSE;

-- Update 4: Update member activity status based on last workout
UPDATE Member m
SET IsActive = CASE 
    WHEN (SELECT MAX(Date) FROM WorkoutLog WHERE M_ID = m.M_ID) 
         < DATE_SUB(CURDATE(), INTERVAL 60 DAY) THEN FALSE
    ELSE TRUE
END;

-- ----------------------------------------------------------------------------
-- DELETE Operations
-- ----------------------------------------------------------------------------

-- Delete 1: Remove old read notifications (90+ days old)
DELETE FROM Notifications
WHERE CreatedAt < DATE_SUB(CURDATE(), INTERVAL 90 DAY)
  AND IsRead = TRUE;

-- Delete 2: Remove cancelled sessions older than 30 days
DELETE FROM Session
WHERE Status = 'cancelled' 
  AND SessionDate < DATE_SUB(CURDATE(), INTERVAL 30 DAY);

-- Delete 3: Remove inactive members (Demonstrates CASCADE delete)
-- This will also delete related WorkoutLogs and HealthMetrics due to CASCADE
DELETE FROM Member
WHERE IsActive = FALSE 
  AND DATEDIFF(CURDATE(), JoinDate) > 365;

-- ============================================================================
-- SECTION 3: DCL (Data Control Language)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Create Users for Different Roles
-- ----------------------------------------------------------------------------

-- Admin User - Full privileges
CREATE USER IF NOT EXISTS 'gymfit_admin'@'localhost' 
    IDENTIFIED BY 'secure_admin_password_123';

-- Trainer User - Limited access
CREATE USER IF NOT EXISTS 'gymfit_trainer'@'localhost' 
    IDENTIFIED BY 'secure_trainer_password_456';

-- Member User - Restricted access
CREATE USER IF NOT EXISTS 'gymfit_member'@'localhost' 
    IDENTIFIED BY 'secure_member_password_789';

-- ----------------------------------------------------------------------------
-- Grant Privileges to Admin User
-- ----------------------------------------------------------------------------

-- Grant all privileges on GymFitDB database
GRANT ALL PRIVILEGES ON GymFitDB.* 
    TO 'gymfit_admin'@'localhost';

-- Grant system-level privileges
GRANT CREATE USER, RELOAD, PROCESS ON *.* 
    TO 'gymfit_admin'@'localhost';

-- Allow admin to grant privileges to other users
GRANT GRANT OPTION ON GymFitDB.* 
    TO 'gymfit_admin'@'localhost';

-- ----------------------------------------------------------------------------
-- Grant Privileges to Trainer User
-- ----------------------------------------------------------------------------

-- Session management
GRANT SELECT, INSERT, UPDATE ON GymFitDB.Session 
    TO 'gymfit_trainer'@'localhost';

-- View member information (read-only)
GRANT SELECT ON GymFitDB.Member 
    TO 'gymfit_trainer'@'localhost';

-- View workout logs
GRANT SELECT ON GymFitDB.WorkoutLog 
    TO 'gymfit_trainer'@'localhost';

-- View health metrics
GRANT SELECT ON GymFitDB.HealthMetrics 
    TO 'gymfit_trainer'@'localhost';

-- View gym and membership information
GRANT SELECT ON GymFitDB.Gym 
    TO 'gymfit_trainer'@'localhost';
GRANT SELECT ON GymFitDB.MembershipType 
    TO 'gymfit_trainer'@'localhost';

-- Access to own trainer record
GRANT SELECT, UPDATE ON GymFitDB.Trainer 
    TO 'gymfit_trainer'@'localhost';

-- ----------------------------------------------------------------------------
-- Grant Privileges to Member User
-- ----------------------------------------------------------------------------

-- View own member information
GRANT SELECT ON GymFitDB.Member 
    TO 'gymfit_member'@'localhost';

-- Manage own workout logs
GRANT SELECT, INSERT, UPDATE ON GymFitDB.WorkoutLog 
    TO 'gymfit_member'@'localhost';

-- Manage own health metrics
GRANT SELECT, INSERT ON GymFitDB.HealthMetrics 
    TO 'gymfit_member'@'localhost';

-- View available sessions
GRANT SELECT ON GymFitDB.Session 
    TO 'gymfit_member'@'localhost';

-- View trainers
GRANT SELECT ON GymFitDB.Trainer 
    TO 'gymfit_member'@'localhost';

-- View gym information
GRANT SELECT ON GymFitDB.Gym 
    TO 'gymfit_member'@'localhost';

-- View membership types
GRANT SELECT ON GymFitDB.MembershipType 
    TO 'gymfit_member'@'localhost';

-- Manage own notifications
GRANT SELECT, UPDATE ON GymFitDB.Notifications 
    TO 'gymfit_member'@'localhost';

-- ----------------------------------------------------------------------------
-- Revoke Dangerous Privileges
-- ----------------------------------------------------------------------------

-- Ensure members cannot delete or modify structure
REVOKE DELETE, DROP, ALTER, CREATE ON GymFitDB.* 
    FROM 'gymfit_member'@'localhost';

-- Ensure trainers cannot delete records
REVOKE DELETE ON GymFitDB.* 
    FROM 'gymfit_trainer'@'localhost';

-- Trainers cannot modify database structure
REVOKE DROP, ALTER, CREATE ON GymFitDB.* 
    FROM 'gymfit_trainer'@'localhost';

-- ----------------------------------------------------------------------------
-- Apply Changes
-- ----------------------------------------------------------------------------

FLUSH PRIVILEGES;

-- ----------------------------------------------------------------------------
-- View Granted Privileges (For Verification)
-- ----------------------------------------------------------------------------

-- Show privileges for admin user
SHOW GRANTS FOR 'gymfit_admin'@'localhost';

-- Show privileges for trainer user
SHOW GRANTS FOR 'gymfit_trainer'@'localhost';

-- Show privileges for member user
SHOW GRANTS FOR 'gymfit_member'@'localhost';

-- ============================================================================
-- End of DDL, DML, DCL Scripts
-- ============================================================================

/*
SUMMARY OF OPERATIONS:

DDL (Data Definition Language):
- Created 9 tables: Gym, MembershipType, Member, Trainer, Admin, Session, 
  WorkoutLog, HealthMetrics, Notifications
- Implemented PRIMARY KEY constraints with AUTO_INCREMENT
- Implemented FOREIGN KEY constraints with CASCADE actions
- Implemented CHECK constraints for data validation
- Implemented UNIQUE constraints for email fields
- Implemented ENUM types for status fields

DML (Data Manipulation Language):
- INSERT: Added sample data for all tables
- SELECT: Demonstrated 6 complex queries with JOINs and aggregations
- UPDATE: Demonstrated 4 different update scenarios
- DELETE: Demonstrated 3 delete operations including CASCADE effects

DCL (Data Control Language):
- Created 3 user roles: Admin, Trainer, Member
- Granted appropriate privileges for each role
- Revoked dangerous privileges
- Implemented role-based access control (RBAC)
*/