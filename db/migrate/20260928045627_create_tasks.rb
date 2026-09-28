# frozen_string_literal: true

# =============================================================================
# MIGRATION: Create Tasks Table
# =============================================================================
# Tasks are the core work items. They belong to a Project, can be optionally
# assigned to a User, can be nested (sub-tasks via parent_task_id), and
# support Active Storage file attachments via `has_many_attached :documents`.
#
# SELF-REFERENTIAL association (sub-tasks):
#   parent_task_id — nullable FK → tasks.id (same table!)
#   A task with parent_task_id = NULL is a top-level task.
#   A task with parent_task_id = 5 is a sub-task of task #5.
#
# ASSIGNEE:
#   assignee_id — nullable FK → users.id
#   A task with assignee_id = NULL is unassigned.
#
# ACTIVE STORAGE (documents):
#   No column is needed here — Active Storage uses its own tables:
#     active_storage_blobs        — file metadata (filename, content_type, byte_size)
#     active_storage_attachments  — join (Task has_many_attached :documents)
#   The attachment is created via: task.documents.attach(io: file, filename: "doc.pdf")
#
# PRIORITY ENUM: 0=low, 1=medium (default), 2=high, 3=critical
# STATUS  ENUM:  0=todo (default), 1=in_progress, 2=review, 3=done, 4=cancelled
# =============================================================================
class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks do |t|
      # -------------------------------------------------------------------------
      # TITLE — Required. Short description of the task.
      # -------------------------------------------------------------------------
      t.string :title, null: false

      # -------------------------------------------------------------------------
      # DESCRIPTION — Optional. Longer explanation, acceptance criteria, etc.
      # -------------------------------------------------------------------------
      t.text :description

      # -------------------------------------------------------------------------
      # STATUS ENUM
      # 0=todo, 1=in_progress, 2=review, 3=done, 4=cancelled
      # -------------------------------------------------------------------------
      t.integer :status, null: false, default: 0

      # -------------------------------------------------------------------------
      # PRIORITY ENUM
      # 0=low, 1=medium (default), 2=high, 3=critical
      # -------------------------------------------------------------------------
      t.integer :priority, null: false, default: 1

      # -------------------------------------------------------------------------
      # DUE DATE — When the task should be completed. Optional.
      # -------------------------------------------------------------------------
      t.datetime :due_date

      # -------------------------------------------------------------------------
      # PROJECT (required FK)
      # Every task belongs to exactly one project.
      # ON DELETE CASCADE is handled by Ruby `dependent: :destroy` on Project.
      # -------------------------------------------------------------------------
      t.references :project, null: false, foreign_key: true

      # -------------------------------------------------------------------------
      # ASSIGNEE (optional FK → users)
      # assignee_id can be NULL (unassigned task).
      # `foreign_key: { to_table: :users }` — needed because column is
      # `assignee_id`, not `user_id`.
      # -------------------------------------------------------------------------
      t.references :assignee,
                   null: true,
                   foreign_key: { to_table: :users }

      # -------------------------------------------------------------------------
      # PARENT TASK (optional self-referential FK → tasks)
      # parent_task_id NULL = top-level task
      # parent_task_id = N  = sub-task of task N
      # `foreign_key: { to_table: :tasks }` — self-referential FK.
      # -------------------------------------------------------------------------
      t.references :parent_task,
                   null: true,
                   foreign_key: { to_table: :tasks }

      t.timestamps
    end

    # Performance indexes for common query patterns:
    add_index :tasks, :status                    # Task.todo, Task.in_progress
    add_index :tasks, :priority                  # Task.high.order(:due_date)
    add_index :tasks, :due_date                  # Task.overdue
    add_index :tasks, %i[project_id status]      # project.tasks.where(status:)
  end
end
