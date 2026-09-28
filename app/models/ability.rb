# frozen_string_literal: true

# =============================================================================
# ABILITY MODEL — CanCanCan Authorization
# =============================================================================
#
# This is the SINGLE SOURCE OF TRUTH for all authorization rules.
# Every permission check in the application ultimately flows through here.
#
# HOW CANCANCAN WORKS:
#   1. ApplicationController defines `current_ability` which instantiates
#      this class: `Ability.new(current_user)`
#
#   2. In controllers, we call:
#        authorize! :read, @project
#        authorize! :create, Comment
#        @projects = Project.accessible_by(current_ability)
#
#   3. `authorize!` calls `can?(:read, @project)` internally.
#      If it returns false → raises CanCan::AccessDenied → 403 Forbidden.
#
#   4. `accessible_by(current_ability)` generates a WHERE clause to
#      return only records the user can :read. Avoids loading all records
#      and filtering in Ruby.
#
# PERMISSION STRUCTURE:
#
#   GUEST (no user / nil):
#     - No permissions (doorkeeper_authorize! prevents access before Ability)
#
#   MEMBER (role: 0):
#     - Read any project, task, comment
#     - Manage own resources (CRUD on own projects, own comments)
#     - Manage own profile
#     - Create tasks in projects they own
#     - Assign tasks to themselves
#
#   ADMIN (role: 1):
#     - Manage EVERYTHING (:manage, :all = full CRUD on all models)
#
# RULE SYNTAX:
#   can :action, ModelClass           — applies to ALL instances
#   can :action, ModelClass, column: value  — SQL WHERE condition
#   can :action, ModelClass { |obj| ... }  — Ruby block for complex checks
#   cannot :action, Model          — explicit deny (evaluated after `can`)
# =============================================================================

class Ability
  include CanCan::Ability

  # ===========================================================================
  # INITIALIZE
  # ===========================================================================
  # Called by ApplicationController#current_ability for every request.
  # `user` is the current authenticated User (or nil for unauthenticated,
  # though Doorkeeper prevents nil in practice for protected endpoints).
  # ===========================================================================
  def initialize(user)
    # -------------------------------------------------------------------------
    # UNAUTHENTICATED / NIL USER
    # -------------------------------------------------------------------------
    # Doorkeeper's `doorkeeper_authorize!` prevents reaching controllers
    # without a valid token, so this is a safety net.
    # -------------------------------------------------------------------------
    return if user.nil?

    # -------------------------------------------------------------------------
    # ADMIN — Full Access
    # -------------------------------------------------------------------------
    # `can :manage, :all` grants every action (:create, :read, :update,
    # :destroy, and any custom actions) on every model.
    #
    # This is the broadest possible permission. Admins bypass all other rules.
    # -------------------------------------------------------------------------
    if user.admin?
      can :manage, :all
      return # No need to process member rules for admins
    end

    # -------------------------------------------------------------------------
    # MEMBER — Granular Permissions
    # -------------------------------------------------------------------------

    # --- USERS ---
    # Members can read their own profile and update themselves.
    # They cannot read other users' private data.
    can :read, User, id: user.id
    can %i[update destroy], User, id: user.id

    # Members can see basic info of all users (for assignment dropdowns etc.)
    can :read, User

    # --- PROFILES ---
    # Members can fully manage their own profile.
    can :manage, Profile, user_id: user.id

    # --- PROJECTS ---
    # Members can read ALL projects (collaboration use case).
    # Members can create projects (they become the owner).
    # Members can only update/destroy projects they OWN.
    can :read, Project
    can :create, Project
    can %i[update destroy], Project, owner_id: user.id

    # --- TASKS ---
    # Members can read all tasks (they need visibility for collaboration).
    # Members can create tasks in projects they own.
    # Members can update tasks assigned to them OR in their own projects.
    # Members can destroy tasks only in their own projects.
    can :read, Task
    can :create, Task, project: { owner_id: user.id }

    # Block-based rule: can update if they are the assignee OR project owner.
    can :update, Task do |task|
      task.assignee_id == user.id || task.project.owner_id == user.id
    end

    can :destroy, Task, project: { owner_id: user.id }

    # --- COMMENTS ---
    # Members can read all comments (public discussion).
    # Members can create comments on any project or task.
    # Members can destroy only their own comments.
    can :read, Comment
    can :create, Comment
    can :destroy, Comment, user_id: user.id

    # --- ACTIVE STORAGE ATTACHMENTS ---
    # Members can manage their own avatars.
    # Members can attach/detach documents from tasks in their projects.
    can :manage, ActiveStorage::Attachment do |attachment|
      attachment.record_type == "User" && attachment.record_id == user.id ||
        attachment.record_type == "Task" && attachment.record.project.owner_id == user.id
    end
  end
end
