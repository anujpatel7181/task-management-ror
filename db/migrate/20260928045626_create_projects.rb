# frozen_string_literal: true

# =============================================================================
# MIGRATION: Create Projects Table
# =============================================================================
# A Project is owned by one User (owner_id FK → users.id) and contains
# many Tasks and polymorphic Comments.
#
# NAMING CONVENTION for owner FK:
#   We use `owner_id` instead of `user_id` because the association
#   on the User model is named `owned_projects`. Rails convention maps
#   `belongs_to :owner, class_name: 'User'` to `owner_id` column.
#
# STATUS ENUM:
#   0 = draft, 1 = active (default), 2 = completed, 3 = archived
#   Stored as INTEGER for performance; mapped to symbols in Ruby.
# =============================================================================
class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      # -------------------------------------------------------------------------
      # NAME — Required. Project title visible in the UI.
      # -------------------------------------------------------------------------
      t.string :name, null: false

      # -------------------------------------------------------------------------
      # DESCRIPTION — Optional. Detailed description of the project.
      # -------------------------------------------------------------------------
      t.text :description

      # -------------------------------------------------------------------------
      # STATUS — Integer enum (draft: 0, active: 1, completed: 2, archived: 3)
      # Default 1 = active. NOT NULL.
      # -------------------------------------------------------------------------
      t.integer :status, null: false, default: 1

      # -------------------------------------------------------------------------
      # OWNER — FK to users.id using custom column name `owner_id`
      # `references :owner` generates:
      #   - `owner_id` integer column
      #   - Index on owner_id (for fast lookups: "all projects by this user")
      # `foreign_key: { to_table: :users }` creates the FK constraint pointing
      # to the users table (since Rails can't infer it from "owner").
      # -------------------------------------------------------------------------
      t.references :owner, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    # Index for fast filtering by status (e.g., Project.active).
    add_index :projects, :status
  end
end
