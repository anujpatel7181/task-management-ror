# frozen_string_literal: true

# =============================================================================
# PROJECT MODEL
# =============================================================================
#
# A Project is a container for Tasks and Comments. It is owned by one User
# (the creator/owner) and can have many Tasks and polymorphic Comments.
#
# ASSOCIATIONS:
#
#   belongs_to :owner, class_name: 'User'
#     - Every project must have an owner (the creating user).
#     - The `projects` table has `owner_id` (FK → users.id, NOT NULL).
#     - `class_name: 'User'` — because the association name `owner` doesn't
#       match the model name `User`, we must be explicit.
#     - `inverse_of: :owned_projects` — pairs with User#owned_projects.
#
#   has_many :tasks, dependent: :destroy
#     - A Project has many Tasks (standard one-to-many).
#     - `dependent: :destroy` — Rails calls task.destroy for each task,
#       firing ActiveRecord callbacks (e.g., destroying task's sub_tasks
#       and comments recursively).
#     - Alternative: use `dependent: :delete_all` for faster deletion
#       when you don't need callbacks (no sub-tasks).
#
#   has_many :comments, as: :commentable, dependent: :destroy
#     - POLYMORPHIC has_many. The `comments` table has:
#         commentable_type  STRING  (e.g., "Project")
#         commentable_id    INTEGER (e.g., 42)
#     - `as: :commentable` tells Rails to use these two columns for lookup:
#         WHERE commentable_type = 'Project' AND commentable_id = ?
#     - Projects and Tasks share the SAME comments table via polymorphism.
#     - `dependent: :destroy` — cascades when project is deleted.
#
# STATUS ENUM:
#   Tracks the project lifecycle: draft → active → completed → archived.
# =============================================================================

class Project < ApplicationRecord
  # ===========================================================================
  # ASSOCIATIONS
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # BELONGS TO: Project → User (as owner)
  # ---------------------------------------------------------------------------
  # `owner_id` column in `projects` table holds the FK.
  # `class_name: 'User'` is required because the method name is `owner`,
  # not `user`.
  #
  # Without inverse_of, calling project.owner.owned_projects would load a
  # NEW Project collection from the DB even if we already have the project.
  # inverse_of prevents that extra query.
  # ---------------------------------------------------------------------------
  belongs_to :owner, class_name: "User", inverse_of: :owned_projects

  # ---------------------------------------------------------------------------
  # HAS MANY: Project → Tasks
  # ---------------------------------------------------------------------------
  # Standard one-to-many with cascade destroy.
  # When a task is destroyed, its sub_tasks and comments are destroyed too
  # (because Task has `dependent: :destroy` on those).
  # ---------------------------------------------------------------------------
  has_many :tasks, dependent: :destroy

  # ---------------------------------------------------------------------------
  # POLYMORPHIC HAS MANY: Project → Comments (as commentable)
  # ---------------------------------------------------------------------------
  # Comments table schema (relevant columns):
  #   commentable_type  | commentable_id | body       | user_id
  #   "Project"         | 1              | "Great!"   | 5
  #   "Task"            | 3              | "Done."    | 2
  #
  # When you call project.comments, Rails generates:
  #   SELECT * FROM comments
  #   WHERE commentable_type = 'Project' AND commentable_id = <project.id>
  #
  # This allows Comments to be shared across Project, Task, and any future
  # commentable models WITHOUT extra join tables or separate comment tables.
  # ---------------------------------------------------------------------------
  has_many :comments, as: :commentable, dependent: :destroy

  # ===========================================================================
  # STATUS ENUM
  # ===========================================================================
  enum :status, { draft: 0, active: 1, completed: 2, archived: 3 }

  # ===========================================================================
  # VALIDATIONS
  # ===========================================================================
  validates :name, presence: true, length: { minimum: 3, maximum: 200 }
  validates :description, length: { maximum: 5000 }, allow_blank: true
  validates :status, presence: true

  # ===========================================================================
  # SCOPES
  # ===========================================================================
  scope :recent, -> { order(created_at: :desc) }
  scope :for_owner, ->(user) { where(owner: user) }

  # ===========================================================================
  # CALLBACKS
  # ===========================================================================
  before_validation :set_default_status, on: :create

  private

  def set_default_status
    self.status ||= :active
  end
end
