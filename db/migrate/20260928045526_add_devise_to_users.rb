# frozen_string_literal: true

# =============================================================================
# MIGRATION: Create Users Table (with Devise modules)
# =============================================================================
# This migration creates the `users` table which is the backbone of
# authentication and authorization in this app.
#
# Devise modules included and their corresponding columns:
#   :database_authenticatable  → email, encrypted_password
#   :recoverable               → reset_password_token, reset_password_sent_at
#   :rememberable              → remember_created_at
#   :trackable                 → sign_in_count, current_sign_in_at,
#                                last_sign_in_at, current_sign_in_ip, last_sign_in_ip
#   :lockable                  → failed_attempts, locked_at, unlock_token
#
# Custom columns:
#   full_name  — Required display name (enforced by model validation)
#   role       — Integer enum: 0=member (default), 1=admin
#                Indexed for fast role-based queries.
# =============================================================================
class AddDeviseToUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      # -------------------------------------------------------------------------
      # DEVISE: Database Authenticatable
      # email            — Unique, case-insensitive login key.
      # encrypted_password — bcrypt hash (NEVER store plaintext passwords).
      # -------------------------------------------------------------------------
      t.string :email, null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      # -------------------------------------------------------------------------
      # DEVISE: Recoverable
      # reset_password_token    — Unique secure token sent in reset email.
      # reset_password_sent_at  — When the reset was requested (for expiry).
      # -------------------------------------------------------------------------
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      # -------------------------------------------------------------------------
      # DEVISE: Rememberable
      # remember_created_at — When "remember me" was set.
      # -------------------------------------------------------------------------
      t.datetime :remember_created_at

      # -------------------------------------------------------------------------
      # DEVISE: Trackable
      # -------------------------------------------------------------------------
      t.integer  :sign_in_count, default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip

      # -------------------------------------------------------------------------
      # DEVISE: Lockable
      # failed_attempts — Incremented on each failed login. Reset on success.
      # locked_at       — Set when account is locked; used for :time unlock.
      # unlock_token    — Used for :email unlock strategy.
      # -------------------------------------------------------------------------
      t.integer  :failed_attempts, default: 0, null: false
      t.string   :unlock_token
      t.datetime :locked_at

      # -------------------------------------------------------------------------
      # CUSTOM COLUMNS
      # -------------------------------------------------------------------------
      # full_name — Required. Display name shown across the app.
      t.string :full_name, null: false, default: ""

      # role — Integer-backed enum. 0=member (default), 1=admin.
      # NOT NULL with a default prevents null role bugs.
      t.integer :role, null: false, default: 0

      t.timestamps
    end

    # -------------------------------------------------------------------------
    # INDEXES
    # -------------------------------------------------------------------------
    add_index :users, :email,                unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, :unlock_token,         unique: true
    add_index :users, :role                  # fast scope: User.admin
  end
end
