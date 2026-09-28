# frozen_string_literal: true

# =============================================================================
# APPLICATION CONTROLLER — Base for all API controllers
# =============================================================================
#
# This is the parent class for every controller in the API.
# It sets up three cross-cutting concerns that apply to EVERY endpoint:
#
#   1. AUTHENTICATION  — Doorkeeper token validation
#   2. CURRENT USER    — Helper to fetch the authenticated user
#   3. ERROR HANDLING  — Consistent JSON error responses
#
# Architecture note:
#   ActionController::API is the lean, session-free version of
#   ActionController::Base. It excludes:
#     - View rendering (ERB, ActionView helpers)
#     - Cookie-based sessions
#     - CSRF protection
#     - Flash messages
#   These are not needed for a stateless JSON API.
#
# Request lifecycle for a protected endpoint:
#
#   Client Request (Authorization: Bearer <token>)
#       ↓
#   before_action :doorkeeper_authorize!
#       ↓  (extracts token from Authorization header, validates in DB)
#   before_action :authenticate_user!   (maps token → User)
#       ↓
#   Controller action runs
#       ↓
#   authorize! :action, @resource      (CanCanCan checks ability)
#       ↓
#   JSON Response
# =============================================================================

class ApplicationController < ActionController::API
  # ===========================================================================
  # AUTHENTICATION — Doorkeeper
  # ===========================================================================
  # `doorkeeper_authorize!` is a Doorkeeper-provided before_action that:
  #   1. Reads the Authorization header: "Bearer <access_token>"
  #   2. Looks up the token in oauth_access_tokens table
  #   3. Checks if the token has expired (based on created_at + expires_in)
  #   4. Checks if the token has been revoked (revoked_at is NULL)
  #   5. Returns 401 JSON if any check fails
  #
  # If you have a public endpoint (e.g., GET /api/v1/products) that should
  # not require authentication, override with:
  #   skip_before_action :doorkeeper_authorize!, only: [:index]
  # ===========================================================================
  before_action :doorkeeper_authorize!

  # ===========================================================================
  # AUTHORIZATION — CanCanCan
  # ===========================================================================
  # `check_authorization` (class method) ensures every action calls
  # `authorize!` at least once. If a controller action is reached without
  # calling `authorize!`, CanCanCan raises CanCan::AuthorizationNotPerformed.
  #
  # This prevents accidentally shipping endpoints with no access control.
  #
  # To skip this check for a specific controller (e.g., public endpoints):
  #   skip_authorization_check
  # ===========================================================================
  check_authorization unless: :devise_controller?

  # ===========================================================================
  # GLOBAL ERROR HANDLING
  # ===========================================================================
  # Instead of cluttering each controller with begin/rescue, we define
  # app-wide error handlers here. They catch exceptions bubbled up from
  # models, controllers, or service objects and render consistent JSON.
  # ===========================================================================

  # CanCanCan raises this when the user doesn't have permission.
  # Returns 403 Forbidden with a descriptive message.
  rescue_from CanCan::AccessDenied do |exception|
    render json: {
      error: "access_denied",
      message: exception.message
    }, status: :forbidden
  end

  # ActiveRecord raises this when a record isn't found (usually via find()).
  # Returns 404 Not Found.
  rescue_from ActiveRecord::RecordNotFound do |exception|
    render json: {
      error: "record_not_found",
      message: exception.message
    }, status: :not_found
  end

  # ActiveRecord raises this on validation failures triggered manually.
  # Controllers should usually check .save and render errors themselves,
  # but this is a safety net.
  rescue_from ActiveRecord::RecordInvalid do |exception|
    render json: {
      error: "record_invalid",
      message: exception.message,
      details: exception.record.errors.full_messages
    }, status: :unprocessable_entity
  end

  # CanCanCan raises this when `check_authorization` finds that `authorize!`
  # was never called in an action.
  rescue_from CanCan::AuthorizationNotPerformed do |exception|
    render json: {
      error: "authorization_not_performed",
      message: exception.message
    }, status: :forbidden
  end

  private

  # ===========================================================================
  # CURRENT USER HELPER
  # ===========================================================================
  # `current_resource_owner` is provided by Doorkeeper.
  # It looks up the user associated with the validated OAuth token.
  #
  # How it works:
  #   doorkeeper_token.resource_owner_id → User.find(id)
  #
  # We memoize with @current_user to avoid multiple DB queries per request.
  # `helper_method` makes it available in views (not needed for API, but
  # harmless and consistent with Rails conventions).
  # ===========================================================================
  def current_user
    @current_user ||= User.find(doorkeeper_token.resource_owner_id) if doorkeeper_token
  end

  # ===========================================================================
  # CANCANCAN INTEGRATION
  # ===========================================================================
  # CanCanCan requires a `current_ability` method returning an Ability instance.
  # The Ability class (app/models/ability.rb) reads `current_user.role`
  # and defines what actions that user can perform on which resources.
  #
  # Called automatically by `authorize!` and `accessible_by`.
  # ===========================================================================
  def current_ability
    @current_ability ||= Ability.new(current_user)
  end

  # ===========================================================================
  # JSON ERROR HELPER
  # ===========================================================================
  # Convenience method to render standardized error responses.
  # Usage:
  #   render_error("validation_failed", @resource.errors.full_messages, :unprocessable_entity)
  # ===========================================================================
  def render_error(error_key, messages, http_status = :bad_request)
    render json: {
      error: error_key,
      messages: Array(messages)
    }, status: http_status
  end

  # ===========================================================================
  # JSON SUCCESS HELPER
  # ===========================================================================
  # Renders a successful JSON response.
  # Accepts:
  #   - A Hash (rendered directly)
  #   - An ActiveModel::Serializer instance (calls serializable_hash to convert)
  #   - An ActiveRecord::Base instance (Rails auto-selects serializer)
  #
  # Usage:
  #   render_success(UserSerializer.new(@user))
  #   render_success({ token: "abc", user: UserSerializer.new(@u).as_json })
  # ===========================================================================
  def render_success(data, http_status = :ok)
    payload = case data
              when ActiveModel::Serializer
                # Convert AMS serializer to a plain hash via serializable_hash,
                # then render as JSON. This avoids the model_name error that
                # occurs when passing a Serializer object directly to render json:.
                data.as_json
              else
                data
              end
    render json: payload, status: http_status
  end
end
