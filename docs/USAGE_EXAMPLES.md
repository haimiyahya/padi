# PADI Usage Examples: Real-World Conversations

## "Hello World" - Your First Conversation

### Starting Fresh: What to Expect

```
User: Hello PADI, what does my codebase do?

PADI: Welcome! I've indexed your codebase and here's what I found:

📊 Repository Overview
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Type: Elixir/Phoenix web application
Files: 847 source files
Functions: 2,341 functions
Tests: 456 tests
Lines of Code: ~45,000

🏗️ Main Components
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• lib/app/         - Main application logic
• lib/auth/        - Authentication system
• lib/api/         - REST API endpoints
• lib/models/      - Database models
• lib/utils/       - Utility functions

🔍 Key Patterns I Found
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• You use Phoenix for web framework
• Authentication uses JWT tokens
• Database: PostgreSQL via Ecto
• Testing: ExUnit with 85%+ coverage
• Code style: snake_case for functions, camelCase for modules

💡 What Can I Help You With?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• "Build me a calculator" - I'll create or extend existing code
• "Add authentication" - I'll find existing auth patterns
• "Fix the bug in..." - I'll locate issues with context
• "How do I..." - I'll explain your own code back to you
• "Optimize..." - I'll suggest performance improvements

What would you like to do?
```

---

## Example 1: Building a Simple Calculator

### The Conversation

```
User: Build me a calculator

PADI: Great! I found 2 existing calculator implementations in your codebase:

🔍 Existing Calculators
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Option A: lib/math/simple_calc.ex
  • Basic operations: add, subtract, multiply
  • Well-tested: 4 tests passing
  • Last modified: 3 months ago
  • Pattern: Functional style, returns {:ok, result}

Option B: lib/scientific/calc.ex
  • Scientific functions: sin, cos, tan, log
  • Light testing: 2 tests
  • Pattern: Imperative style, direct returns

💡 My Recommendation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Extend Option A (lib/math/simple_calc.ex) because:
• It follows your codebase's functional pattern
• It has better test coverage
• It's more recently maintained

Should I:
A) Extend Option A with division
B) Extend Option B with basic operations
C) Create new calculator module

User: A, extend Option A

PADI: Perfect! Here's my plan:

📋 Implementation Plan
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
File to modify: lib/math/simple_calc.ex
Files affected: 2 total
• lib/math/simple_calc.ex (add divide_numbers/2)
• test/math/simple_calc_test.ex (add 3 test cases)

Code style detected:
  • Function naming: snake_case
  • Return format: {:ok, result} or {:error, reason}
  • Error handling: Pattern matching

Time estimate: <2 seconds
Token cost: ~1,500 tokens

Proceed with implementation? (y/n)

User: y

PADI: ✅ Done! Implementation complete:

📝 Changes Made
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Modified: lib/math/simple_calc.ex
  Added: divide_numbers/2

New Function:
def divide_numbers(a, b) when is_number(a) and is_number(b) do
  case b do
    0 -> {:error, :division_by_zero}
    _ -> {:ok, a / b}
  end
end

Modified: test/math/simple_calc_test.ex
  Added: 3 test cases for division

✅ Test Results: 7/7 passing (4 existing + 3 new)

🔗 Impact Analysis
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
No existing code needs updating (new function)
No breaking changes to existing API

⏱️ Performance: 1.2 seconds, 1,340 tokens used

What would you like to do next?
```

---

## Example 2: School Management System

### The Conversation

```
User: Build me a school management system

PADI: That's a complex system! Let me analyze what you already have:

🔍 Existing School-Related Code
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Found relevant existing components:

✅ Student Management:
  • lib/user/student.ex - Student records, basic CRUD
  • lib/user/teacher.ex - Teacher accounts
  • 3 months old, 85% test coverage

✅ Course System:
  • lib/course/course.ex - Course definitions
  • lib/course/enrollment.ex - Enrollment logic
  • Well-documented, comprehensive tests

✅ Attendance System:
  • lib/school/attendance.ex - Attendance tracking
  • Recently updated (1 week ago)
  • Integrated with user system

❌ Missing Components:
  • Grade/Assessment management
  • Class scheduling
  • Fee management
  • Report card generation

💡 My Recommendation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Build on existing foundations! Extend your current systems:

Phase 1 (Immediate):
  A) Add grade management to lib/course/assessment.ex
  B) Add class scheduling to lib/school/schedule.ex
  C) Create report card generation

Phase 2 (Future):
  D) Fee management system
  E) Parent portal access

Should I:
A) Build Phase 1 (3 components, ~30 seconds)
B) Focus on one component first
C) Create entirely new school module

User: A, build Phase 1

PADI: Excellent choice! Starting Phase 1 implementation:

📋 Phase 1 Implementation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Component 1: Grade Management
📁 File: lib/course/assessment.ex (extend existing)
  Add: grade_student/3, class_grades/2
  Tests: 5 new test cases
  Affected files: 3

Component 2: Class Scheduling
📁 File: lib/school/schedule.ex (extend existing)
  Add: schedule_class/3, check_conflict/2
  Tests: 4 new test cases
  Affected files: 2

Component 3: Report Cards
📁 File: Create lib/school/report_card.ex (new)
  Add: generate_report_card/2, class_summary/2
  Tests: 6 new test cases
  Affected files: 4

⏱️ Time Estimate: 28 seconds total
💰 Token Estimate: ~8,000 tokens

🔍 Code Patterns Detected
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Your codebase uses:
• Ecto schemas for database models
• Changeset validation
• Phoenix contexts for APIs
• ExUnit for testing

I'll follow these patterns throughout.

Proceeding with implementation...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Component 1 complete (Grade Management)
✅ Component 2 complete (Class Scheduling)
✅ Component 3 complete (Report Cards)

📊 Results Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Files modified: 3
Files created: 1
Functions added: 8
Tests added: 15
All tests: ✅ PASSING (471/471)

🎯 Ready to Use
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Grade Management
Grade.student(student_id, course_id, grade_value)

# Class Scheduling
School.Schedule.schedule_class(class_id, teacher_id, time_slot)

# Report Cards
School.ReportCard.generate(student_id, semester_id)

⏱️ Actual time: 24 seconds, 7,650 tokens used

Would you like me to:
A) Add API endpoints for these functions
B) Create database migrations
C) Set up admin interface
D) Something else

User: A, add API endpoints

PADI: Adding Phoenix API endpoints...
[Continues with API endpoint creation]
```

---

## Example 3: Bug Fix with Context

### The Conversation

```
User: Fix the authentication bug in user login

PADI: I found 3 authentication-related issues! Let me show you:

🔍 Authentication Issues Found
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Issue A: Token Validation Missing ⚠️ SECURITY
  📁 File: lib/auth/login.ex:45
  📝 Code: validate_token/1 exists but returns :ok unconditionally
  🔴 Severity: CRITICAL - Security vulnerability
  📅 History: Added 2 months ago by dev_intern
  📚 Context: "Quick fix for demo, needs proper validation"

Issue B: Session Timeout Too Short
  📁 File: lib/auth/session.ex:23
  📝 Code: Session timeout set to 5 minutes (too short for users)
  🟡 Severity: LOW - User experience issue
  📅 History: Changed 6 weeks ago

Issue C: Missing CSRF Protection ⚠️ SECURITY
  📁 File: lib/auth/middleware.ex:89
  📝 Code: CSRF check commented out for debugging
  🔴 Severity: CRITICAL - Security vulnerability
  📅 History: Commented out 1 week ago by senior_dev

💡 Priority Recommendation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Fix Issue A (CRITICAL) - Token validation
2. Fix Issue C (CRITICAL) - CSRF protection
3. Optionally fix Issue B (LOW) - Session timeout

Should I:
A) Fix both critical issues (A + C)
B) Fix all three issues
C) Focus on one specific issue

User: A, fix the critical issues

PADI: Fixing critical security issues...

🔧 Issue A: Token Validation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Current Code:
  def validate_token(_token), do: :ok

Fixed Code:
  def validate_token(token) do
    case JWTHelpers.decode(token) do
      {:ok, claims} -> :ok
      {:error, _reason} -> {:error, :invalid_token}
    end
  end

🔧 Issue C: CSRF Protection
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Current Code:
  # CSRF check temporarily disabled

Fixed Code:
  def call(conn, opts) do
    case CSRF.verify_and_get_csrf_token(conn) do
      {:ok, token} -> conn
      {:error, _reason} -> send_resp(conn, 403, "Invalid CSRF")
    end
  end

✅ Security fixes applied!

📊 Security Impact Analysis
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Files modified: 2
Tests added: 4 security tests
Vulnerabilities resolved: 2 critical

⚠️ Important Notes
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• These fixes may break existing clients using invalid tokens
• I recommend adding deprecation warnings first
• Consider backward compatibility period

Would you like me to:
A) Add deprecation warnings for smooth transition
B) Update authentication documentation
C) Test the fixes with existing auth flows

User: B, update documentation

PADI: Updating authentication documentation...
[Shows documentation updates with security guidelines]
```

---

## Example 4: Performance Optimization

### The Conversation

```
User: Optimize the slow database query in user search

PADI: Found the slow query! Let me analyze:

🔍 Performance Issue Found
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📁 File: lib/user/search.ex:127
🐌 Current Performance: ~2.3 seconds per search
📊 Query complexity: O(n²) - checking every user

Current Code:
def search_users(term) do
  User
  |> where([u], ilike(u.name, ^"%#{term}%"))
  |> or_where([u], ilike(u.email, ^"%#{term}%"))
  |> Repo.all()
  |> Enum.filter(fn u -> is_active?(u) end)
end

🔴 Performance Issues:
1. No database index on name/email
2. ILIKE with leading wildcard (%) prevents index usage
3. Post-filtering in Elixir instead of database

💡 Optimization Plan
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Option A: Add full-text search (RECOMMENDED)
  • Create PostgreSQL GIN index
  • Use tsvector for name/email
  • Performance: ~50ms (46x faster)
  • Migration: Create indexes

Option B: Add trigram indexes
  • Use pg_trgm for partial matching
  • Performance: ~200ms (11x faster)
  • Migration: Add extension

Option C: Optimize existing query only
  • Remove leading wildcards
  • Move filtering to database
  • Performance: ~400ms (5x faster)
  • Migration: No changes needed

My recommendation: Option A (full-text search)

Should I implement Option A?

User: A, implement full-text search

PADI: Implementing full-text search optimization...

📝 Migration Generated
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
defmodule Repo.Migrations.AddFullTextSearch do
  use Ecto.Migration

  def change do
    # Add GIN index for full-text search
    execute("""
      CREATE INDEX users_name_trgm_idx ON users USING gin (name gin_trgm_ops);
      CREATE INDEX users_email_trgm_idx ON users USING gin (email gin_trgm_ops);
    """)

    # Add full-text search column
    alter table(:users) do
      add(:search_vector, :tsvector)
    end

    # Create trigger for automatic updates
    execute("""
      CREATE TRIGGER users_search_vector_update
      BEFORE INSERT OR UPDATE ON users
      FOR EACH ROW EXECUTE FUNCTION
      tsvector_update_trigger(search_vector, 'pg_catalog.simple', 'name', 'email');
    """)
  end
end

🔧 Optimized Function
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
def search_users(term) do
  query = """
    SELECT id, name, email,
           ts_rank(search_vector, plainto_tsquery($1)) as rank
    FROM users
    WHERE search_vector @@ plainto_tsquery($1)
    ORDER BY rank DESC
    LIMIT 50
  """

  Repo.query(query, [term])
end

✅ Optimization Complete!

📊 Performance Results
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Before: 2,300ms per search
After: 45ms per search
Improvement: 51x faster 🚀

✅ Tests Passing: 8/8
✅ Migration Safe: Backwards compatible

⏱️ Time: 8 seconds, 2,100 tokens used

Next Steps:
1. Run migration: mix ecto.migrate
2. Test search functionality
3. Monitor query performance

Would you like me to help with testing or monitoring?
```

---

## Example 5: Understanding Your Own Code

### The Conversation

```
User: How does the authentication system work?

PADI: Let me explain your authentication system! I found 3 interconnected components:

🔍 Authentication Architecture
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Component 1: Login Flow
📁 File: lib/auth/login.ex
Flow:
  1. User submits credentials → authenticate_user/2
  2. Validates password against hash → verify_password/2
  3. Generates JWT token → generate_token/1
  4. Returns token to client

Component 2: Token Validation
📁 File: lib/auth/middleware.ex
Flow:
  1. Extract token from headers → extract_token/1
  2. Validate token signature → validate_token/1
  3. Load user from database → load_user_from_token/1
  4. Set current_user in conn

Component 3: Session Management
📁 File: lib/auth/session.ex
Flow:
  1. Create session on login → create_session/1
  2. Refresh tokens periodically → refresh_session/1
  3. Clean up expired sessions → cleanup_sessions/0

🔗 Relationships
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
login.ex → generates tokens → validated by middleware.ex
login.ex → creates sessions → managed by session.ex
session.ex → loads users → uses functions from user.ex

💡 Key Design Decisions (from your codebase)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• JWT tokens expire after 24 hours
• Sessions persist for 7 days
• Password hashing uses bcrypt (cost: 12)
• Failed login attempts are rate-limited

📚 Test Coverage
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Login Flow: 12 tests (all passing)
Token Validation: 8 tests (all passing)
Session Management: 5 tests (all passing)

🎯 What Would You Like to Know More About?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
A) How to add OAuth2 provider
B) How to implement password reset
C) How to add two-factor authentication
D) Show me the call graph for authentication
E) Something else

User: D, show me the call graph

PADI: Here's the authentication call graph:

📊 Authentication Call Graph
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Entry Points:
  • POST /api/login → Auth.login/2
  • GET /api/me → Auth.validate_and_load_user/1

Call Chain for Login:
  Auth.login/2
    ├─→ User.find_by_email/1
    ├─→ Auth.verify_password/2
    │   └─→ CryptoWrapper.compare_hash/2
    ├─→ Auth.generate_token/1
    │   └─→ JWTHelpers.encode/1
    └─→ Auth.create_session/1
        └─→ SessionStore.insert/2

External Dependencies:
  • CryptoWrapper (your crypto wrapper)
  • JWTHelpers (JWT library)
  • User schema (Ecto model)
  • SessionStore (ETS cache)

📈 Performance Characteristics:
  • Login: ~45ms (database query: 30ms, crypto: 10ms, token: 5ms)
  • Token validation: ~2ms (database lookup)
  • Session refresh: ~8ms (ETS read + write)

🔗 Files That Call Authentication:
  • lib/api/middleware.ex: 8 calls
  • lib/controllers/user_controller.ex: 12 calls
  • lib/controllers/admin_controller.ex: 5 calls

Would you like to see:
A) How to optimize performance
B) Where authentication errors occur
C) How to add new auth methods
```

---

## Example 6: Adding Features to Existing Code

### The Conversation

```
User: Add password reset functionality to the authentication system

PADI: Let me analyze your existing authentication to add password reset properly!

🔍 Existing Authentication Analysis
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Current System:
  • Login with email/password
  • JWT tokens for authentication
  • Session management via ETS
  • User model: lib/schemas/user.ex

Missing for Password Reset:
  • Reset token generation/storage
  • Email sending capability
  • Password update flow
  • Token expiration handling

💡 Implementation Plan
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Phase 1: Database Schema (Required)
  • Add password_reset_tokens table
  • Add reset_token_sent_at to users table

Phase 2: Core Functions (Required)
  • request_password_reset/1 - Send reset email
  • verify_reset_token/1 - Validate token
  • reset_password/2 - Update password with token

Phase 3: API Endpoints (Required)
  • POST /api/auth/password-reset/request
  • POST /api/auth/password-reset/confirm

Your codebase uses:
  • Ecto for database
  • Bamboo/Swoosh for emails
  • Phoenix for APIs

I'll follow these patterns.

Files to modify: 5
Files to create: 2
Estimated time: 15 seconds
Token cost: ~3,500 tokens

Proceed with implementation?

User: Yes, proceed

PADI: Implementing password reset system...

📝 Database Migration Created
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
defmodule Repo.Migrations.AddPasswordReset do
  use Ecto.Migration

  def change do
    create table(:password_reset_tokens) do
      add :user_id, references(:users), null: false
      add :token, :string, null: false
      add :expires_at, :utc_datetime, null: false
      add :used, :boolean, default: false

      timestamps()
    end

    create index(:password_reset_tokens, [:token])
    create index(:password_reset_tokens, [:user_id])
  end
end

🔧 Core Functions Added
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# File: lib/auth/password_reset.ex

def request_password_reset(email) do
  case User.find_by_email(email) do
    nil ->
      # Always return success to prevent email enumeration
      {:ok, :email_sent}

    user ->
      token = generate_reset_token()
      expires_at = DateTime.add(DateTime.utc_now(), hours: 1)

      Repo.insert(%PasswordResetToken{
        user_id: user.id,
        token: token,
        expires_at: expires_at
      })

      # Send email
      Email.send_password_reset(user, token)

      {:ok, :email_sent}
  end
end

def verify_reset_token(token) do
  case Repo.get_by(PasswordResetToken, token: token) do
    nil -> {:error, :invalid_token}
    reset ->
      cond do
        DateTime.utc_now() > reset.expires_at -> {:error, :expired_token}
        reset.used == true -> {:error, :already_used}
        true -> {:ok, reset.user_id}
      end
  end
end

def reset_password(token, new_password) do
  case verify_reset_token(token) do
    {:ok, user_id} ->
      Repo.transaction(fn ->
        user = Repo.get!(User, user_id)

        user
        |> Ecto.Changeset.change(%{password_hash: hash_password(new_password)})
        |> Repo.update()

        # Mark token as used
        reset = Repo.get_by!(PasswordResetToken, token: token)
        Ecto.Changeset.change(reset, %{used: true})
        |> Repo.update()
      end)

      {:ok, :password_reset}

    {:error, reason} ->
      {:error, reason}
  end
end

🌐 API Endpoints Added
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# File: lib/controllers/auth_controller.ex

def request_password_reset(conn, %{"email" => email}) do
  case Auth.request_password_reset(email) do
    {:ok, :email_sent} ->
      json(conn, %{message: "If email exists, password reset sent"})
  end
end

def reset_password(conn, %{"token" => token, "password" => password}) do
  case Auth.reset_password(token, password) do
    {:ok, :password_reset} ->
      json(conn, %{message: "Password reset successfully"})

    {:error, :invalid_token} ->
      conn
      |> put_status(422)
      |> json(%{error: "Invalid reset token"})

    {:error, :expired_token} ->
      conn
      |> put_status(422)
      |> json(%{error: "Reset token expired"})
  end
end

✅ Password Reset System Complete!

📊 Implementation Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Files created: 2
  • lib/auth/password_reset.ex
  • lib/controllers/auth_controller.ex (extended)

Files modified: 1
  • lib/schemas/user.ex (added associations)

Migration files: 1
Tests added: 8
  • 5 for password_reset functions
  • 3 for API endpoints

✅ All tests passing (479/479)

🔒 Security Features Implemented:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Reset tokens expire after 1 hour
• Tokens are single-use only
• Email enumeration prevention (always return success)
• Token expiration validation

⏱️ Time: 12 seconds, 3,200 tokens used

🎯 Ready to Use
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Request password reset
Auth.request_password_reset("user@example.com")

# Reset with token
Auth.reset_password("reset_token_here", "new_password")

# API endpoints
POST /api/auth/password-reset/request
POST /api/auth/password-reset/confirm

Would you like me to:
A) Add rate limiting for password reset
B) Add email template customization
C) Create admin interface for managing resets
```

---

## Key Takeaways from These Examples

### What Makes PADI Different

**✅ Context Awareness**
- Knows your existing code before making changes
- Suggests extending vs creating new
- Understands your code patterns and style

**✅ Historical Memory**
- Knows why code was written a certain way
- Prevents reintroduction of old bugs
- Explains architectural decisions

**✅ Surgical Precision**
- Shows exact files affected
- Provides performance estimates
- Gives token usage predictions

**✅ Single-Turn Success**
- Pre-validated code patterns
- Automatic test generation
- Built-in policy compliance

### What You'll Experience

**Traditional AI:**
- 5-10 turns of trial and error
- 50,000-150,000 tokens burned
- Generic suggestions that don't fit your codebase
- Frustration and time wasted

**PADI:**
- 1-2 turns with confidence
- 1,500-4,000 tokens total
- Code that matches your exact patterns
- Satisfaction with working code

---

**Ready to try these conversations yourself?**

Start here: `padi scan .` then `padi server start`

Then ask: `"Hello PADI, what does my codebase do?"`