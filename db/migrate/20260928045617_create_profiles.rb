# frozen_string_literal: true

# =============================================================================
# MIGRATION: Create Profiles Table
# =============================================================================
# Stores extended user information beyond what Devise needs for auth.
#
# UNIQUE INDEX on user_id enforces one-to-one relationship at the DB level.
# This is critical for data integrity — even if Ruby validation is bypassed
# (e.g., raw SQL inserts, race conditions), the DB will reject duplicates.
#
# FOREIGN KEY: user_id → users.id (with ON DELETE CASCADE in the FK constraint)
# The `foreign_key: true` option in the reference creates:
#   ALTER TABLE profiles ADD CONSTRAINT fk_profiles_users
#     FOREIGN KEY (user_id) REFERENCES users(id)
# This works with Rails' `dependent: :destroy` on the User side.
# =============================================================================
class CreateProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :profiles do |t|
      # -------------------------------------------------------------------------
      # FOREIGN KEY: user_id → users.id
      # `null: false` — every profile MUST have a user.
      # `foreign_key: true` — DB-level FK constraint (data integrity).
      # `index: { unique: true }` — enforces one-to-one at the DB level.
      # -------------------------------------------------------------------------
      t.references :user, null: false, foreign_key: true, index: { unique: true }

      # -------------------------------------------------------------------------
      # PROFILE FIELDS
      # -------------------------------------------------------------------------
      # Bio: freeform text about the user. NULL-allowed (optional).
      t.text :bio

      # Website URL: must be a valid HTTP/HTTPS URL (validated in model).
      t.string :website_url

      # Location: city, country, or any text. NULL-allowed.
      t.string :location

      t.timestamps
    end

  end
end
