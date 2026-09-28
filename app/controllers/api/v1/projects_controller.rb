# frozen_string_literal: true

# =============================================================================
# PROJECTS CONTROLLER — api/v1/projects_controller.rb
# =============================================================================
#
# Full CRUD for Projects. A project is owned by the current user.
#
# ROUTES:
#   GET    /api/v1/projects           → index
#   POST   /api/v1/projects           → create
#   GET    /api/v1/projects/:id       → show
#   PATCH  /api/v1/projects/:id       → update
#   DELETE /api/v1/projects/:id       → destroy
#
# AUTHENTICATION:
#   All actions require doorkeeper_authorize! (from ApplicationController).
#   Bearer token in Authorization header → current_user.
#
# AUTHORIZATION (CanCanCan):
#   :index   — Members see their own projects; admins see all.
#   :show    — Members can read any project.
#   :create  — Any member can create a project (they become the owner).
#   :update  — Only the project owner (or admin) can update.
#   :destroy — Only the project owner (or admin) can delete.
#
# OWNER ASSIGNMENT:
#   `owner` is ALWAYS set to current_user, not from params.
#   This prevents privilege escalation (user A creating a project for user B).
# =============================================================================

module Api
  module V1
    class ProjectsController < ApplicationController
      # =========================================================================
      # BEFORE ACTIONS
      # =========================================================================
      before_action :find_project, only: %i[show update destroy]

      # =========================================================================
      # GET /api/v1/projects
      # =========================================================================
      # Returns projects accessible to the current user.
      #
      # `accessible_by(current_ability)` is CanCanCan's powerful method that
      # generates a SQL WHERE clause based on the Ability rules instead of
      # loading all projects and filtering in Ruby.
      #
      # For members: returns all projects (Ability: can :read, Project)
      # For admins:  returns all projects (Ability: can :manage, :all)
      # =========================================================================
      def index
        # `accessible_by` automatically applies the CanCanCan rules as a WHERE clause.
        # This is more efficient than loading all projects and calling can?(:read, project).
        @projects = Project.accessible_by(current_ability).recent

        # authorize! collection is implicitly done by accessible_by.
        # We call authorize! :read, Project to satisfy check_authorization.
        authorize! :read, Project

        render_success({ projects: @projects.map { |p| ProjectSerializer.new(p) },
                         total: @projects.count })
      end

      # =========================================================================
      # GET /api/v1/projects/:id
      # =========================================================================
      def show
        # authorize! :read, @project uses Ability rules:
        # Member: can :read, Project → true (any project readable)
        # Admin: can :manage, :all → true
        authorize! :read, @project

        render_success(ProjectSerializer.new(@project, include_tasks: true))
      end

      # =========================================================================
      # POST /api/v1/projects
      # =========================================================================
      # Creates a new project owned by current_user.
      #
      # Request body:
      #   { "project": { "name": "...", "description": "...", "status": "active" } }
      # =========================================================================
      def create
        # Build the project, but FORCE owner to current_user.
        # Never trust owner from params — that would allow creating projects
        # on behalf of other users.
        @project = Project.new(project_params.merge(owner: current_user))

        # authorize! :create, Project — Ability: can :create, Project (any member)
        authorize! :create, @project

        if @project.save
          render_success(ProjectSerializer.new(@project), :created)
        else
          render_error("project_creation_failed", @project.errors.full_messages, :unprocessable_entity)
        end
      end

      # =========================================================================
      # PATCH /api/v1/projects/:id
      # =========================================================================
      def update
        # authorize! :update, @project
        # Ability (member): can :update, Project, owner_id: user.id
        # → raises 403 if @project.owner_id != current_user.id (for non-admins)
        authorize! :update, @project

        if @project.update(project_params)
          render_success(ProjectSerializer.new(@project))
        else
          render_error("project_update_failed", @project.errors.full_messages, :unprocessable_entity)
        end
      end

      # =========================================================================
      # DELETE /api/v1/projects/:id
      # =========================================================================
      # Destroys the project and all associated tasks + comments (cascade).
      # =========================================================================
      def destroy
        # Ability (member): can :destroy, Project, owner_id: user.id
        authorize! :destroy, @project

        @project.destroy!
        render_success({ message: "Project '#{@project.name}' deleted successfully." })
      end

      private

      def find_project
        # ActiveRecord::RecordNotFound is rescued globally in ApplicationController → 404.
        @project = Project.find(params[:id])
      end

      # =========================================================================
      # STRONG PARAMETERS
      # =========================================================================
      # `owner_id` is NOT permitted here — owner is always set from current_user.
      # `status` is permitted to allow status transitions (draft → active etc.)
      # =========================================================================
      def project_params
        params.require(:project).permit(:name, :description, :status)
      end
    end
  end
end
