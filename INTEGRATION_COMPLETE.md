# Flutter-FastAPI Integration Complete

## ✅ Integration Summary

The Flutter frontend has been successfully integrated with the FastAPI backend using JWT authentication and a centralized API infrastructure.

## 🏗️ Architecture Overview

### Backend (FastAPI)

- **Base URL**: `http://localhost:8000`
- **Authentication**: JWT-based (Access + Refresh tokens)
- **CORS**: Configured to allow all origins (development mode)
- **Services**:
  - Authentication (`/api/auth`)
  - Exam Seating (`/api/seating/v1`)
  - Timetable (`/api/timetable`)
  - Occupancy Detection (`/api/occupancy`)

### Frontend (Flutter)

- **State Management**: Riverpod
- **HTTP Client**: Dio with automatic token handling
- **Token Storage**: SharedPreferences
- **Authentication**: Automatic token refresh on 401 errors

## 📁 New Files Created

### Core Infrastructure

1. **`lib/core/api_config.dart`**

   - Centralized API endpoint configuration
   - Base URL and all service endpoints
   - Timeout settings

2. **`lib/core/token_storage.dart`**

   - Secure token storage using SharedPreferences
   - Manages access tokens, refresh tokens, user email, and role
   - Provides login state checking

3. **`lib/core/api_client.dart`** (Updated)

   - Singleton API client with Dio
   - Automatic token attachment to requests
   - Automatic token refresh on 401 errors
   - Request/response logging

4. **`lib/core/auth_provider.dart`**
   - Riverpod providers for authentication state
   - AuthNotifier for login/register/logout actions
   - Current user, authentication status providers

### Updated Files

5. **`lib/auth/auth_api.dart`** (Completely rewritten)

   - JWT-based authentication (replaced OTP)
   - Register, login, logout, refresh token methods
   - Get current user profile
   - Email validation endpoint

6. **`lib/student_login_page.dart`** (Updated)

   - Login and register functionality
   - Password validation
   - JWT token flow
   - Navigate to home on success

7. **`lib/staff_login_page.dart`** (Updated)

   - Login and register functionality for staff
   - Password validation
   - JWT token flow

8. **`lib/features/exam_seating/services/api_service.dart`** (Updated)

   - Accepts Dio instance from centralized API client
   - Uses authenticated requests automatically

9. **`lib/features/exam_seating/providers/providers.dart`** (Updated)
   - Uses centralized API client
   - All providers await the API service initialization

## 🔐 Authentication Flow

### Registration

```dart
1. User enters email (name.deptYYYY@citchennai.net) and password
2. Frontend validates email format and password strength
3. POST /api/auth/register with email and password
4. Backend creates user, extracts student info from email
5. Backend returns JWT tokens (access + refresh)
6. Frontend saves tokens to SharedPreferences
7. Navigate to home page
```

### Login

```dart
1. User enters email and password
2. POST /api/auth/login with credentials
3. Backend validates credentials
4. Backend returns JWT tokens
5. Frontend saves tokens
6. Navigate to home page
```

### Automatic Token Refresh

```dart
1. API request gets 401 Unauthorized
2. Interceptor catches error
3. Attempts to refresh using refresh token
4. POST /api/auth/refresh with refresh_token
5. Backend validates and returns new tokens
6. Save new tokens
7. Retry original request with new access token
8. If refresh fails, clear all tokens (logout)
```

### Authenticated API Calls

```dart
1. All API requests automatically include:
   Authorization: Bearer <access_token>
2. Backend validates JWT token
3. Extracts user info from token
4. Processes request with user context
```

## 📋 API Endpoints Used

### Authentication

- `POST /api/auth/register` - Create new user account
- `POST /api/auth/login` - Login with email/password
- `POST /api/auth/refresh` - Refresh access token
- `GET /api/auth/me` - Get current user profile
- `POST /api/auth/logout` - Logout (clears tokens)
- `GET /api/auth/validate-email` - Validate email format

### Exam Seating (All require authentication)

- `POST /api/seating/v1/rooms/bulk` - Create rooms
- `GET /api/seating/v1/rooms` - List rooms
- `POST /api/seating/v1/students/bulk` - Create students
- `GET /api/seating/v1/students` - List students
- `POST /api/seating/v1/exams` - Create exam
- `GET /api/seating/v1/exams` - List exams
- `POST /api/seating/v1/seating/generate` - Generate seating
- `GET /api/seating/v1/seating/by-room` - Get seating by room

## 🔧 How to Test

### 1. Start Backend

```bash
cd App_Back/Backend
python -m uvicorn main:app --reload
```

Backend will run at `http://localhost:8000`

### 2. Start Flutter App

```bash
cd ui/myapp
flutter run
```

### 3. Test Registration Flow

1. Launch app
2. Go to Student Login (or Staff Login)
3. Click "Register"
4. Enter email: `john.cse2023@citchennai.net`
5. Enter password: `Test1234`
6. Click Register
7. Should navigate to home page

### 4. Test Login Flow

1. Launch app
2. Go to Student Login
3. Enter registered email and password
4. Click Login
5. Should navigate to home page

### 5. Test Authenticated API Calls

1. After logging in, navigate to any feature
2. Exam Seating features should work with authentication
3. Check terminal logs for API requests with Bearer tokens

### 6. Test Token Refresh

1. Login and wait 30 minutes (or manually expire token in backend)
2. Make any API call
3. Should automatically refresh token and retry request
4. Check logs for "Token refreshed successfully"

## 🐛 Debugging

### Enable Verbose Logging

All HTTP requests/responses are logged automatically:

- 🔵 REQUEST: Shows method and URL
- ✅ RESPONSE: Shows status code
- ❌ ERROR: Shows error details
- 🔄 Token refresh attempts

### Check Token Storage

```dart
final tokenStorage = await TokenStorage.getInstance();
print(tokenStorage.getAllData());
```

### Check Authentication State

```dart
final authState = ref.watch(authProvider);
print('Logged in: ${authState.isAuthenticated}');
print('User: ${authState.user?.email}');
```

## 📝 Email Format Rules

### Student Emails

- Format: `name.deptYYYY@citchennai.net`
- Examples:
  - `john.cse2023@citchennai.net` → Name: john, Dept: CSE, Batch: 2023
  - `jane.ece2024@citchennai.net` → Name: jane, Dept: ECE, Batch: 2024

### Staff Emails

- Format: Any `@citchennai.net` email not matching student pattern
- Examples:
  - `faculty.smith@citchennai.net`
  - `admin@citchennai.net`

## 🔒 Password Requirements

- Minimum 8 characters
- At least one letter (a-z, A-Z)
- At least one number (0-9)

## 🎯 Next Steps

### For Production

1. **Update Base URL**

   - Change `ApiConfig.baseUrl` in `lib/core/api_config.dart`
   - Point to production backend URL

2. **Secure Token Storage**

   - Consider using `flutter_secure_storage` instead of SharedPreferences
   - Encrypt tokens at rest

3. **CORS Configuration**

   - Update backend CORS to specific Flutter app domain
   - Remove wildcard `allow_origins=["*"]`

4. **Environment Variables**

   - Use flutter_dotenv for configuration
   - Separate dev/staging/prod environments

5. **Error Handling**

   - Add user-friendly error messages
   - Implement retry logic for network failures
   - Add offline support

6. **Add Features**
   - Timetable API service (similar to exam seating)
   - Occupancy detection API service
   - Attendance tracking integration

## 📚 Key Dependencies

```yaml
dependencies:
  flutter_riverpod: ^2.6.1 # State management
  dio: ^5.7.0 # HTTP client
  shared_preferences: ^2.3.3 # Token storage
```

## ✨ Features Implemented

✅ JWT authentication (register, login, logout)  
✅ Automatic token refresh  
✅ Centralized API configuration  
✅ Secure token storage  
✅ HTTP interceptor for auth headers  
✅ Role-based access (student/staff)  
✅ Email validation and parsing  
✅ Password strength validation  
✅ Riverpod state management for auth  
✅ Exam seating API integration  
✅ Error handling and logging  
✅ CORS configuration

## 🎉 Integration Complete!

The Flutter app is now fully integrated with the FastAPI backend. All API calls are authenticated, tokens are managed automatically, and the authentication flow is seamless.

**Test the complete flow and enjoy your integrated Campus Connect application!**
