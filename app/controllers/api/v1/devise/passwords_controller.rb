# frozen_string_literal: true

# =============================================================================
# DEVISE PASSWORDS CONTROLLER (API Override)
# =============================================================================
# Overrides Devise's PasswordsController to return JSON responses instead
# of HTML redirects. Required for API-only mode.
#
# ROUTES:
#   POST  /users/password          → create (request password reset email)
#   PATCH /users/password          → update (reset password with token)
# =============================================================================

module Api
  module V1
    module Devise
      class PasswordsController < DeviseController
        # Skip Doorkeeper auth for password reset (user is unauthenticated)
        skip_before_action :doorkeeper_authorize!
        skip_authorization_check

        respond_to :json

        # =======================================================================
        # POST /users/password
        # =======================================================================
        # Sends a password reset email.
        # Body: { "user": { "email": "alice@example.com" } }
        # =======================================================================
        def create
          self.resource = resource_class.send_reset_password_instructions(resource_params)

          if successfully_sent?(resource)
            render json: { message: "Password reset instructions sent to #{resource.email}." }
          else
            render json: { errors: resource.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # =======================================================================
        # PATCH /users/password
        # =======================================================================
        # Resets password using the token from the email link.
        # Body: { "user": { "reset_password_token": "...", "password": "...", "password_confirmation": "..." } }
        # =======================================================================
        def update
          self.resource = resource_class.reset_password_by_token(resource_params)

          if resource.errors.empty?
            render json: { message: "Password updated successfully. Please request a new OAuth token." }
          else
            render json: { errors: resource.errors.full_messages }, status: :unprocessable_entity
          end
        end

        private

        def resource_params
          params.require(:user).permit(:email, :password, :password_confirmation, :reset_password_token)
        end
      end
    end
  end
end
