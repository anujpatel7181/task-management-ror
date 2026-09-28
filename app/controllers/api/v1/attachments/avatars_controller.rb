# frozen_string_literal: true

# =============================================================================
# AVATARS CONTROLLER — api/v1/attachments/avatars_controller.rb
# =============================================================================
#
# Manages Active Storage avatar attachments for Users.
#
# ROUTES:
#   GET    /api/v1/users/:user_id/avatars          → index  (list avatar URLs)
#   POST   /api/v1/users/:user_id/avatars          → create (upload new avatars)
#   DELETE /api/v1/users/:user_id/avatars/:id      → destroy (remove a blob)
#
# HOW ACTIVE STORAGE WORKS:
#   User.has_many_attached :avatars creates:
#     active_storage_blobs        — stores file metadata (name, size, mime type,
#                                   checksum, key used for storage backend)
#     active_storage_attachments  — joins User to Blob
#                                   (record_type="User", record_id=user.id)
#
#   When you POST with files:
#     user.avatars.attach(io: file.tempfile, filename: file.original_filename,
#                         content_type: file.content_type)
#   Active Storage:
#     1. Calculates checksum of the file
#     2. Uploads to the configured service (local disk in dev, S3 in production)
#     3. Creates a blob record
#     4. Creates an attachment record linking user → blob
#
#   When you access user.avatars.first.url:
#     In development: generates a signed URL to the file on disk
#     In production:  generates a signed URL to the storage backend
#
# FILE UPLOAD FORMAT:
#   Multipart form-data request:
#     Content-Type: multipart/form-data
#     avatars[]=<file1>
#     avatars[]=<file2>
# =============================================================================

module Api
  module V1
    module Attachments
      class AvatarsController < ApplicationController
        before_action :find_user

        # =======================================================================
        # GET /api/v1/users/:user_id/avatars
        # =======================================================================
        # Returns URLs for all avatars attached to this user.
        # =========================================================================
        def index
          authorize! :read, @user

          # Build an array of avatar info hashes.
          # `rails_blob_url` generates a signed URL (works in production too).
          avatars = @user.avatars.map do |avatar|
            {
              id: avatar.id,
              filename: avatar.filename.to_s,
              content_type: avatar.content_type,
              byte_size: avatar.byte_size,
              # `url_for` generates the Blob URL via Active Storage routes.
              # In development: /rails/active_storage/blobs/...
              # In production: Signed S3/GCS URL with expiry
              url: rails_blob_url(avatar, only_path: false)
            }
          end

          render_success({ avatars: avatars, total: avatars.count })
        end

        # =======================================================================
        # POST /api/v1/users/:user_id/avatars
        # =======================================================================
        # Uploads one or more avatar images.
        #
        # REQUEST FORMAT (multipart/form-data):
        #   avatars[] = <binary file 1>
        #   avatars[] = <binary file 2>
        #
        # Active Storage does NOT replace existing avatars — it APPENDS.
        # To replace, first DELETE existing avatars, then upload new ones.
        # =======================================================================
        def create
          authorize! :update, @user

          # `params[:avatars]` is an Array of ActionDispatch::Http::UploadedFile objects.
          # Each has: .original_filename, .content_type, .tempfile (IO object)
          uploaded_files = params[:avatars]

          unless uploaded_files.present?
            return render_error("no_files", ["No avatar files provided"], :bad_request)
          end

          # `attach` accepts:
          #   - A single UploadedFile
          #   - An array of UploadedFiles
          #   - A hash: { io:, filename:, content_type: }
          @user.avatars.attach(uploaded_files)

          render_success({ message: "#{uploaded_files.length} avatar(s) uploaded successfully." }, :created)
        end

        # =======================================================================
        # DELETE /api/v1/users/:user_id/avatars/:id
        # =======================================================================
        # Removes a specific avatar by its Active Storage Blob/Attachment ID.
        #
        # `:id` is the ActiveStorage::Attachment ID (not the blob's key).
        # We find the attachment and call `.purge` which:
        #   1. Deletes the file from the storage service
        #   2. Removes the active_storage_attachments record
        #   3. Removes the active_storage_blobs record (if no other references)
        # =======================================================================
        def destroy
          authorize! :update, @user

          # Find the specific attachment (not blob — user can have multiple attachments)
          attachment = @user.avatars.find { |a| a.id == params[:id].to_i }

          unless attachment
            return render_error("attachment_not_found",
                                ["Avatar with id #{params[:id]} not found"], :not_found)
          end

          # `purge` is synchronous (deletes immediately).
          # `purge_later` uses Active Job (asynchronous — better for production).
          attachment.purge_later

          render_success({ message: "Avatar removed." })
        end

        private

        def find_user
          @user = User.find(params[:user_id])
        end
      end
    end
  end
end
