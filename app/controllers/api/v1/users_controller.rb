# frozen_string_literal: true

# =============================================================================
# USERS CONTROLLER — api/v1/users_controller.rb
# =============================================================================
#
# Handles user registration and user profile management.
#
# AUTHENTICATION:
#   All actions are protected by `doorkeeper_authorize!` from ApplicationController.
#   Exception: `:create` (registration) is public — users need to register before
#   they have a token.
#
# AUTHORIZATION (CanCanCan):
#   :create  — Any visitor (no auth needed)
#   :show    — Any authenticated user can view any user's basic info
#   :me      — Only the current user can see their own full profile
#   :update  — Users can update only their own record; admins can update any
#   :destroy — Users can destroy only themselves; admins can destroy any
#
# REQUEST FLOW for POST /api/v1/users (registration):
#   Client sends { user: { email:, password:, full_name: } }
#       ↓
#   skip_before_action :doorkeeper_authorize! allows unauthenticated access
#       ↓
#   User.new(user_params) + user.save
#       ↓
#   Returns 201 Created with user JSON or 422 with errors
#
# After registration, the client calls POST /oauth/token to get a Bearer token.
# =============================================================================

module Api
  module V1
    class UsersController < ApplicationController
      # =========================================================================
      # SKIP AUTHENTICATION FOR REGISTRATION
      # =========================================================================
      # `create` (user registration) is the ONLY public endpoint.
      # Every other action requires a valid Bearer token in the Authorization header.
      #
      # How this works:
      #   ApplicationController has: before_action :doorkeeper_authorize!
      #   We skip it only for :create so new users can register.
      # =========================================================================
      skip_before_action :doorkeeper_authorize!, only: [:create]

      # =========================================================================
      # SKIP AUTHORIZATION CHECK FOR REGISTRATION
      # =========================================================================
      # CanCanCan's `check_authorization` (set in ApplicationController) ensures
      # every action calls `authorize!`. For the public :create endpoint, we call
      # `skip_authorization_check` so it doesn't raise AuthorizationNotPerformed.
      # We'll call authorize! manually inside the action.
      # =========================================================================
      skip_authorization_check only: [:create]

      # =========================================================================
      # GET /api/v1/users/:id
      # =========================================================================
      # Returns basic user info for any authenticated user.
      # CanCanCan Ability: members can :read any User (for assignment dropdowns).
      # =========================================================================
      def show
        @user = User.find(params[:id])

        # authorize! checks: can?(current_user, :read, @user)
        # For members: always true (they can read any user's basic info).
        # For admins: always true.
        authorize! :read, @user

        render_success(UserSerializer.new(@user))
      end

      # =========================================================================
      # GET /api/v1/users/me
      # =========================================================================
      # Returns the FULL profile of the currently authenticated user.
      # This is the primary way clients load "current user" data after login.
      # =========================================================================
      def me
        # current_user is set by ApplicationController from the Doorkeeper token.
        # No extra DB query needed — token already has resource_owner_id.
        authorize! :read, current_user

        render_success(UserSerializer.new(current_user, include_private: true))
      end

      # =========================================================================
      # POST /api/v1/users
      # Public endpoint — no authentication required.
      # =========================================================================
      # Creates a new user account.
      # After successful registration, the client should immediately request
      # an OAuth token via POST /oauth/token.
      #
      # Request body (JSON):
      #   {
      #     "user": {
      #       "email": "alice@example.com",
      #       "password": "secret123",
      #       "password_confirmation": "secret123",
      #       "full_name": "Alice Smith"
      #     }
      #   }
      # =========================================================================
      def create
        @user = User.new(user_create_params)

        if @user.save
          # Registration succeeded. Return 201 Created with user data.
          # Client should now POST /oauth/token to get a Bearer token.
          render_success({ message: "Registration successful. Please request an OAuth token.",
                           user: UserSerializer.new(@user) }, :created)
        else
          render_error("registration_failed", @user.errors.full_messages, :unprocessable_entity)
        end
      end

      # =========================================================================
      # PATCH /api/v1/users/:id
      # =========================================================================
      # Allows a user to update their own profile.
      # Admins can update any user's data.
      #
      # Note: Password updates use a separate flow (Devise recoverable).
      # =========================================================================
      def update
        @user = User.find(params[:id])

        # CanCanCan: members can only update their own record (id: current_user.id)
        # Admins can update any user.
        authorize! :update, @user

        if @user.update(user_update_params)
          render_success(UserSerializer.new(@user))
        else
          render_error("update_failed", @user.errors.full_messages, :unprocessable_entity)
        end
      end

      # =========================================================================
      # PATCH /api/v1/users/me
      # =========================================================================
      # Convenience endpoint to update the current user without knowing their ID.
      # Equivalent to PATCH /api/v1/users/:current_user_id but friendlier for clients.
      # =========================================================================
      def update_me
        authorize! :update, current_user

        if current_user.update(user_update_params)
          render_success(UserSerializer.new(current_user))
        else
          render_error("update_failed", current_user.errors.full_messages, :unprocessable_entity)
        end
      end

      # =========================================================================
      # DELETE /api/v1/users/:id
      # =========================================================================
      # Hard deletes a user account.
      # Members can only delete themselves.
      # Admins can delete any user.
      #
      # Cascades (via model associations):
      #   - Profile destroyed
      #   - Owned projects (and their tasks/comments) destroyed
      #   - Comments destroyed
      #   - Tasks where assignee_id set to NULL (nullify)
      # =========================================================================
      def destroy
        @user = User.find(params[:id])
        authorize! :destroy, @user

        @user.destroy!
        render_success({ message: "User account deleted." }, :ok)
      end

      private

      # =========================================================================
      # STRONG PARAMETERS
      # =========================================================================
      # Rails 4+ requires explicitly permitting params to prevent mass assignment.
      # `permit` whitelists only the fields we want to allow.
      #
      # We separate :create and :update params because:
      #   - Registration requires password + password_confirmation
      #   - Updates should NOT allow changing email without verification (future)
      #   - Role should NOT be settable by regular users
      # =========================================================================

      # Params allowed only during initial registration.
      def user_create_params
        params.require(:user).permit(
          :email,
          :password,
          :password_confirmation,
          :full_name
          # Note: :role is intentionally excluded — all new users get :member
          # Admins must manually elevate via console or admin endpoint
        )
      end

      # Params allowed during profile updates (no password, no email by default).
      def user_update_params
        permitted = %i[full_name]

        # Admins can also update the role field.
        permitted << :role if current_user&.admin?

        params.require(:user).permit(permitted)
      end
    end
  end
end
