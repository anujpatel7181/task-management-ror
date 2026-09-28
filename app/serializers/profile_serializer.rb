# frozen_string_literal: true

class ProfileSerializer < ActiveModel::Serializer
  attributes :id, :bio, :website_url, :location, :created_at, :updated_at

  belongs_to :user, serializer: UserSerializer
end
