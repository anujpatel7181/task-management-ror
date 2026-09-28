# frozen_string_literal: true

# =============================================================================
# PROFILES CONTROLLER — api/v1/profiles_controller.rb
# =============================================================================
#
# Manages the current user's Profile (singleton resource — no :id in URLs).
#
# ROUTES (singular resource):
#   GET   /api/v1/profile    → show
#   POST  /api/v1/profile    → create
#   PATCH /api/v1/profile    → update
#
# AUTHENTICATION:
#   All actions require a valid Bearer token (from ApplicationController).
#
# AUTHORIZATION (CanCanCan):
#   Members can only manage (CRUD) their OWN profile.
#   Ability rule: can :manage, Profile, user_id: user.id
#
# DESIGN NOTE:
#   Profile is a singular resource because each user has exactly one.
#   `resource :profile` (singular) generates routes WITHOUT :id.
#   The controller always scopes to `current_user.profile`.
# =============================================================================

module Api
  module V1
    class ProfilesController < ApplicationController
      # =========================================================================
      # BEFORE ACTIONS
      # =========================================================================
      # Load the profile before update (to avoid re-querying in multiple actions).
      before_action :load_profile, only: %i[update]

      # =========================================================================
      # GET /api/v1/profile
      # =========================================================================
      # Returns the current user's profile data.
      # Creates a blank profile response if the user hasn't created one yet.
      # =========================================================================
      def show
        # Find the profile associated with the authenticated user.
        # current_user is resolved from the Doorkeeper token by ApplicationController.
        @profile = current_user.profile

        # CanCanCan authorization:
        # Ability.can?(:read, @profile)
        # For members: checks profile.user_id == current_user.id
        authorize! :read, @profile || Profile.new(user: current_user)

        if @profile
          render_success(ProfileSerializer.new(@profile))
        else
          # No profile yet — return an empty structure so the client knows to POST.
          render_success({ profile: nil, message: "No profile created yet. POST /api/v1/profile to create one." })
        end
      end

      # =========================================================================
      # POST /api/v1/profile
      # =========================================================================
      # Creates the profile for the current user.
      # If a profile already exists, returns 409 Conflict.
      #
      # Request body:
      #   { "profile": { "bio": "...", "website_url": "...", "location": "..." } }
      # =========================================================================
      def create
        # Build a new profile scoped to the current user.
        # This automatically sets profile.user = current_user.
        @profile = current_user.build_profile(profile_params)

        # CanCanCan: members can create their own profile.
        authorize! :create, @profile

        if @profile.save
          render_success(ProfileSerializer.new(@profile), :created)
        else
          render_error("profile_creation_failed", @profile.errors.full_messages, :unprocessable_entity)
        end
      end

      # =========================================================================
      # PATCH /api/v1/profile
      # =========================================================================
      # Updates the current user's profile.
      # =========================================================================
      def update
        # @profile is loaded by before_action :load_profile
        authorize! :update, @profile

        if @profile.update(profile_params)
          render_success(ProfileSerializer.new(@profile))
        else
          render_error("profile_update_failed", @profile.errors.full_messages, :unprocessable_entity)
        end
      end

      private

      def load_profile
        @profile = current_user.profile

        render_error("profile_not_found", ["Profile not found. Create one first."], :not_found) unless @profile
      end

      # =========================================================================
      # STRONG PARAMETERS
      # =========================================================================
      # Only permit safe profile attributes.
      # user_id is NOT permitted — it's always set from current_user (secure).
      # =========================================================================
      def profile_params
        params.require(:profile).permit(:bio, :website_url, :location)
      end
    end
  end
end
