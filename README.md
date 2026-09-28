# 🚀 Rails API Learning Hub

A production-ready, highly documented **Rails 8+ API-Only** reference application demonstrating enterprise architecture patterns:
- **Authentication:** OAuth2 Password Grant Flow via **Devise** + **Doorkeeper**
- **Authorization:** Role-Based Access Control (RBAC) via **CanCanCan** (`member` vs `admin`)
- **Database:** PostgreSQL with relational integrity, composite indexes, and enum mappings
- **Attachments:** Multi-file uploads via **Active Storage** (`has_many_attached :avatars`, `has_many_attached :documents`)

---

## 📑 Table of Contents
1. [Tech Stack](#-tech-stack)
2. [Domain Models & Relationships](#-domain-models--relationships)
3. [Prerequisites](#-prerequisites)
4. [Quickstart Setup (Step-by-Step)](#-quickstart-setup-step-by-step)
5. [Pre-Seeded Test Credentials](#-pre-seeded-test-credentials)
6. [Authentication Flow (How to get Bearer Tokens)](#-authentication-flow)
7. [Managing OAuth2 Client Applications](#-managing-oauth2-client-applications)
8. [API Endpoints Cheat Sheet](#-api-endpoints-cheat-sheet)
9. [Architecture & Design Decisions](#-architecture--design-decisions)
10. [Troubleshooting & Helpful Commands](#-troubleshooting--helpful-commands)

---

## 🛠 Tech Stack

| Component | Technology | Description |
| :--- | :--- | :--- |
| **Framework** | Rails 8.1+ (`--api`) | Session-free, lightweight JSON-only REST pipeline |
| **Language** | Ruby 3.3+ | Modern Ruby syntax and garbage collection |
| **Database** | PostgreSQL 16+ (`pg` gem) | Relational persistence, composite indexes, foreign keys |
| **Authentication** | `devise` + `doorkeeper` | Bcrypt hashing + OAuth2 Bearer token provider |
| **Authorization** | `cancancan` | Centralized permission rules in `app/models/ability.rb` |
| **File Storage** | `active_storage` | Local disk (dev) / S3-compatible (prod) file handling |
| **Serializers** | `active_model_serializers` | Contract-driven JSON serialization |
| **CORS** | `rack-cors` | Fine-grained Cross-Origin Resource Sharing middleware |
| **Job Queue** | `solid_queue` | Database-backed background processing for async file purging |

---

## 🧩 Domain Models & Relationships

```text
  +------------------+         1:1          +------------------+
  |       User       | -------------------> |     Profile      |
  | (member / admin) |                      +------------------+
  +------------------+
     | 1          | 1          | 1
     |            |            |
     | 1:N (owner)| 1:N (asg.) | 1:N (author)
     v            v            v
+----------+  +----------+  +-------------------------------+
| Project  |  |   Task   |  |            Comment            |
+----------+  +----------+  | (Polymorphic: Project | Task) |
     | 1           | 1      +-------------------------------+
     | 1:N         | 1:N                  ^
     +------->+<---+                      |
              |                           |
              +--- has_many :comments ----+
              |   (as: :commentable)
              |
              | 1:N (self-referential)
              +---> Task (sub_tasks via parent_task_id)
```

1. **User:** Central identity (`role: :member` or `:admin`). Has one `Profile`, has many `owned_projects` (`owner_id`), has many `assigned_tasks` (`assignee_id`), has many `comments`, and `has_many_attached :avatars`.
2. **Profile:** Belongs to `User`. Enforced 1-to-1 via DB unique index.
3. **Project:** Belongs to `owner` (`User`). Has many `tasks` (`dependent: :destroy`) and polymorphic `comments` (`as: :commentable`).
4. **Task:** Belongs to `project`, optionally belongs to `assignee` (`User`), and has a **self-referential** hierarchy (`belongs_to :parent_task` / `has_many :sub_tasks`). Has polymorphic `comments` and `has_many_attached :documents`.
5. **Comment:** Polymorphic belongs to `commentable` (`Project` or `Task`) and belongs to `user` (author).

---

## 📋 Prerequisites

Ensure your system has the following installed:
- **Ruby:** `3.3.0` or higher (`ruby -v`)
- **Rails:** `8.1.0` or higher (`rails -v`)
- **PostgreSQL:** `15+` running locally on port `5432` (`psql --version`)
- **Bundler:** `2.5+` (`bundle -v`)
- **Bruno** or **Postman** (for executing API tests)

---

## ⚡ Quickstart Setup (Step-by-Step)

### 1. Clone the repository
```bash
git clone <repo_url> rails_api_learning_hub
cd rails_api_learning_hub
```

### 2. Install dependencies
```bash
bundle install
```

### 3. Configure Database

The application's `config/database.yml` is configured with flexible defaults that support both environment variables and zero-config local defaults:

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  max_connections: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  username: <%= ENV["POSTGRES_USERNAME"] %>
  password: <%= ENV["POSTGRES_PASSWORD"] %>
  host: <%= ENV["POSTGRES_HOST"] %>
  port: <%= ENV["POSTGRES_PORT"] %>
```

> [!NOTE]
> **Environment variables are NOT strictly required.**
> When `POSTGRES_USERNAME`, `POSTGRES_PASSWORD`, `POSTGRES_HOST`, and `POSTGRES_PORT` are omitted, Rails and the PostgreSQL driver automatically fall back to local defaults (connecting over Unix domain socket with your current OS user on port 5432).

Choose the approach that matches your environment:

- **Option A: Default Local PostgreSQL (No ENV Needed)**
  If your PostgreSQL runs locally with standard trust/socket authentication, you do **not** need to set any environment variables. You can proceed directly to step 4.

- **Option B: Custom Credentials or Docker (Using ENV Variables)**
  If your PostgreSQL setup requires authentication or runs on a custom host/port (e.g., via Docker):
  ```bash
  export POSTGRES_USERNAME="postgres"
  export POSTGRES_PASSWORD="your_password"
  export POSTGRES_HOST="localhost"
  export POSTGRES_PORT="5432"
  ```

- **Option C: Direct Configuration in `config/database.yml`**
  If you prefer not to use environment variables, you can hardcode your connection parameters directly into [config/database.yml](file:///Users/anujpatel/Desktop/ror_session/rails_api_learning_hub/config/database.yml).

### 4. Create and Migrate Database
```bash
bin/rails db:create db:migrate
```

### 5. Seed Test Data & OAuth Client
Run the comprehensive seed file to populate realistic users, projects, tasks, comments, and a Doorkeeper OAuth client:
```bash
bin/rails db:seed
```
*Tip: The seed command prints out the generated Client ID and ready-to-use credentials!*

### 6. Start the API Server
```bash
bin/rails server -p 3000
```
The API is now running at `http://localhost:3000`.

---

## 👥 Pre-Seeded Test Credentials

| Role | Email | Password | Permissions |
| :--- | :--- | :--- | :--- |
| **Admin** | `admin@railshub.dev` | `Admin@123456` | Full access across all projects, users, tasks, and comments |
| **Member** (Alice) | `alice@railshub.dev` | `Member@123456` | Can manage own projects, assigned tasks, own profile, and own comments |
| **Member** (Bob) | `bob@railshub.dev` | `Member@123456` | Member permissions |
| **Member** (Carol) | `carol@railshub.dev` | `Member@123456` | Member permissions |

---

## 🔐 Authentication Flow

All protected endpoints require an OAuth2 Bearer token in the `Authorization` header.

### 1. Obtain an Access Token (OAuth2 Password Flow)
To get a Bearer token, query Doorkeeper's `/oauth/token` endpoint. First, find your Client ID:
```bash
bin/rails doorkeeper:list_apps
```

Then request your token:
```bash
curl -X POST http://localhost:3000/oauth/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "username=admin@railshub.dev" \
  -d "password=Admin@123456" \
  -d "client_id=<YOUR_CLIENT_ID>"
```

**Response (HTTP 200 OK):**
```json
{
  "access_token": "KcuKSBou-XKlHPp_CzQpap6KIGy54D4TQP4aMKHaCvs",
  "token_type": "Bearer",
  "expires_in": 7200,
  "created_at": 1790572635
}
```

### 2. Make Authenticated Requests
Pass the `access_token` in the `Authorization: Bearer <TOKEN>` header:
```bash
curl -X GET http://localhost:3000/api/v1/users/me \
  -H "Authorization: Bearer <YOUR_ACCESS_TOKEN>"
```

### 3. Revoke Token (Logout)
```bash
curl -X POST http://localhost:3000/oauth/revoke \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "token=<YOUR_ACCESS_TOKEN>" \
  -d "client_id=<YOUR_CLIENT_ID>"
```

---

## 🛠 Managing OAuth2 Client Applications

This project includes built-in CLI automation in `lib/tasks/doorkeeper.rake`.

### 1. Create a Public App (Mobile App / SPA / Bruno / Postman - No Secret Required)
```bash
bin/rails "doorkeeper:create_app[React Web Client, , false]"
```

### 2. Create a Confidential App (Backend Service - Secret Required)
```bash
bin/rails "doorkeeper:create_app[Payment Microservice, https://payments.internal/callback, true]"
```

### 3. List All Registered Clients
```bash
bin/rails doorkeeper:list_apps
```

### 4. Emergency: Revoke All Tokens for a User
```bash
bin/rails "doorkeeper:revoke_user_tokens[alice@railshub.dev]"
```

### 5. Via Rails Console (`rails c`)
```ruby
# In bin/rails console:
app = Doorkeeper::Application.create!(
  name: "Mobile App",
  redirect_uri: "",
  confidential: false,
  scopes: ""
)
puts app.uid # This is your client_id
```

---

## 📡 API Endpoints Cheat Sheet

All application endpoints are versioned under `/api/v1` and return JSON.

### Authentication & Account
| Method | Endpoint | Description | Auth Required |
| :--- | :--- | :--- | :--- |
| `POST` | `/oauth/token` | Request OAuth2 access token (password flow) | No |
| `POST` | `/oauth/revoke` | Invalidate/revoke an access token | No |
| `POST` | `/api/v1/users` | Register a new user | No |
| `POST` | `/users/password` | Request Devise password reset email | No |
| `GET` | `/api/v1/users/me` | Fetch authenticated user details | **Bearer Token** |
| `PATCH`| `/api/v1/users/update_me` | Update authenticated user details | **Bearer Token** |
| `GET` | `/api/v1/profile` | View profile (singular resource) | **Bearer Token** |
| `PATCH`| `/api/v1/profile` | Update profile bio/website/location | **Bearer Token** |

### Projects
| Method | Endpoint | Description | CanCanCan RBAC |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/v1/projects` | List projects (scoped via `accessible_by`) | All authenticated |
| `POST` | `/api/v1/projects` | Create project (owner is set to `current_user`) | Any member / admin |
| `GET` | `/api/v1/projects/:id` | View project details & task summary | Any member / admin |
| `PATCH`| `/api/v1/projects/:id` | Update project | **Owner or Admin only** |
| `DELETE`| `/api/v1/projects/:id` | Delete project and cascade tasks | **Owner or Admin only** |

### Tasks & Nested Sub-Tasks
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/v1/projects/:project_id/tasks` | List all tasks in a project |
| `POST` | `/api/v1/projects/:project_id/tasks` | Create task (pass `parent_task_id` for sub-tasks) |
| `GET` | `/api/v1/tasks/:id` | View task details, assignee, documents, & sub-tasks |
| `PATCH`| `/api/v1/tasks/:id` | Update task (status, priority, assignee) |
| `DELETE`| `/api/v1/tasks/:id` | Delete task & cascade child sub-tasks |

### Polymorphic Comments
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/v1/projects/:project_id/comments` | List comments on a project |
| `POST` | `/api/v1/projects/:project_id/comments` | Add comment to a project |
| `GET` | `/api/v1/tasks/:task_id/comments` | List comments on a task |
| `POST` | `/api/v1/tasks/:task_id/comments` | Add comment to a task |
| `DELETE`| `/api/v1/comments/:id` | Delete comment (**Author or Admin only**) |

### Active Storage Attachments
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/v1/users/:user_id/avatars` | List user avatars (includes signed URLs) |
| `POST` | `/api/v1/users/:user_id/avatars` | Upload avatar (`multipart/form-data`: `avatars[]`) |
| `GET` | `/api/v1/tasks/:task_id/documents` | List task documents (spec PDFs, screenshots) |
| `POST` | `/api/v1/tasks/:task_id/documents` | Upload task documents (`documents[]`) |

---

## 🏛 Architecture & Design Decisions

### 1. `before_action :doorkeeper_authorize!`
Every controller inherits from `ApplicationController`, which validates Bearer tokens on every call. Public actions explicitly override this with:
```ruby
skip_before_action :doorkeeper_authorize!, only: [:create]
```

### 2. CanCanCan Safety Net (`check_authorization`)
`ApplicationController` enforces that every request must evaluate permissions:
```ruby
check_authorization unless: :devise_controller?
```
If an action executes without calling `authorize!`, CanCanCan raises `CanCan::AuthorizationNotPerformed`, preventing accidental data exposure.

### 3. Polymorphic Resolution without Code Duplication
[`app/controllers/api/v1/comments_controller.rb`](file:///Users/anujpatel/Desktop/ror_session/rails_api_learning_hub/app/controllers/api/v1/comments_controller.rb) inspects params to dynamically bind to either a `Project` or a `Task`:
```ruby
def find_commentable
  @commentable = if params[:project_id]
                   Project.find(params[:project_id])
                 elsif params[:task_id]
                   Task.find(params[:task_id])
                 end
end
```
---

## 🔧 Troubleshooting & Helpful Commands

### Check Registered OAuth Clients:
```bash
bin/rails doorkeeper:list_apps
```

### Reset & Reseed Database:
```bash
bin/rails db:drop db:create db:migrate db:seed
```

### Check Routes:
```bash
bin/rails routes | grep -E "api/v1|oauth"
```

### Interactive Console with Sandbox (Rollback on exit):
```bash
bin/rails console --sandbox
```

### Run Server on Custom Port:
```bash
bin/rails server -p 3001
```

---

## 📄 License
MIT License. Built for developer learning and enterprise production reference.
