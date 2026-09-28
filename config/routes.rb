# frozen_string_literal: true

# =============================================================================
# ROUTES
# =============================================================================
# All routes in one place. Following REST conventions throughout.
#
# Authentication flow:
#   POST /oauth/token          → Exchange credentials for Bearer token
#   POST /oauth/revoke         → Revoke (logout) a token
#
# API is namespaced under /api/v1 for versioning. When you introduce
# breaking changes, add a /api/v2 namespace alongside v1 (don't remove v1
# until all clients have migrated).
# =============================================================================

Rails.application.routes.draw do
  # ===========================================================================
  # HEALTH CHECK
  # ===========================================================================
  # GET /up → Returns 200 if the app is healthy. Used by load balancers,
  # Kubernetes liveness probes, and uptime monitors like Betteruptime.
  get "up" => "rails/health#show", as: :rails_health_check

  # ===========================================================================
  # DOORKEEPER — OAuth2 Token Endpoints
  # ===========================================================================
  # Mounts Doorkeeper's built-in controllers at /oauth:
  #
  #   POST   /oauth/token          — Request access + refresh tokens
  #   POST   /oauth/revoke         — Invalidate an access or refresh token
  #   POST   /oauth/introspect     — Check if a token is valid (RFC 7662)
  #   GET    /oauth/token/info     — Get metadata about the current token
  #
  # These endpoints are NOT under /api/v1 on purpose — OAuth is
  # infrastructure-level, not an API resource.
  # ===========================================================================
  use_doorkeeper do
    # We only need the token and revoke endpoints for password flow.
    # Skipping the authorization endpoint (used only in auth-code flow).
    skip_controllers :authorizations, :applications, :authorized_applications
  end

  # ===========================================================================
  # DEVISE — Password Reset / Registration Routes
  # ===========================================================================
  # We use Devise only for user management (password reset emails).
  # Session-based login routes are NOT needed because Doorkeeper handles auth.
  #
  # :skip => [...] removes the routes we don't want to expose.
  # ===========================================================================
  devise_for :users,
    skip: %i[sessions registrations omniauth_callbacks confirmations unlocks],
    controllers: {
      passwords: "api/v1/devise/passwords"
    }

  # ===========================================================================
  # API v1 Namespace
  # ===========================================================================
  # All API routes are versioned under /api/v1.
  # The `defaults: { format: :json }` ensures:
  #   - Controllers always render JSON even if the request has no Accept header.
  #   - `request.format` is :json by default.
  # ===========================================================================
  namespace :api do
    namespace :v1, defaults: { format: :json } do

      # =========================================================================
      # USERS
      # =========================================================================
      # POST   /api/v1/users              → Register a new user
      # GET    /api/v1/users/me           → Current authenticated user profile
      # PATCH  /api/v1/users/me           → Update current user
      #
      # Standard CRUD resources PLUS custom member/collection routes.
      # =========================================================================
      resources :users, only: %i[create show update destroy] do
        collection do
          get  :me                  # GET  /api/v1/users/me
          patch :update_me          # PATCH /api/v1/users/me
        end
      end

      # =========================================================================
      # PROFILES
      # =========================================================================
      # GET   /api/v1/profile         → Show current user's profile
      # PATCH /api/v1/profile         → Update current user's profile
      # POST  /api/v1/profile         → Create profile for current user
      #
      # Singular resource (one profile per user, no :id in URL).
      # =========================================================================
      resource :profile, only: %i[show create update]

      # =========================================================================
      # PROJECTS
      # =========================================================================
      # GET    /api/v1/projects           → List owned projects
      # POST   /api/v1/projects           → Create project
      # GET    /api/v1/projects/:id       → Show project
      # PATCH  /api/v1/projects/:id       → Update project
      # DELETE /api/v1/projects/:id       → Delete project
      #
      # Nested: comments under projects (polymorphic)
      # =========================================================================
      resources :projects do
        # Nested comments route: /api/v1/projects/:project_id/comments
        # `commentable_type` and `commentable_id` are set from the URL params.
        resources :comments, only: %i[index create destroy], shallow: true
      end

      # =========================================================================
      # TASKS
      # =========================================================================
      # Nested under projects: /api/v1/projects/:project_id/tasks
      # GET    /api/v1/projects/:project_id/tasks      → List tasks for project
      # POST   /api/v1/projects/:project_id/tasks      → Create task in project
      # GET    /api/v1/tasks/:id                       → Show task (shallow)
      # PATCH  /api/v1/tasks/:id                       → Update task (shallow)
      # DELETE /api/v1/tasks/:id                       → Delete task (shallow)
      #
      # `shallow: true` generates short URLs for member actions (/tasks/:id)
      # instead of /projects/:project_id/tasks/:id — cleaner for sub-tasks.
      # =========================================================================
      resources :projects, only: [] do  # piggyback on existing :projects resource
        resources :tasks, shallow: true do
          # Comments nested under tasks: /api/v1/tasks/:task_id/comments
          resources :comments, only: %i[index create], shallow: true
        end
      end

      # =========================================================================
      # ATTACHMENTS
      # =========================================================================
      # These endpoints accept multipart/form-data with file uploads.
      # Active Storage handles the actual storage; the controller
      # calls `user.avatars.attach(params[:avatars])`.
      #
      # POST   /api/v1/users/:user_id/avatars           → Upload avatar(s)
      # DELETE /api/v1/users/:user_id/avatars/:blob_id  → Remove an avatar
      # POST   /api/v1/tasks/:task_id/documents         → Attach document(s)
      # DELETE /api/v1/tasks/:task_id/documents/:blob_id → Remove a document
      # =========================================================================
      resources :users, only: [] do
        resources :avatars, only: %i[index create destroy],
          controller: "attachments/avatars"
      end

      resources :tasks, only: [] do
        resources :documents, only: %i[index create destroy],
          controller: "attachments/task_documents"
      end

    end
  end
end
