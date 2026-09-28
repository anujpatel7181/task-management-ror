# frozen_string_literal: true

# =============================================================================
# PROFILE MODEL
# =============================================================================
#
# Profile stores extended user information that is not needed for
# authentication but enriches the user's public/private persona.
#
# ASSOCIATIONS:
#   belongs_to :user
#     - Mandatory by default in Rails 5+.
#     - The `profiles` table has a `user_id` column (FK → users.id, NOT NULL).
#     - `inverse_of: :profile` tells Rails that User#profile and
#       Profile#user are the two sides of the same association, enabling
#       in-memory object reuse and avoiding extra queries.
#
# DATABASE:
#   The migration sets a UNIQUE index on `user_id` to enforce the
#   one-to-one relationship at the database level (not just in Ruby).
#   Without this index, multiple profiles per user could slip through
#   in a race condition.
# =============================================================================

class Profile < ApplicationRecord
  # ===========================================================================
  # ASSOCIATIONS
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # BELONGS TO: Profile → User (owner)
  # ---------------------------------------------------------------------------
  # Every Profile must have a User. Rails validates presence of user_id
  # automatically (since Rails 5, belongs_to is required by default).
  #
  # `inverse_of: :profile` enables:
  #   - user.profile.user == user  (no extra SQL query)
  #   - Correct validation of associated objects in memory
  # ---------------------------------------------------------------------------
  belongs_to :user, inverse_of: :profile

  # ===========================================================================
  # VALIDATIONS
  # ===========================================================================

  # Enforce one-to-one at the ActiveRecord level (DB has a unique index too).
  validates :user_id, uniqueness: true

  # Bio is optional but limited in length for UI rendering.
  validates :bio, length: { maximum: 1000 }, allow_blank: true

  # Website URL format validation (optional field).
  validates :website_url,
            format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]),
                      message: "must be a valid HTTP/HTTPS URL" },
            allow_blank: true

  # Location is optional — free text.
  validates :location, length: { maximum: 200 }, allow_blank: true
end
