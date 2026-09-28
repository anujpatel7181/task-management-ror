# frozen_string_literal: true

# =============================================================================
# COMMENT MODEL
# =============================================================================
#
# A Comment is a polymorphic resource — it can be attached to ANY commentable
# model (currently: Project, Task) using a single `comments` table.
#
# POLYMORPHIC PATTERN:
#   Instead of having separate `project_comments` and `task_comments` tables,
#   we use one `comments` table with two special columns:
#
#     commentable_type  VARCHAR  — stores the class name ("Project" or "Task")
#     commentable_id    INTEGER  — stores the primary key of the parent record
#
#   This is Rails' built-in polymorphic association.
#
# ASSOCIATIONS:
#
#   belongs_to :user
#     - Every comment must have an author (user_id FK, NOT NULL).
#     - `inverse_of: :comments` enables in-memory association reuse.
#
#   belongs_to :commentable, polymorphic: true
#     - The `polymorphic: true` option tells Rails this belongs_to points
#       to different models depending on commentable_type.
#     - Rails automatically handles the two-column lookup:
#         WHERE commentable_type = 'Project' AND commentable_id = 1
#
# DATABASE INDEX:
#   The migration creates a composite index on (commentable_type, commentable_id)
#   for efficient polymorphic lookups. Without this, every `project.comments`
#   call would do a full table scan.
#
# USAGE EXAMPLES:
#   # Creating a comment on a project:
#   project.comments.create!(body: "Looking good!", user: current_user)
#
#   # Creating a comment on a task:
#   task.comments.create!(body: "Will fix tomorrow", user: current_user)
#
#   # comment.commentable returns the parent (Project or Task instance)
#   comment.commentable  # => #<Project id: 1, ...>
# =============================================================================

class Comment < ApplicationRecord
  # ===========================================================================
  # ASSOCIATIONS
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # BELONGS TO: Comment → User (author)
  # ---------------------------------------------------------------------------
  # Every comment has an author. `user_id` is NOT NULL in the DB.
  # We include `inverse_of` so that user.comments.first.user returns
  # the same user object from memory, not a new query.
  # ---------------------------------------------------------------------------
  belongs_to :user, inverse_of: :comments

  # ---------------------------------------------------------------------------
  # POLYMORPHIC BELONGS TO: Comment → Commentable (Project or Task)
  # ---------------------------------------------------------------------------
  # `polymorphic: true` activates two-column polymorphism:
  #   - comment.commentable_type  → "Project" or "Task"
  #   - comment.commentable_id    → the parent record's id
  #   - comment.commentable       → the actual Project or Task instance
  #
  # Rails generates a WHERE clause like:
  #   SELECT * FROM [model_table] WHERE id = commentable_id
  # where model_table is derived from commentable_type.
  #
  # This means you can call:
  #   comment.commentable          # => Project or Task object
  #   comment.commentable_type     # => "Project"
  #   comment.commentable_id       # => 42
  # ---------------------------------------------------------------------------
  belongs_to :commentable, polymorphic: true

  # ===========================================================================
  # VALIDATIONS
  # ===========================================================================

  # Comment body is required and has a max length.
  validates :body, presence: true, length: { minimum: 1, maximum: 5000 }

  # ===========================================================================
  # SCOPES
  # ===========================================================================
  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user) { where(user: user) }
end
