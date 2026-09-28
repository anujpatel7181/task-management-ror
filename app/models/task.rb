# frozen_string_literal: true

# =============================================================================
# TASK MODEL
# =============================================================================
#
# A Task belongs to a Project and can optionally be assigned to a User.
# Tasks can be nested infinitely via self-referential associations (sub-tasks).
# Tasks can have file documents attached via Active Storage.
# Tasks support polymorphic Comments.
#
# ASSOCIATIONS (detailed):
#
# 1. belongs_to :project
#    - Every Task MUST belong to a Project (NOT NULL FK in DB).
#    - When a Project is destroyed, all its Tasks are destroyed (cascade).
#
# 2. belongs_to :assignee, class_name: 'User', optional: true
#    - A Task CAN be assigned to a User (nullable FK: assignee_id).
#    - `optional: true` disables Rails' automatic presence validation for
#      `assignee_id`, allowing unassigned tasks.
#    - When a User is destroyed, assignee_id is set to NULL (nullify).
#
# 3. belongs_to :parent_task, class_name: 'Task', optional: true
#    - SELF-REFERENTIAL: A Task can be a sub-task of another Task.
#    - `optional: true` — top-level tasks have no parent (parent_task_id = NULL).
#    - The `parent_task_id` column references `tasks.id` (same table).
#    - Example: Task "Build login page" → sub-task "Design mockup"
#
# 4. has_many :sub_tasks, class_name: 'Task', foreign_key: 'parent_task_id'
#    - The reverse of belongs_to :parent_task.
#    - A parent Task has many sub Tasks.
#    - `dependent: :destroy` — destroying a parent destroys all sub_tasks
#      recursively (because sub_tasks also have `dependent: :destroy`).
#    - WARNING: Deep nesting can cause N+1 destroy callbacks. Consider
#      using DB-level cascade or a closure_tree gem for deep trees.
#
# 5. has_many :comments, as: :commentable, dependent: :destroy
#    - Same polymorphic pattern as Project#comments.
#    - WHERE commentable_type = 'Task' AND commentable_id = <id>
#
# 6. has_many_attached :documents
#    - Multiple file attachments per task (PDFs, images, spreadsheets).
#    - Stored in Active Storage configured service.
#    - Controller permits: params.permit(documents: [])
#    - URLs: task.documents.map { |d| rails_blob_url(d) }
#
# PRIORITY ENUM:
#   low: 0, medium: 1, high: 2, critical: 3
#
# STATUS ENUM:
#   todo: 0, in_progress: 1, review: 2, done: 3, cancelled: 4
# =============================================================================

class Task < ApplicationRecord
  # ===========================================================================
  # ASSOCIATIONS
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # BELONGS TO: Task → Project (mandatory)
  # ---------------------------------------------------------------------------
  # The `tasks` table has `project_id` (FK → projects.id, NOT NULL).
  # A task cannot exist without a project.
  # ---------------------------------------------------------------------------
  belongs_to :project, inverse_of: :tasks

  # ---------------------------------------------------------------------------
  # BELONGS TO: Task → User (as assignee, optional)
  # ---------------------------------------------------------------------------
  # The `tasks` table has `assignee_id` (FK → users.id, NULLABLE).
  # `optional: true` tells Rails this FK is allowed to be NULL.
  # Without it, Rails would raise a validation error when saving
  # a task without an assignee.
  # ---------------------------------------------------------------------------
  belongs_to :assignee, class_name: "User", optional: true, inverse_of: :assigned_tasks

  # ---------------------------------------------------------------------------
  # SELF-REFERENTIAL: Task → Parent Task (optional)
  # ---------------------------------------------------------------------------
  # A Task can be a sub-task of another Task in the SAME table.
  # `optional: true` allows top-level tasks (parent_task_id = NULL).
  #
  # SQL when loading parent: SELECT * FROM tasks WHERE id = <parent_task_id>
  # ---------------------------------------------------------------------------
  belongs_to :parent_task, class_name: "Task", optional: true, inverse_of: :sub_tasks

  # ---------------------------------------------------------------------------
  # SELF-REFERENTIAL: Task → Sub-Tasks (has_many)
  # ---------------------------------------------------------------------------
  # The reverse side of belongs_to :parent_task.
  # `foreign_key: 'parent_task_id'` — the column in `tasks` that points
  # to the parent task's id.
  #
  # SQL when loading sub_tasks:
  #   SELECT * FROM tasks WHERE parent_task_id = <this_task.id>
  #
  # `dependent: :destroy` recursively destroys sub-tasks when a parent is deleted.
  # This means destroying task A also destroys task A's sub_tasks,
  # and THEIR sub_tasks, and so on (via Ruby callbacks, not DB cascade).
  #
  # For very large trees, consider using:
  #   `dependent: :delete_all` (skips callbacks, uses single SQL DELETE)
  # ---------------------------------------------------------------------------
  has_many :sub_tasks,
           class_name: "Task",
           foreign_key: "parent_task_id",
           dependent: :destroy,
           inverse_of: :parent_task

  # ---------------------------------------------------------------------------
  # POLYMORPHIC HAS MANY: Task → Comments (as commentable)
  # ---------------------------------------------------------------------------
  # Shares the same `comments` table with Project.
  # WHERE commentable_type = 'Task' AND commentable_id = <task.id>
  # ---------------------------------------------------------------------------
  has_many :comments, as: :commentable, dependent: :destroy

  # ---------------------------------------------------------------------------
  # ACTIVE STORAGE: Multiple Document Attachments
  # ---------------------------------------------------------------------------
  # `has_many_attached :documents` creates:
  #   - task.documents            → ActiveStorage::Attached::Many proxy
  #   - task.documents.attach(…)  → attach new files
  #   - task.documents.detach     → remove all attachments
  #   - task.documents_blobs      → join to ActiveStorage::Blob
  #
  # In the API controller, accept file uploads:
  #   params.require(:task).permit(:title, documents: [])
  #
  # Note: ActiveStorage doesn't validate file type/size automatically.
  # Add custom validations or use the `active_storage_validations` gem.
  # ---------------------------------------------------------------------------
  has_many_attached :documents

  # ===========================================================================
  # ENUMS
  # ===========================================================================

  # Priority affects how the task is sorted and displayed in the UI.
  enum :priority, { low: 0, medium: 1, high: 2, critical: 3 }

  # Status tracks the task through its lifecycle.
  enum :status, { todo: 0, in_progress: 1, review: 2, done: 3, cancelled: 4 }

  # ===========================================================================
  # VALIDATIONS
  # ===========================================================================
  validates :title, presence: true, length: { minimum: 3, maximum: 500 }
  validates :description, length: { maximum: 10_000 }, allow_blank: true
  validates :priority, :status, presence: true

  # Prevent a task from being its own parent (self-referential guard).
  validate :not_own_parent, if: :parent_task_id?

  # Due date must be in the future on creation.
  validates :due_date, comparison: { greater_than: -> { Time.current } },
            allow_nil: true, on: :create

  # ===========================================================================
  # SCOPES
  # ===========================================================================
  scope :top_level, -> { where(parent_task_id: nil) }
  scope :sub_tasks_of, ->(task) { where(parent_task: task) }
  scope :overdue, -> { where("due_date < ?", Time.current).where.not(status: :done) }
  scope :recent, -> { order(created_at: :desc) }

  # ===========================================================================
  # CALLBACKS
  # ===========================================================================
  before_validation :set_defaults, on: :create

  private

  def set_defaults
    self.priority ||= :medium
    self.status   ||= :todo
  end

  # Custom validation to prevent circular self-referential assignment.
  def not_own_parent
    errors.add(:parent_task_id, "can't be the task itself") if parent_task_id == id
  end
end
