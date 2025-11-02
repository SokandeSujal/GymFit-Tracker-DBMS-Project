# GymFit Tracker System

## Database Management System Mini Project

**Academic Year:** 2024-2025  
**Institution:** MIT-WPU, School of Computer Science and Engineering  
**Course:** Database Management Systems (DBMS)  
**Review:** Final Review Submission

---

## Team Members

| Name               |
|--------------------|
| Sujal Sokande      |
| Kavya Rane         |
| Megha Mahesh       |
| Raya Gangopadhyay  |

---

## Project Overview

The **GymFit Tracker System** is a comprehensive database-driven application designed to manage gym memberships, trainer schedules, workout sessions, and member progress tracking. The system demonstrates advanced DBMS concepts including normalization, stored procedures, functions, triggers, and role-based access control.

### Key Features

- Multi-role authentication system (Member, Trainer, Admin)
- Comprehensive workout logging and tracking
- Session booking and management
- Health metrics monitoring (weight, sleep, steps, water intake)
- AI-powered fitness recommendations and chatbot
- Progress visualization with interactive charts
- Automated membership renewal notifications
- Real-time analytics and reporting

---

## Technology Stack

### Backend
- **Database:** MySQL 8.0
- **Server Framework:** Python Flask
- **API Design:** RESTful API architecture
- **Authentication:** Session-based with password hashing (werkzeug)
- **AI Integration:** OpenAI GPT-4 API for chatbot

### Frontend
- **Structure:** HTML5
- **Styling:** CSS3 with modern design patterns
- **Interactivity:** Vanilla JavaScript (ES6+)
- **Visualization:** Chart.js for progress charts
- **UI/UX:** Responsive design with glassmorphism effects

### Database Features
- 9 normalized tables (3NF)
- 12+ stored functions
- 15+ stored procedures
- 10+ triggers
- Multiple cursors for batch operations
- Role-based access control (RBAC)

---

## Project Structure

```
GymFit-Tracker-DBMS-Project/
│
├── Documentation/
│   └── GymFit_Tracker_System_DBMS_Mini_Project_Report.pdf
│
├── Frontend/
│   ├── templates/
│   │   └── index.html
│   └── static/
│       ├── style.css
│       └── script.js
│
├── Backend/
│   ├── app.py
│   ├── recommendations.py
│   ├── notifications.py
│   ├── ai_chatbot.py
│   └── mysql_operations.py
│
├── Database_Scripts/
│   ├── DDL_DML_DCL_Scripts.sql
│   ├── Functions_Code.sql
│   ├── Procedures_Code.sql
│   ├── Triggers_Code.sql
│   └── Cursor_Code.sql
│
├── Configuration/
│   ├── .env.example
│   └── requirements.txt
│
└── README.md
```

---

## Database Schema

### Core Tables

1. **Gym** - Gym location and capacity information
2. **MembershipType** - Different membership plans
3. **Member** - Member profiles and credentials
4. **Trainer** - Trainer details and specializations
5. **Admin** - System administrator accounts
6. **Session** - Training sessions scheduled by trainers
7. **WorkoutLog** - Individual workout records
8. **HealthMetrics** - Daily health and activity tracking
9. **Notifications** - Automated alerts and reminders

### Relationships

- One gym offers multiple membership types (1:M)
- One gym hosts multiple members and trainers (1:M)
- One trainer conducts multiple sessions (1:M)
- Members attend sessions (M:M via WorkoutLog)
- Members track multiple health metrics (1:M)

---

## Installation and Setup

### Prerequisites

- Python 3.8 or higher
- MySQL 8.0 or higher
- pip (Python package manager)
- Modern web browser (Chrome, Firefox, Edge)

### Step 1: Database Setup

```sql
-- Execute in MySQL Workbench or command line
mysql -u root -p

-- Run the scripts in order:
SOURCE Database_Scripts/DDL_DML_DCL_Scripts.sql;
SOURCE Database_Scripts/Functions_Code.sql;
SOURCE Database_Scripts/Procedures_Code.sql;
SOURCE Database_Scripts/Triggers_Code.sql;
SOURCE Database_Scripts/Cursor_Code.sql;
```

### Step 2: Backend Configuration

```bash
# Navigate to project directory
cd GymFit-Tracker-DBMS-Project

# Install Python dependencies
pip install -r Configuration/requirements.txt

# Create environment file
cp Configuration/.env.example .env

# Edit .env with your credentials
# DB_HOST=localhost
# DB_USER=root
# DB_PASSWORD=your_password
# DB_NAME=GymFitDB
# SECRET_KEY=your_secret_key
# OPENAI_API_KEY=your_openai_key
```

### Step 3: Run the Application

```bash
# Start Flask server
python Backend/app.py

# Application will run on http://localhost:5000
```

### Step 4: Access the System

1. Open browser and navigate to `http://localhost:5000`
2. Select your role (Member/Trainer/Admin)
3. Use demo credentials provided on login screen

---

## Demo Credentials

### Member Accounts
- **Email:** sujal.sokande@gmail.com | **Password:** theSujal866
- **Email:** priya.d@email.com | **Password:** password123
- **Email:** kavya.rane@gmail.com | **Password:** password123

### Trainer Accounts
- **Email:** joshua.t@gymfit.in | **Password:** password123
- **Email:** anjali.m@gymfit.in | **Password:** password123

### Admin Account
- **Email:** admin@gymfit.in | **Password:** admin123

---

## Key Functionalities

### Member Dashboard
- View personal profile and membership details
- Log daily workouts with exercise details
- Track health metrics (weight, sleep, steps, water)
- Book and manage training sessions
- View progress charts and statistics
- Access AI fitness chatbot (Gold members only)
- Receive personalized workout recommendations

### Trainer Dashboard
- View assigned sessions and participants
- Monitor client workout progress
- Manage session schedules
- Access client statistics and analytics

### Admin Dashboard
- Manage members and trainers (CRUD operations)
- View system-wide statistics and revenue
- Monitor active sessions and memberships
- Generate comprehensive reports
- Trigger membership renewal checks

---

## Database Features Implemented

### Functions (12)
- CheckMembershipExpiry - Calculate days until expiration
- CalculateMemberBMI - Compute Body Mass Index
- GetTotalCaloriesBurned - Total calories in period
- CalculateWorkoutConsistency - Workout frequency percentage
- GetAvgWorkoutDuration - Average workout duration
- IsSessionAvailable - Check session capacity
- CountTrainerActiveSessions - Count upcoming sessions
- CalculateWeightChange - Weight change tracking
- GetAvgDailySteps - Average daily steps
- CalculateGymRevenue - Revenue calculation
- GetMemberAgeGroup - Age categorization
- FormatDurationToTime - Duration formatting

### Procedures (15)
- GetMemberProgressSummary - Comprehensive progress report
- RegisterNewMember - New member registration
- UpdateMemberHealthMetrics - Health data updates
- AddWorkoutLog - Workout recording
- GetMemberWorkoutHistory - Workout history retrieval
- GenerateWorkoutStatistics - Statistical analysis
- BookSessionForMember - Session booking with validation
- GetAvailableSessions - List available sessions
- CancelSessionBooking - Cancel bookings
- GetTrainerDashboard - Trainer analytics
- AddNewSession - Create new sessions
- GenerateSystemStatistics - System-wide stats
- CheckMembershipRenewals - Renewal notifications
- DeactivateExpiredMemberships - Auto-deactivation
- GenerateMonthlyReport - Monthly reporting

### Triggers (10+)
- Auto-set membership end dates
- Validate session capacity before booking
- Update member activity status
- Log membership changes
- Enforce data integrity constraints
- Auto-create notifications
- Cascade delete operations
- Update aggregate statistics

### Cursors (Multiple)
- Batch membership renewal processing
- Bulk notification generation
- Report data aggregation
- Multi-member statistics calculation

---

## API Endpoints

### Authentication
- POST `/api/login` - User authentication
- POST `/api/logout` - User logout

### Member Operations
- GET `/api/dashboard/member/:id` - Member dashboard data
- GET `/api/member/:id/progress` - Progress charts data
- GET `/api/member/:id/recommendations` - AI recommendations
- POST `/api/member/:id/chat` - AI chatbot interaction
- POST `/api/workouts` - Add workout log

### Session Management
- GET `/api/sessions/available` - List available sessions
- POST `/api/sessions/book` - Book session
- POST `/api/sessions/cancel` - Cancel booking

### Trainer Operations
- GET `/api/dashboard/trainer/:id` - Trainer dashboard

### Admin Operations
- GET `/api/dashboard/admin/:id` - Admin dashboard
- POST `/api/admin/member` - Add new member
- POST `/api/admin/trainer` - Add new trainer
- DELETE `/api/admin/member/:id` - Delete member
- DELETE `/api/admin/trainer/:id` - Delete trainer
- POST `/api/admin/check_renewals` - Trigger renewal check

### Notifications
- GET `/api/notifications` - Get user notifications

---

## Security Features

### Password Security
- Passwords hashed using werkzeug.security (scrypt algorithm)
- No plain text password storage
- Secure password verification

### Session Management
- Server-side session storage
- HTTP-only cookies
- Session timeout after 24 hours
- CSRF protection

### Database Security
- Role-based access control (RBAC)
- Prepared statements (SQL injection prevention)
- Input validation and sanitization
- Stored procedure encapsulation

### Access Control
- **Admin:** Full system access
- **Trainer:** Limited to assigned sessions and clients
- **Member:** Personal data access only

---

## Normalization Details

All tables are normalized to **Third Normal Form (3NF)** to eliminate:
- Data redundancy
- Update anomalies
- Insert anomalies
- Delete anomalies

### Normalization Steps
1. **UNF to 1NF:** Eliminated repeating groups, ensured atomic values
2. **1NF to 2NF:** Removed partial dependencies
3. **2NF to 3NF:** Eliminated transitive dependencies

---

## Advanced Features

### AI Integration
- OpenAI GPT-4o-mini powered fitness chatbot
- Context-aware responses based on user data
- Personalized workout and nutrition advice
- Natural language interaction
- Markdown formatting support

### Progress Visualization
- Interactive Chart.js graphs
- Workout frequency tracking
- Weight progress monitoring
- Calorie burn trends
- Real-time data updates

### Automated Notifications
- Membership renewal reminders
- Session booking confirmations
- Progress milestone alerts
- System announcements

### Smart Recommendations
- Rule-based workout suggestions
- Personalized based on activity patterns
- Health metrics analysis
- Exercise variety recommendations

---

## Testing and Validation

### Database Testing
- All functions tested with sample data
- Procedures validated with multiple scenarios
- Triggers verified for correct behavior
- Cursors tested for batch operations

### Application Testing
- API endpoints tested with Postman
- Frontend tested across browsers
- Session management validated
- Error handling verified

### Security Testing
- SQL injection prevention confirmed
- XSS protection validated
- Authentication flow tested
- Authorization checks verified

---

## Future Enhancements

### Planned Features
- Mobile application (iOS/Android)
- Payment gateway integration
- Advanced analytics dashboard
- Meal planning and nutrition tracking
- Social features (member connections)
- Wearable device integration
- Video workout library
- Trainer certification management

### Technical Improvements
- Redis caching for performance
- WebSocket for real-time updates
- Microservices architecture
- Docker containerization
- CI/CD pipeline
- Automated testing suite

---

## Troubleshooting

### Common Issues

**Database Connection Error**
```
Solution: Verify MySQL is running and credentials in .env are correct
```

**Module Not Found Error**
```
Solution: Run 'pip install -r Configuration/requirements.txt'
```

**Session Not Persisting**
```
Solution: Check SECRET_KEY is set in .env file
```

**Charts Not Displaying**
```
Solution: Ensure Chart.js CDN is accessible, check browser console
```

---

## Dependencies

### Python Packages
```
Flask==3.0.0
Flask-CORS==4.0.0
mysql-connector-python==8.2.0
python-dotenv==1.0.0
werkzeug==3.0.1
openai==1.3.0
```

### Frontend Libraries
```
Chart.js v4.4.0 (CDN)
Google Fonts - Inter (CDN)
```

---

## Performance Optimization

### Database Optimization
- Indexed primary and foreign keys
- Optimized query execution plans
- Efficient JOIN operations
- Aggregate function optimization

### Application Optimization
- Connection pooling
- Query result caching
- Lazy loading for charts
- Minimized API calls

---

## Compliance and Standards

### Database Standards
- ANSI SQL compliance
- MySQL 8.0 best practices
- Normalized schema design
- Proper constraint implementation

### Code Standards
- PEP 8 (Python style guide)
- ESLint recommendations (JavaScript)
- Semantic HTML5
- BEM methodology (CSS)

---

## Documentation

### Available Documents
1. **Project Report (PDF)** - Comprehensive technical documentation
2. **Database Schema Diagram** - Visual ER representation
3. **API Documentation** - Endpoint specifications
4. **User Manual** - Step-by-step usage guide
5. **SQL Scripts** - Fully commented database code

---

## License and Usage

This project is submitted as part of academic coursework for the Database Management Systems course at MIT-WPU. The code is provided for educational purposes and evaluation by faculty members.

### Usage Rights
- Academic use permitted
- Commercial use requires permission
- Attribution required for modifications
- Not for redistribution without consent

---

## Acknowledgments

### Faculty Guidance
Special thanks to our DBMS course instructor for guidance and support throughout the project development.

### Resources
- MySQL Official Documentation
- Flask Documentation
- OpenAI API Documentation
- Chart.js Documentation
- Stack Overflow Community

---

## Contact Information

For queries related to this project, please contact:

**Project Lead:** Sujal Sokande  
**Email:** sujal.sokande@gmail.com  
**Institution:** MIT-WPU, Pune

---

## Project Timeline

- **Week 1-2:** Requirements analysis and database design
- **Week 3-4:** Schema implementation and normalization
- **Week 5-6:** Stored procedures, functions, and triggers
- **Week 7-8:** Backend API development
- **Week 9-10:** Frontend development and integration
- **Week 11:** Testing, debugging, and optimization
- **Week 12:** Documentation and final submission

---

## Version History

### Version 1.0.0 (Current)
- Initial release for Review 2
- Complete database implementation
- Functional frontend and backend
- All DBMS features implemented
- Documentation completed

---

## Submission Checklist

- [x] Mini Project Report (PDF)
- [x] Frontend Files (HTML, CSS, JS)
- [x] DDL, DML, DCL Scripts
- [x] Functions Code
- [x] Procedures Code
- [x] Triggers Code
- [x] Cursor Code
- [x] Backend Python Files
- [x] Configuration Files
- [x] README Documentation

---

**Project Status:** Ready for Submission  
**Last Updated:** November 2025  
**Submission Date:** As per course schedule

---

END OF DOCUMENTATION
