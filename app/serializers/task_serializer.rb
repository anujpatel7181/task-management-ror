# frozen_string_literal: true

class TaskSerializer < ActiveModel::Serializer
  attributes :id, :title, :description, :status, :priority, :due_date,
             :project_id, :assignee_id, :parent_task_id, :created_at, :updated_at

  belongs_to :assignee, serializer: UserSerializer, if: -> { object.assignee_id.present? }

  attribute :status_label do
    object.status.humanize
  end

  attribute :priority_label do
    object.priority.humanize
  end

  attribute :sub_tasks_count do
    object.sub_tasks.size
  end

  # Document attachment URLs — includes metadata for each file
  attribute :document_urls do
    if object.documents.attached?
      object.documents.map do |doc|
        {
          id: doc.id,
          filename: doc.filename.to_s,
          content_type: doc.content_type,
          byte_size: doc.byte_size,
          url: begin
                 Rails.application.routes.url_helpers.rails_blob_url(
                   doc, host: ENV.fetch("APP_HOST", "localhost:3000")
                 )
               rescue StandardError
                 nil
               end
        }
      end
    else
      []
    end
  end
end
