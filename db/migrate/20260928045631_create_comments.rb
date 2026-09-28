# frozen_string_literal: true

# =============================================================================
# MIGRATION: Create Comments Table (Polymorphic)
# =============================================================================
# The comments table uses Rails polymorphic associations to allow one table
# to serve as comments for MULTIPLE parent models (Project, Task, etc.).
#
# POLYMORPHIC COLUMNS:
#   commentable_type  VARCHAR — the parent model class name ("Project", "Task")
#   commentable_id    INTEGER — the parent record's primary key
#
# HOW IT WORKS:
#   When you call `project.comments`, Rails generates:
#     SELECT * FROM comments
#     WHERE commentable_type = 'Project' AND commentable_id = <project.id>
#
#   When you call `task.comments`, Rails generates:
#     SELECT * FROM comments
#     WHERE commentable_type = 'Task' AND commentable_id = <task.id>
#
# COMPOSITE INDEX on (commentable_type, commentable_id):
#   This is CRITICAL for performance. Without it, every `record.comments`
#   call would do a full table scan as the comments table grows.
#   The `t.references :commentable, polymorphic: true` automatically
#   creates this composite index.
#
# IMPORTANT: Do NOT add a foreign_key constraint on the polymorphic columns
# because a FK can only point to ONE table, but commentable_type can be
# "Project" or "Task" (different tables). Data integrity is enforced by
# the `dependent: :destroy` associations on Project and Task.
# =============================================================================
class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      # -------------------------------------------------------------------------
      # BODY — The text content of the comment. Required.
      # Using `text` (not `string`) for unlimited length support.
      # -------------------------------------------------------------------------
      t.text :body, null: false

      # -------------------------------------------------------------------------
      # USER (author) FK
      # Every comment has an author (user_id FK → users.id, NOT NULL).
      # `foreign_key: true` creates the DB constraint.
      # -------------------------------------------------------------------------
      t.references :user, null: false, foreign_key: true

      # -------------------------------------------------------------------------
      # POLYMORPHIC REFERENCE
      # `polymorphic: true` generates TWO columns:
      #   - commentable_type  VARCHAR(255)  — "Project" or "Task"
      #   - commentable_id    INTEGER       — parent record's id
      #
      # AND a composite index: (commentable_type, commentable_id)
      # which is the index used by polymorphic lookups.
      #
      # NOTE: No `foreign_key: true` here — polymorphic FKs are not
      # supported at the DB level in PostgreSQL (a FK can only reference
      # one table). Data integrity relies on cascading deletes in Rails.
      # -------------------------------------------------------------------------
      t.references :commentable, polymorphic: true, null: false

      t.timestamps
    end
  end
end
