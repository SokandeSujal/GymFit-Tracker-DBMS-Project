// API Base URL - use relative path since we're on same origin
const API_BASE = '/api';

// Current user data
let currentUser = null;
let currentRole = null;

// Demo credentials for each role
const DEMO_CREDENTIALS = {
    member: [
        { email: 'sujal.sokande@gmail.com', password: 'theSujal866' },
        { email: 'priya.d@email.com', password: 'password123' },
        { email: 'kavya.rane@gmail.com', password: 'password123' }
    ],
    trainer: [
        { email: 'joshua.t@gymfit.in', password: 'password123' },
        { email: 'anjali.m@gymfit.in', password: 'password123' }
    ],
    admin: [
        { email: 'admin@gymfit.in', password: 'admin123' }
    ]
};

// --- App Initialization ---
document.addEventListener('DOMContentLoaded', () => {
    initEventListeners();
    checkLoginStatus();
    updateDemoCredentials();
});

function initEventListeners() {
    // Role selection
    document.querySelectorAll('.role-option').forEach(option => {
        option.addEventListener('click', handleRoleSelection);
    });

    // Back to role selection
    document.getElementById('backToRole')?.addEventListener('click', showRoleSelection);

    // Login form
    document.getElementById('loginForm')?.addEventListener('submit', handleLogin);

    // Logout buttons
    document.querySelectorAll('[id$="LogoutBtn"]').forEach(btn => {
        btn.addEventListener('click', handleLogout);
    });

    // Modals
    document.getElementById('addWorkoutBtn')?.addEventListener('click', () => openModal('workoutModal'));
    document.getElementById('bookSessionBtn')?.addEventListener('click', () => openModal('sessionModal'));
    document.querySelectorAll('.modal-close, .modal-cancel').forEach(el => {
        el.addEventListener('click', () => closeModal(el.closest('.modal').id));
    });

    // Forms
    document.getElementById('workoutForm')?.addEventListener('submit', handleAddWorkout);

    // Set today's date as default for workout form
    const workoutDate = document.getElementById('workoutDate');
    if (workoutDate) {
        workoutDate.valueAsDate = new Date();
    }

    // Click outside modal to close
    window.addEventListener('click', (e) => {
        if (e.target.classList.contains('modal')) {
            closeModal(e.target.id);
        }
    });

    // Add Member/Trainer forms
    document.getElementById('addMemberForm')?.addEventListener('submit', handleAddMember);
    document.getElementById('addTrainerForm')?.addEventListener('submit', handleAddTrainer);

    // Chatbot
    document.getElementById('openChatbotBtn')?.addEventListener('click', openChatbot);
    document.getElementById('sendChatBtn')?.addEventListener('click', sendChatMessage);
    document.getElementById('chatInput')?.addEventListener('keypress', (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            sendChatMessage();
        }
    });
}

// --- UI Navigation & State ---

function showScreen(screenId) {
    document.querySelectorAll('.screen').forEach(screen => screen.classList.remove('active'));
    document.getElementById(screenId)?.classList.add('active');
}

function showRoleSelection() {
    currentRole = null;
    showScreen('roleScreen');
}

function showLogin() {
    showScreen('loginScreen');
    updateDemoCredentials();
}

function showDashboard(role, userId) {
    const dashboardId = `${role}Dashboard`;
    showScreen(dashboardId);
    loadDashboard(role, userId);
}

function checkLoginStatus() {
    const userId = sessionStorage.getItem('user_id');
    const userRole = sessionStorage.getItem('user_role');
    
    if (userId && userRole) {
        currentUser = { id: parseInt(userId), role: userRole, name: sessionStorage.getItem('user_name') };
        currentRole = userRole;
        showDashboard(userRole, userId);
    } else {
        showRoleSelection();
    }
}

function handleRoleSelection(e) {
    currentRole = e.currentTarget.getAttribute('data-role');
    const roleName = currentRole.charAt(0).toUpperCase() + currentRole.slice(1);
    
    document.getElementById('loginRoleTitle').textContent = `${roleName} Login`;
    document.getElementById('loginRoleSubtitle').textContent = `Access your ${currentRole} dashboard`;
    
    showLogin();
}

// --- API & Data Handling ---

async function apiRequest(endpoint, method = 'GET', body = null) {
    const loader = document.getElementById('loader');
    if (loader) loader.classList.add('active');

    const options = {
        method,
        headers: { 
            'Content-Type': 'application/json'
        },
        credentials: 'same-origin'
    };
    if (body) {
        options.body = JSON.stringify(body);
    }

    try {
        const response = await fetch(`${API_BASE}${endpoint}`, options);
        const data = await response.json();
        
        if (response.status === 401) {
            if (!endpoint.includes('/login')) {
                handleLogout();
                showNotification('Your session has expired. Please log in again.', 'error');
            }
            return null;
        }
        
        if (!response.ok) {
            throw new Error(data.error || `HTTP error! status: ${response.status}`);
        }
        return data;
    } catch (error) {
        console.error('API Request Error:', error);
        showNotification(error.message, 'error');
        return null;
    } finally {
        if (loader) loader.classList.remove('active');
    }
}

async function handleLogin(e) {
    e.preventDefault();
    const email = document.getElementById('email').value.trim();
    const password = document.getElementById('password').value;
    const errorDiv = document.getElementById('loginError');
    errorDiv.textContent = '';

    if (!currentRole) {
        errorDiv.textContent = 'Please select a role first.';
        return;
    }

    const data = await apiRequest('/login', 'POST', { email, password, role: currentRole });

    if (data && data.success) {
        sessionStorage.setItem('user_id', data.user_id);
        sessionStorage.setItem('user_role', data.role);
        sessionStorage.setItem('user_name', data.name);
        
        currentUser = { id: data.user_id, role: data.role, name: data.name };
        showNotification(`Welcome back, ${data.name}!`);
        
        setTimeout(() => {
            showDashboard(data.role, data.user_id);
        }, 100);
    } else {
        errorDiv.textContent = data?.error || 'Login failed. Please check your credentials.';
    }
}

async function handleLogout() {
    await apiRequest('/logout', 'POST');
    sessionStorage.clear();
    currentUser = null;
    currentRole = null;
    destroyAllCharts();
    showRoleSelection();
    showNotification('Logged out successfully');
}

async function loadDashboard(role, userId) {
    const data = await apiRequest(`/dashboard/${role}/${userId}`);
    if (data) {
        updateDashboardUI(role, data);
        loadNotifications(role);
        if (role === 'member') {
            loadProgressCharts(userId);
            loadRecommendations(userId);
        }
    }
}

// --- Dashboard UI Updates ---

function updateDashboardUI(role, data) {
    if (role === 'member') updateMemberDashboard(data);
    else if (role === 'trainer') updateTrainerDashboard(data);
    else if (role === 'admin') updateAdminDashboard(data);
}

function updateMemberDashboard(data) {
    const { member, healthMetrics, recentWorkouts, upcomingSessions } = data;
    document.getElementById('userName').textContent = `Hello, ${member?.Name || 'Member'}`;
    
    // Populate profile card
    document.getElementById('memberName').textContent = member?.Name || 'N/A';
    document.getElementById('memberEmail').textContent = member?.Email || 'N/A';
    document.getElementById('memberAge').textContent = `Age ${member?.Age || 'N/A'}`;
    document.getElementById('memberHeight').textContent = `Height ${healthMetrics?.Height || 'N/A'} cm`;
    document.getElementById('memberWeight').textContent = `Weight ${healthMetrics?.Weight || 'N/A'} kg`;

    // Populate stats
    document.getElementById('sleepHours').textContent = healthMetrics?.SleepHours || 0;
    document.getElementById('waterLiters').textContent = healthMetrics?.WaterLiters || 0;
    document.getElementById('walkingSteps').textContent = healthMetrics?.Steps || 0;

    // Populate recent workouts
    const workoutsList = document.getElementById('recentWorkoutsList');
    if (workoutsList) {
        workoutsList.innerHTML = recentWorkouts?.length ? recentWorkouts.map(w => `
            <div class="workout-item">
                <div class="workout-info">
                    <h4>${escapeHtml(w.Exercise)}</h4>
                    <div class="workout-meta">${formatDate(w.Date)}</div>
                </div>
                <div class="workout-stats">
                    <div class="workout-stat"><span>${w.Duration || 0}</span><span>mins</span></div>
                    <div class="workout-stat"><span>${Math.round(w.CaloriesBurnt || 0)}</span><span>cal</span></div>
                </div>
            </div>
        `).join('') : '<div class="empty-state">No recent workouts</div>';
    }

    // Populate upcoming sessions
    const sessionsList = document.getElementById('upcomingSessionsList');
    if (sessionsList) {
        sessionsList.innerHTML = upcomingSessions?.length ? upcomingSessions.map(s => `
            <div class="session-item">
                <div class="session-info">
                    <h4>${escapeHtml(s.Details)}</h4>
                    <div class="session-meta">${formatDate(s.SessionDate)} at ${formatTime(s.SessionTime)}</div>
                </div>
                <button class="btn-danger" onclick="cancelSession(${s.BookingID})">Cancel</button>
            </div>
        `).join('') : '<div class="empty-state">No upcoming sessions</div>';
    }
}

function updateTrainerDashboard(data) {
    const { trainer, stats, sessions, clients } = data;
    document.getElementById('trainerName').textContent = `Hello, ${trainer?.Name || 'Trainer'}`;
    document.getElementById('totalClients').textContent = stats?.totalClients || 0;
    document.getElementById('todaySessions').textContent = stats?.sessionsToday || 0;

    const sessionsList = document.getElementById('trainerSessionsList');
    if (sessionsList) {
        sessionsList.innerHTML = sessions?.length ? sessions.map(s => `
            <div class="session-item">
                <div class="session-info">
                    <h4>${escapeHtml(s.Details)}</h4>
                    <div class="session-meta">${formatDate(s.SessionDate)} at ${formatTime(s.SessionTime)} • ${s.participantCount}/${s.MaxParticipants} participants</div>
                </div>
                <span style="font-size: 12px; color: var(--text-muted);">Status: ${s.Status || 'Scheduled'}</span>
            </div>
        `).join('') : '<div class="empty-state">No sessions scheduled</div>';
    }

    const clientsList = document.getElementById('trainerClientsList');
    if (clientsList) {
        clientsList.innerHTML = clients?.length ? clients.map(c => `
            <div class="client-item">
                <div>
                    <strong>${escapeHtml(c.Name)}</strong>
                    <div style="font-size: 12px; color: var(--text-muted);">Last workout: ${c.lastWorkout ? formatDate(c.lastWorkout) : 'N/A'}</div>
                </div>
            </div>
        `).join('') : '<div class="empty-state">No clients found</div>';
    }
}

function updateAdminDashboard(data) {
    const { stats, members, trainers } = data;
    document.getElementById('adminName').textContent = `Hello, ${currentUser?.name || 'Admin'}`;
    document.getElementById('totalMembers').textContent = stats?.totalMembers || 0;
    document.getElementById('totalTrainers').textContent = stats?.totalTrainers || 0;
    document.getElementById('activeSessions').textContent = stats?.activeSessions || 0;
    document.getElementById('revenue').textContent = `₹${(stats?.totalRevenue || 0).toLocaleString()}`;

    const membersList = document.getElementById('adminMembersList');
    if (membersList) {
        membersList.innerHTML = members?.length ? members.map(m => `
            <div class="user-item">
                <div>
                    <strong>${escapeHtml(m.Name)}</strong> - ${escapeHtml(m.MembershipType || 'N/A')}
                    <div style="font-size: 12px; color: var(--text-muted);">${m.Email} • Joined: ${formatDate(m.JoinDate)}</div>
                </div>
                <div>
                    <button class="btn-danger" onclick="deleteUser('member', ${m.M_ID})">Delete</button>
                </div>
            </div>
        `).join('') : '<div class="empty-state">No members found</div>';
    }

    const trainersList = document.getElementById('adminTrainersList');
    if (trainersList) {
        trainersList.innerHTML = trainers?.length ? trainers.map(t => `
            <div class="user-item">
                <div>
                    <strong>${escapeHtml(t.Name)}</strong> - ${escapeHtml(t.Specialization || 'N/A')}
                    <div style="font-size: 12px; color: var(--text-muted);">${t.Email} • Clients: ${t.clientCount || 0}</div>
                </div>
                <div>
                    <button class="btn-danger" onclick="deleteUser('trainer', ${t.T_ID})">Delete</button>
                </div>
            </div>
        `).join('') : '<div class="empty-state">No trainers found</div>';
    }
}

// --- Modal & Form Logic ---

function openModal(modalId) {
    if (modalId === 'sessionModal') {
        loadAvailableSessions();
    }
    const modal = document.getElementById(modalId);
    if (modal) modal.classList.add('active');
}

function closeModal(modalId) {
    const modal = document.getElementById(modalId);
    if (modal) {
        modal.classList.remove('active');
        const form = modal.querySelector('form');
        if (form) form.reset();
        if (modalId === 'workoutModal') {
            const workoutDate = document.getElementById('workoutDate');
            if (workoutDate) workoutDate.valueAsDate = new Date();
        }
    }
}

async function handleAddWorkout(e) {
    e.preventDefault();
    const workoutData = {
        exercise: document.getElementById('exerciseName').value.trim(),
        date: document.getElementById('workoutDate').value,
        duration: parseInt(document.getElementById('duration').value),
        calories: parseInt(document.getElementById('calories').value) || null,
        distance: parseFloat(document.getElementById('distance').value) || null,
        progress: document.getElementById('progress').value.trim()
    };

    if (!workoutData.exercise || !workoutData.date || !workoutData.duration) {
        showNotification('Please fill in all required fields', 'error');
        return;
    }

    const data = await apiRequest('/workouts', 'POST', workoutData);
    if (data && data.success) {
        closeModal('workoutModal');
        loadDashboard(currentUser.role, currentUser.id);
        showNotification('Workout added successfully!');
    }
}

async function loadAvailableSessions() {
    const data = await apiRequest('/sessions/available');
    const sessionList = document.getElementById('availableSessionsList');
    if (data && data.sessions && sessionList) {
        sessionList.innerHTML = data.sessions.length ? data.sessions.map(session => `
            <div class="session-item">
                <div class="session-info">
                    <h4>${escapeHtml(session.Details)}</h4>
                    <div class="session-meta">
                        ${formatDate(session.SessionDate)} at ${formatTime(session.SessionTime)}<br>
                        Trainer: ${escapeHtml(session.TrainerName)} (${escapeHtml(session.Specialization)})<br>
                        Spots: ${session.participantCount}/${session.MaxParticipants}
                    </div>
                </div>
                <button class="btn-primary" onclick="bookSession(${session.S_ID})">Book</button>
            </div>
        `).join('') : '<div class="empty-state">No sessions available at the moment.</div>';
    }
}

async function bookSession(sessionId) {
    const data = await apiRequest('/sessions/book', 'POST', { session_id: sessionId });
    if (data && data.success) {
        closeModal('sessionModal');
        loadDashboard(currentUser.role, currentUser.id);
        showNotification('Session booked successfully!');
    }
}

async function cancelSession(bookingId) {
    if (!confirm('Are you sure you want to cancel this session booking?')) return;
    const data = await apiRequest('/sessions/cancel', 'POST', { booking_id: bookingId });
    if (data && data.success) {
        loadDashboard(currentUser.role, currentUser.id);
        showNotification('Session booking canceled.');
    }
}

async function deleteUser(role, userId) {
    if (!confirm(`Are you sure you want to delete this ${role}? This action cannot be undone.`)) return;
    const data = await apiRequest(`/admin/${role}/${userId}`, 'DELETE');
    if (data && data.success) {
        loadDashboard(currentUser.role, currentUser.id);
        showNotification(`${role.charAt(0).toUpperCase() + role.slice(1)} deleted successfully.`);
    }
}

async function openAddMemberModal() {
    openModal('addMemberModal');
}

async function openAddTrainerModal() {
    openModal('addTrainerModal');
}

async function handleAddMember(e) {
    e.preventDefault();
    const memberData = {
        name: document.getElementById('newMemberName').value.trim(),
        email: document.getElementById('newMemberEmail').value.trim(),
        password: document.getElementById('newMemberPassword').value,
        age: parseInt(document.getElementById('newMemberAge').value),
        phone: document.getElementById('newMemberPhone').value.trim(),
        membership_type_id: parseInt(document.getElementById('newMemberMembershipType').value),
        gym_id: parseInt(document.getElementById('newMemberGym').value)
    };

    if (!memberData.name || !memberData.email || !memberData.password || !memberData.age) {
        showNotification('Please fill in all required fields', 'error');
        return;
    }

    const data = await apiRequest('/admin/member', 'POST', memberData);
    if (data && data.success) {
        closeModal('addMemberModal');
        loadDashboard(currentUser.role, currentUser.id);
        showNotification('Member added successfully!');
    }
}

async function handleAddTrainer(e) {
    e.preventDefault();
    const trainerData = {
        name: document.getElementById('newTrainerName').value.trim(),
        email: document.getElementById('newTrainerEmail').value.trim(),
        password: document.getElementById('newTrainerPassword').value,
        specialization: document.getElementById('newTrainerSpecialization').value.trim(),
        gym_id: parseInt(document.getElementById('newTrainerGym').value)
    };

    if (!trainerData.name || !trainerData.email || !trainerData.password || !trainerData.specialization) {
        showNotification('Please fill in all required fields', 'error');
        return;
    }

    const data = await apiRequest('/admin/trainer', 'POST', trainerData);
    if (data && data.success) {
        closeModal('addTrainerModal');
        loadDashboard(currentUser.role, currentUser.id);
        showNotification('Trainer added successfully!');
    }
}

async function sendChatMessage() {
    const input = document.getElementById('chatInput');
    const question = input.value.trim();
    
    if (!question) {
        showNotification('Please enter a question', 'error');
        return;
    }

    // Add user message to chat
    addChatMessage(question, 'user');
    input.value = '';

    // Show typing indicator
    const chatMessages = document.getElementById('chatMessages');
    const typingDiv = document.createElement('div');
    typingDiv.className = 'chat-message bot typing';
    typingDiv.innerHTML = '<div class="message-content"><div class="typing-indicator"><span></span><span></span><span></span></div></div>';
    typingDiv.id = 'typingIndicator';
    chatMessages.appendChild(typingDiv);
    chatMessages.scrollTop = chatMessages.scrollHeight;

    // Send to API
    const data = await apiRequest(`/member/${currentUser.id}/chat`, 'POST', { question });
    
    // Remove typing indicator
    document.getElementById('typingIndicator')?.remove();

    if (data && data.success) {
        addChatMessage(data.response, 'bot', data.isMarkdown);
    } else if (data && data.error) {
        addChatMessage(data.error, 'bot', false);
    }
}

function addChatMessage(message, type, isMarkdown = false) {
    const chatMessages = document.getElementById('chatMessages');
    const messageDiv = document.createElement('div');
    messageDiv.className = `chat-message ${type}`;
    
    let formattedMessage = message;
    
    // Convert markdown to HTML if needed
    if (isMarkdown) {
        formattedMessage = parseMarkdown(message);
    } else {
        formattedMessage = message.replace(/\n/g, '<br>');
    }
    
    messageDiv.innerHTML = `
        <div class="message-content">${formattedMessage}</div>
        <div class="message-time">${new Date().toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })}</div>
    `;
    
    chatMessages.appendChild(messageDiv);
    chatMessages.scrollTop = chatMessages.scrollHeight;
}

function parseMarkdown(text) {
    // Headers
    text = text.replace(/^### (.*$)/gim, '<h3>$1</h3>');
    text = text.replace(/^## (.*$)/gim, '<h2>$1</h2>');
    text = text.replace(/^# (.*$)/gim, '<h1>$1</h1>');
    
    // Bold
    text = text.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
    
    // Italic
    text = text.replace(/\*(.+?)\*/g, '<em>$1</em>');
    
    // Unordered lists
    text = text.replace(/^\- (.+)$/gim, '<li>$1</li>');
    text = text.replace(/(<li>.*<\/li>)/s, '<ul>$1</ul>');
    
    // Numbered lists
    text = text.replace(/^\d+\.\s(.+)$/gim, '<li>$1</li>');
    
    // Code blocks
    text = text.replace(/```([\s\S]*?)```/g, '<pre><code>$1</code></pre>');
    
    // Inline code
    text = text.replace(/`(.+?)`/g, '<code>$1</code>');
    
    // Line breaks
    text = text.replace(/\n\n/g, '<br><br>');
    text = text.replace(/\n/g, '<br>');
    
    return text;
}

function openChatbot() {
    openModal('chatbotModal');
    // Initialize with welcome message if chat is empty
    const chatMessages = document.getElementById('chatMessages');
    if (chatMessages && chatMessages.children.length === 0) {
        const welcomeMsg = `👋 **Hello ${currentUser.name}!** I'm your AI fitness assistant powered by advanced AI.

I can help you with:
- 📊 Analyzing your workout progress
- 🎯 Creating personalized workout plans
- 💪 Providing exercise recommendations
- 📈 Tracking your health metrics
- 🥗 Nutrition and diet advice
- 😴 Sleep and recovery tips

Ask me anything about your fitness journey!`;
        addChatMessage(welcomeMsg, 'bot', true);
    }
}

// --- Utility Functions ---

function escapeHtml(text) {
    if (!text) return '';
    const map = {
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#039;'
    };
    return text.toString().replace(/[&<>"']/g, m => map[m]);
}

function formatDate(dateString) {
    if (!dateString) return 'N/A';
    try {
        return new Date(dateString).toLocaleDateString('en-US', { 
            month: 'short', 
            day: 'numeric', 
            year: 'numeric' 
        });
    } catch (e) {
        return 'Invalid Date';
    }
}

function formatTime(timeString) {
    if (!timeString) return 'N/A';
    try {
        const [hours, minutes] = timeString.split(':');
        const date = new Date();
        date.setHours(parseInt(hours), parseInt(minutes));
        return date.toLocaleTimeString('en-US', { 
            hour: 'numeric', 
            minute: '2-digit', 
            hour12: true 
        });
    } catch (e) {
        return 'Invalid Time';
    }
}

function showNotification(message, type = 'success') {
    const notification = document.createElement('div');
    notification.className = `notification ${type}`;
    notification.textContent = message;
    document.body.appendChild(notification);
    setTimeout(() => notification.remove(), 3000);
}

function updateDemoCredentials() {
    const demoContainer = document.getElementById('demoCredentials');
    if (!demoContainer || !currentRole) return;

    let html = '<h5>Demo Credentials for ' + currentRole.charAt(0).toUpperCase() + currentRole.slice(1) + '</h5>';
    if (DEMO_CREDENTIALS[currentRole]) {
        DEMO_CREDENTIALS[currentRole].forEach(cred => {
            html += `<p><b>Email:</b> ${cred.email}<br><b>Password:</b> ${cred.password}</p>`;
        });
    }
    demoContainer.innerHTML = html;
}

// --- Chart Rendering ---

let chartInstances = {};

function destroyAllCharts() {
    Object.values(chartInstances).forEach(chart => {
        try {
            chart.destroy();
        } catch (e) {
            console.error('Error destroying chart:', e);
        }
    });
    chartInstances = {};
}

async function loadProgressCharts(memberId) {
    const data = await apiRequest(`/member/${memberId}/progress`);
    if (data) {
        renderWorkoutFrequencyChart(data.workoutFrequency || []);
        renderWeightProgressChart(data.weightProgress || []);
        renderCalorieTrendChart(data.calorieTrend || []);
    }
}

function renderWorkoutFrequencyChart(data) {
    const chartId = 'workoutFrequencyChart';
    const canvas = document.getElementById(chartId);
    if (!canvas) return;

    if (chartInstances[chartId]) {
        chartInstances[chartId].destroy();
    }

    const ctx = canvas.getContext('2d');
    chartInstances[chartId] = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: data.map(d => formatDate(d.Date)),
            datasets: [{
                label: 'Workouts',
                data: data.map(d => d.workout_count),
                backgroundColor: 'rgba(79, 70, 229, 0.7)',
                borderColor: 'rgba(79, 70, 229, 1)',
                borderWidth: 1
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    display: false
                }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    ticks: {
                        stepSize: 1
                    }
                }
            }
        }
    });
}

function renderWeightProgressChart(data) {
    const chartId = 'weightProgressChart';
    const canvas = document.getElementById(chartId);
    if (!canvas) return;

    if (chartInstances[chartId]) {
        chartInstances[chartId].destroy();
    }

    const ctx = canvas.getContext('2d');
    chartInstances[chartId] = new Chart(ctx, {
        type: 'line',
        data: {
            labels: data.map(d => formatDate(d.Date)),
            datasets: [{
                label: 'Weight (kg)',
                data: data.map(d => d.Weight),
                borderColor: 'rgba(79, 70, 229, 1)',
                backgroundColor: 'rgba(79, 70, 229, 0.1)',
                fill: true,
                tension: 0.3
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    display: false
                }
            },
            scales: {
                y: {
                    beginAtZero: false
                }
            }
        }
    });
}

function renderCalorieTrendChart(data) {
    const chartId = 'calorieTrendChart';
    const canvas = document.getElementById(chartId);
    if (!canvas) return;

    if (chartInstances[chartId]) {
        chartInstances[chartId].destroy();
    }

    const ctx = canvas.getContext('2d');
    chartInstances[chartId] = new Chart(ctx, {
        type: 'line',
        data: {
            labels: data.map(d => formatDate(d.Date)),
            datasets: [{
                label: 'Calories Burnt',
                data: data.map(d => d.daily_calories),
                borderColor: 'rgba(5, 150, 105, 1)',
                backgroundColor: 'rgba(5, 150, 105, 0.1)',
                fill: true,
                tension: 0.3
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    display: false
                }
            },
            scales: {
                y: {
                    beginAtZero: true
                }
            }
        }
    });
}

async function loadRecommendations(memberId) {
    const data = await apiRequest(`/member/${memberId}/recommendations`);
    const recommendationsList = document.getElementById('recommendationsList');
    if (data && data.recommendations && recommendationsList) {
        recommendationsList.innerHTML = data.recommendations.length ? data.recommendations.map(rec => `
            <div class="recommendation-item">
                <div class="recommendation-info">
                    <h4>${escapeHtml(rec.exercise || 'Recommendation')}</h4>
                    <p>${escapeHtml(rec.message)}</p>
                </div>
                <div class="recommendation-details">
                    <span>${rec.duration || 0} mins</span>
                </div>
            </div>
        `).join('') : '<div class="empty-state">No recommendations available. Keep tracking your workouts!</div>';
    }
}

async function loadNotifications(role) {
    const data = await apiRequest('/notifications');
    if (data && data.notifications) {
        const unreadCount = data.notifications.filter(n => !n.IsRead).length;
        const badge = document.getElementById(`${role}NotificationBadge`);
        if (badge) {
            if (unreadCount > 0) {
                badge.textContent = unreadCount;
                badge.style.display = 'flex';
            } else {
                badge.style.display = 'none';
            }
        }
    }
}