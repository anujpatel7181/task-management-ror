# frozen_string_literal: true

# =============================================================================
# TASK DOCUMENTS CONTROLLER — api/v1/attachments/task_documents_controller.rb
# =============================================================================
#
# Manages Active Storage document attachments for Tasks.
# Pattern is identical to AvatarsController but scoped to Task#documents.
#
# ROUTES:
#   GET    /api/v1/tasks/:task_id/documents        → index  (list documents)
#   POST   /api/v1/tasks/:task_id/documents        → create (upload documents)
#   DELETE /api/v1/tasks/:task_id/documents/:id    → destroy (remove a document)
#
# Use case: Attach spec PDFs, design files, meeting notes to a task.
# =============================================================================

module Api
  module V1
    module Attachments
      class TaskDocumentsController < ApplicationController
        before_action :find_task

        # =======================================================================
        # GET /api/v1/tasks/:task_id/documents
        # =======================================================================
        def index
          authorize! :read, @task

          # Active Storage: @task.documents returns ActiveStorage::Attached::Many
          # .map builds a safe representation of each blob/attachment.
          documents = @task.documents.map do |doc|
            {
              id: doc.id,
              filename: doc.filename.to_s,
              content_type: doc.content_type,
              byte_size: doc.byte_size,
              url: rails_blob_url(doc, only_path: false)
            }
          end

          render_success({ documents: documents, total: documents.count })
        end

        # =======================================================================
        # POST /api/v1/tasks/:task_id/documents
        # =======================================================================
        # Upload one or more files. Must be multipart/form-data.
        # Request: documents[] = <file1>, documents[] = <file2>
        #
        # AUTHORIZATION:
        #   Only project owners (or admins) can attach documents to tasks.
        #   Assignees who don't own the project cannot upload documents
        #   (per the Ability block rule).
        # =======================================================================
        def create
          # authorize! uses the block-based rule in Ability:
          #   can :update, Task do |task|
          #     task.assignee_id == user.id || task.project.owner_id == user.id
          #   end
          authorize! :update, @task

          uploaded_files = params[:documents]
          unless uploaded_files.present?
            return render_error("no_files", ["No document files provided"], :bad_request)
          end

          # Active Storage attach method handles both single file and array.
          # Each UploadedFile is stored in the configured storage service.
          @task.documents.attach(uploaded_files)

          render_success({ message: "#{uploaded_files.length} document(s) attached to task." }, :created)
        end

        # =======================================================================
        # DELETE /api/v1/tasks/:task_id/documents/:id
        # =======================================================================
        # Removes a specific document attachment.
        # `purge_later` uses Active Job for async deletion (storage backend + DB records).
        # =======================================================================
        def destroy
          authorize! :update, @task

          attachment = @task.documents.find { |d| d.id == params[:id].to_i }
          unless attachment
            return render_error("attachment_not_found",
                                ["Document with id #{params[:id]} not found"], :not_found)
          end

          attachment.purge_later
          render_success({ message: "Document removed from task." })
        end

        private

        def find_task
          @task = Task.find(params[:task_id])
        end
      end
    end
  end
end
