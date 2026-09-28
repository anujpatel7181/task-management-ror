# frozen_string_literal: true

# =============================================================================
# USER MODEL
# =============================================================================
#
# The User is the central actor in this application.
# Every other resource ultimately belongs to or is created by a User.
#
# ASSOCIATIONS:
#   has_one  :profile
#     - One-to-one. User can have a richer profile (bio, website, etc.)
#     - `dependent: :destroy` — deleting a User cascades to Profile in Ruby
#       (in addition to the DB cascade on the migration's foreign key).
#
#   has_many :owned_projects
#     - A User can own many Projects (they are the Project's creator/owner).
#     - `foreign_key: 'owner_id'` — in the `projects` table the column is
#       `owner_id`, not `user_id`. Class name must be explicit too.
#     - `dependent: :destroy` — owned projects are destroyed when user is.
#
#   has_many :assigned_tasks
#     - A User can be assigned to many Tasks.
#     - `foreign_key: 'assignee_id'` — same pattern as above.
#     - `optional: true` is on the Task side (a task need not have an assignee).
#     - `dependent: :nullify` — if user deleted, set tasks.assignee_id = NULL.
#
#   has_many_attached :avatars
#     - Active Storage polymorphic attachment.
#     - Stores files in the configured Active Storage service (local in dev,
#       S3/GCS/Azure in production).
#     - Under the hood, creates records in:
#         active_storage_blobs (file metadata + checksum)
#         active_storage_attachments (join: User has many blobs)
#     - Access: user.avatars → ActiveStorage::Attached::Many proxy
#               user.avatars.attach(io: file, filename: "avatar.jpg")
#               user.avatars.first.url  # public URL
#
# DEVISE MODULES:
#   :database_authenticatable — password hashing with bcrypt
#   :registerable             — User.new / user.save to register
#   :recoverable              — Password reset via email token
#   :rememberable             — "Remember me" cookie (not used in API)
#   :validatable              — Validates email format and password length
#   :lockable                 — Locks account after N failed attempts
#   :trackable                — Tracks sign_in_count, last_sign_in_at (optional)
#
# ROLE ENUM:
#   member — Default role. Can read/create own resources.
#   admin  — Can manage all resources.
#
#   Enum maps symbols to integers in the DB (column: role INTEGER).
#   Usage:
#     user.admin?     → true/false
#     user.admin!     → sets role to admin and saves
#     User.admin      → scope returning all admins
# =============================================================================

class User < ApplicationRecord
  # ===========================================================================
  # DEVISE MODULES
  # ===========================================================================
  # We include the modules needed for API-based authentication.
  # :omniauthable and :confirmable are excluded here to keep things simple,
  # but they can be added as needed.
  # ===========================================================================
  devise :database_authenticatable,
         :registerable,
         :recoverable,
         :rememberable,
         :validatable,
         :lockable,
         :trackable

  # ===========================================================================
  # ROLE ENUM
  # ===========================================================================
  # Stored as an integer in the `role` column (NOT NULL, default: 0).
  # The enum macro provides:
  #   - Scopes:    User.member, User.admin
  #   - Predicates: user.member?, user.admin?
  #   - Bang methods: user.admin!
  #   - Validation: raises ArgumentError on invalid role value
  #
  # _prefix: :role adds role_ prefix to avoid name clashes:
  #   user.role_admin? instead of user.admin? (clearer in models)
  # ===========================================================================
  enum :role, { member: 0, admin: 1 }

  # ===========================================================================
  # ASSOCIATIONS
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # ONE-TO-ONE: User → Profile
  # ---------------------------------------------------------------------------
  # A User has exactly one Profile (created separately after registration).
  # Using `dependent: :destroy` means Rails calls profile.destroy when the
  # user is deleted, which fires ActiveRecord callbacks on Profile.
  # (The DB migration also has a foreign key for data integrity.)
  # ---------------------------------------------------------------------------
  has_one :profile, dependent: :destroy

  # ---------------------------------------------------------------------------
  # ONE-TO-MANY: User → Projects (as owner)
  # ---------------------------------------------------------------------------
  # The `projects` table has an `owner_id` column (integer FK → users.id).
  # We name the association `owned_projects` to distinguish from projects
  # the user might be a member of (future feature).
  #
  # `class_name: 'Project'` is required because Rails cannot infer the class
  # from the association name `owned_projects`.
  # ---------------------------------------------------------------------------
  has_many :owned_projects,
           class_name: "Project",
           foreign_key: "owner_id",
           dependent: :destroy,
           inverse_of: :owner

  # ---------------------------------------------------------------------------
  # ONE-TO-MANY: User → Tasks (as assignee)
  # ---------------------------------------------------------------------------
  # The `tasks` table has an `assignee_id` column (nullable FK → users.id).
  # Using `dependent: :nullify` so that deleting a user sets tasks.assignee_id
  # to NULL rather than cascading deletes (tasks belong to Projects, not Users).
  # ---------------------------------------------------------------------------
  has_many :assigned_tasks,
           class_name: "Task",
           foreign_key: "assignee_id",
           dependent: :nullify,
           inverse_of: :assignee

  # ---------------------------------------------------------------------------
  # ONE-TO-MANY: User → Comments
  # ---------------------------------------------------------------------------
  # A User can author many Comments on any commentable resource.
  # `dependent: :destroy` — deleting user removes their comments.
  # ---------------------------------------------------------------------------
  has_many :comments, dependent: :destroy

  # ---------------------------------------------------------------------------
  # ACTIVE STORAGE: Multiple Avatars
  # ---------------------------------------------------------------------------
  # `has_many_attached` creates a polymorphic attachment point named :avatars.
  # Multiple files can be attached (gallery-style avatar history).
  #
  # To upload in an API request:
  #   params[:avatars] — an array of ActionDispatch::Http::UploadedFile objects
  #   user.avatars.attach(params[:avatars])
  #
  # In the controller we use:
  #   params.permit(avatars: [])   # permit an array of files
  #
  # URLs: user.avatars.map { |a| url_for(a) }
  # ---------------------------------------------------------------------------
  has_many_attached :avatars

  # ===========================================================================
  # VALIDATIONS
  # ===========================================================================
  # Devise's :validatable module already validates:
  #   - email presence, format, uniqueness
  #   - password presence, length (8-128 chars per our Devise initializer)
  #
  # We add custom validations here:
  # ===========================================================================

  # Full name is required for display across the application.
  validates :full_name, presence: true, length: { minimum: 2, maximum: 100 }

  # Role must be one of the enum values (enum handles this, but explicit is safer).
  validates :role, presence: true, inclusion: { in: roles.keys }

  # ===========================================================================
  # CALLBACKS
  # ===========================================================================

  # Normalize email to lowercase before validation runs.
  # Devise's :case_insensitive_keys handles this too, but belt-and-suspenders.
  before_validation :normalize_email

  # ===========================================================================
  # SCOPES
  # ===========================================================================

  # Return users ordered by creation date (newest first).
  scope :recent, -> { order(created_at: :desc) }

  # ===========================================================================
  # INSTANCE METHODS
  # ===========================================================================

  # Doorkeeper / CanCanCan integration helper.
  # Returns a human-readable display name for use in serializers/logs.
  def display_name
    full_name.presence || email.split("@").first
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end
end
