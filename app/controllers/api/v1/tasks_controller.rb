# frozen_string_literal: true

# =============================================================================
# TASKS CONTROLLER — api/v1/tasks_controller.rb
# =============================================================================
#
# Manages Tasks within Projects. Supports creating top-level tasks and sub-tasks.
# Tasks can have Active Storage document attachments.
#
# ROUTES (shallow nesting):
#   GET    /api/v1/projects/:project_id/tasks   → index  (list tasks in a project)
#   POST   /api/v1/projects/:project_id/tasks   → create (create task in project)
#   GET    /api/v1/tasks/:id                    → show
#   PATCH  /api/v1/tasks/:id                    → update
#   DELETE /api/v1/tasks/:id                    → destroy
#
# WHY SHALLOW NESTING?
#   Shallow nesting (`shallow: true` in routes) gives us:
#   - /projects/:project_id/tasks     → scoped index + create (need context)
#   - /tasks/:id                      → show/update/destroy (id is already unique)
#   This avoids long redundant URLs like /projects/1/tasks/5 when /tasks/5 is unique.
#
# ACTIVE STORAGE DOCUMENTS:
#   Task documents are handled by a separate attachments controller.
#   See: app/controllers/api/v1/attachments/task_documents_controller.rb
#   Documents are permitted in task params for initial upload during create/update.
#
# SUB-TASKS:
#   To create a sub-task, include `parent_task_id` in the request body.
#   The parent task must belong to the same project.
# =============================================================================

module Api
  module V1
    class TasksController < ApplicationController
      # =========================================================================
      # BEFORE ACTIONS
      # =========================================================================
      # Set @project for index and create (they need project scope).
      before_action :find_project, only: %i[index create]

      # Load @task for show/update/destroy.
      before_action :find_task, only: %i[show update destroy]

      # =========================================================================
      # GET /api/v1/projects/:project_id/tasks
      # =========================================================================
      # Lists tasks for a specific project.
      # Optional query params: ?status=todo, ?priority=high, ?assignee_id=5
      # Supports returning top-level tasks only or all tasks (including sub-tasks).
      # =========================================================================
      def index
        # Authorize viewing tasks in this project.
        authorize! :read, Task

        # Scope tasks to the project, then apply optional filters.
        # `accessible_by` respects CanCanCan rules for tasks.
        @tasks = @project.tasks
                         .accessible_by(current_ability)
                         .then { |q| filter_tasks(q) }
                         .includes(:assignee, :sub_tasks, documents_attachments: :blob)
                         .recent

        render_success({ tasks: @tasks.map { |t| TaskSerializer.new(t) },
                         total: @tasks.count })
      end

      # =========================================================================
      # GET /api/v1/tasks/:id
      # =========================================================================
      # Returns full task details including sub_tasks, assignee, and document URLs.
      # =========================================================================
      def show
        authorize! :read, @task

        render_success(TaskSerializer.new(@task, include_sub_tasks: true, include_documents: true))
      end

      # =========================================================================
      # POST /api/v1/projects/:project_id/tasks
      # =========================================================================
      # Creates a new task in the specified project.
      # Optionally assign to a user and/or set a parent_task_id (for sub-tasks).
      #
      # Request body (JSON):
      #   {
      #     "task": {
      #       "title": "Build login page",
      #       "description": "...",
      #       "priority": "high",
      #       "status": "todo",
      #       "due_date": "2026-10-15",
      #       "assignee_id": 3,
      #       "parent_task_id": null
      #     }
      #   }
      #
      # For file attachments during creation, use multipart/form-data:
      #   task[title]=..., task[documents][]=<file1>, task[documents][]=<file2>
      # =========================================================================
      def create
        @task = @project.tasks.build(task_params)

        # CanCanCan: member can create tasks only in projects they own.
        # Ability: can :create, Task, project: { owner_id: user.id }
        authorize! :create, @task

        if @task.save
          render_success(TaskSerializer.new(@task), :created)
        else
          render_error("task_creation_failed", @task.errors.full_messages, :unprocessable_entity)
        end
      end

      # =========================================================================
      # PATCH /api/v1/tasks/:id
      # =========================================================================
      # Updates a task. Members can update tasks they're assigned to OR in their
      # owned projects.
      #
      # To add document attachments, use multipart/form-data with documents[].
      # Active Storage APPENDS to existing attachments (doesn't replace them).
      # To remove specific attachments, use the dedicated DELETE endpoint.
      # =========================================================================
      def update
        # CanCanCan block rule in Ability:
        #   can :update, Task do |task|
        #     task.assignee_id == user.id || task.project.owner_id == user.id
        #   end
        authorize! :update, @task

        if @task.update(task_params)
          render_success(TaskSerializer.new(@task, include_documents: true))
        else
          render_error("task_update_failed", @task.errors.full_messages, :unprocessable_entity)
        end
      end

      # =========================================================================
      # DELETE /api/v1/tasks/:id
      # =========================================================================
      # Destroys a task and ALL its sub_tasks recursively.
      # Also removes all comments and Active Storage documents.
      # =========================================================================
      def destroy
        # Ability: can :destroy, Task, project: { owner_id: user.id }
        authorize! :destroy, @task

        @task.destroy!
        render_success({ message: "Task '#{@task.title}' and all sub-tasks deleted." })
      end

      private

      def find_project
        @project = Project.find(params[:project_id])
      end

      def find_task
        @task = Task.find(params[:id])
      end

      # Apply optional query-parameter filters.
      def filter_tasks(tasks)
        tasks = tasks.where(status: params[:status]) if params[:status].present?
        tasks = tasks.where(priority: params[:priority]) if params[:priority].present?
        tasks = tasks.where(assignee_id: params[:assignee_id]) if params[:assignee_id].present?
        tasks = tasks.where(parent_task_id: nil) if params[:top_level] == "true"
        tasks
      end

      # =========================================================================
      # STRONG PARAMETERS
      # =========================================================================
      # `project_id` is set from the URL param (not from params body) to prevent
      # tasks from being "moved" to other projects via mass assignment.
      #
      # `documents: []` — accepts an ARRAY of uploaded files for Active Storage.
      # multipart/form-data request with task[documents][] = <file> binaries.
      #
      # Active Storage: when `task.documents` is in `task_params`, Rails calls
      #   task.documents.attach(params[:task][:documents])
      # internally, which appends new blobs to active_storage_attachments.
      # =========================================================================
      def task_params
        params.require(:task).permit(
          :title,
          :description,
          :status,
          :priority,
          :due_date,
          :assignee_id,
          :parent_task_id,
          documents: []    # Array of ActionDispatch::Http::UploadedFile objects
        )
      end
    end
  end
end
