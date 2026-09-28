# frozen_string_literal: true

class CommentSerializer < ActiveModel::Serializer
  attributes :id, :body, :commentable_type, :commentable_id, :created_at, :updated_at

  belongs_to :user, serializer: UserSerializer

  attribute :author_name do
    object.user.display_name
  end
end
