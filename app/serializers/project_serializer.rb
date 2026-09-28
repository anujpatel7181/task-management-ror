# frozen_string_literal: true

class ProjectSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :status, :created_at, :updated_at

  belongs_to :owner, serializer: UserSerializer

  # Computed: task count
  attribute :tasks_count do
    object.tasks.size
  end

  attribute :status_label do
    object.status.humanize
  end
end
