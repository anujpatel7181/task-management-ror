# frozen_string_literal: true

# =============================================================================
# USER SERIALIZER
# =============================================================================
# Defines the JSON structure returned when a User object is rendered.
# Uses ActiveModelSerializers for declarative, reusable serialization.
#
# This prevents accidentally leaking sensitive fields like:
#   - encrypted_password
#   - reset_password_token
#   - unlock_token
#   - sign_in_count, last_sign_in_ip (tracking data)
#
# The serializer is the CONTRACT between our API and its clients.
# Only explicitly listed attributes are included in the response.
# =============================================================================
class UserSerializer < ActiveModel::Serializer
  # ============================================================================
  # PUBLIC ATTRIBUTES (always included)
  # ============================================================================
  attributes :id, :email, :full_name, :role, :created_at

  # ============================================================================
  # ASSOCIATIONS
  # ============================================================================
  # Including `has_one :profile` here would embed the profile in every user
  # response (N+1 risk). Instead, we provide it only when specifically requested.
  # See the `profile` attribute method below.
  # ============================================================================

  # ============================================================================
  # COMPUTED ATTRIBUTES
  # ============================================================================

  # Human-readable role display (e.g., "Member" instead of "member").
  attribute :role_label do
    object.role.capitalize
  end

  # Avatar URLs — we generate signed URLs for all attached avatars.
  attribute :avatar_urls do
    if object.avatars.attached?
      object.avatars.map do |avatar|
        # `rails_blob_url` generates the Active Storage URL for this blob.
        # This is a helper method available in serializers via the context.
        begin
          Rails.application.routes.url_helpers.rails_blob_url(
            avatar,
            host: ENV.fetch("APP_HOST", "localhost:3000")
          )
        rescue StandardError
          nil
        end
      end.compact
    else
      []
    end
  end
end
