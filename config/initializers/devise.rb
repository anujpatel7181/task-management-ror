# frozen_string_literal: true

# =============================================================================
# DEVISE INITIALIZER
# =============================================================================
# Devise configuration for API-only mode.
#
# Key differences from standard Devise (browser apps):
#   1. No session store — stateless JWT/OAuth token auth only.
#   2. No CSRF protection — handled at the API client level.
#   3. Navigational formats cleared — no HTML redirects on auth failure.
# =============================================================================

Devise.setup do |config|
  # ---------------------------------------------------------------------------
  # MAILER SETTINGS
  # Used for password reset and confirmation emails.
  # In production, set DEVISE_MAILER_SENDER in your environment.
  # ---------------------------------------------------------------------------
  config.mailer_sender = ENV.fetch("DEVISE_MAILER_SENDER", "no-reply@railsapilhub.com")

  # ---------------------------------------------------------------------------
  # ORM — Active Record
  # ---------------------------------------------------------------------------
  require "devise/orm/active_record"

  # ---------------------------------------------------------------------------
  # AUTHENTICATION KEYS
  # Users authenticate via email (case-insensitive).
  # ---------------------------------------------------------------------------
  config.authentication_keys = [:email]
  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]

  # ---------------------------------------------------------------------------
  # PASSWORD SETTINGS
  # Minimum 8 characters. Bcrypt cost is auto-tuned to ~100ms per hash.
  # ---------------------------------------------------------------------------
  config.password_length = 8..128
  config.email_regexp = /\A[^@\s]+@[^@\s]+\z/

  # ---------------------------------------------------------------------------
  # TOKEN SETTINGS FOR PASSWORD RESET
  # The reset token expires after this many hours for security.
  # ---------------------------------------------------------------------------
  config.reset_password_within = 6.hours
  config.sign_in_after_reset_password = false # API: clients re-authenticate

  # ---------------------------------------------------------------------------
  # LOCK SETTINGS
  # Lock an account after 5 failed sign-in attempts for 1 hour.
  # ---------------------------------------------------------------------------
  config.lock_strategy = :failed_attempts
  config.unlock_strategy = :time
  config.maximum_attempts = 5
  config.unlock_in = 1.hour

  # ---------------------------------------------------------------------------
  # NAVIGATIONAL FORMATS
  # Clearing this prevents Devise from issuing HTML redirects
  # (which would cause 406 errors in an API-only app).
  # ---------------------------------------------------------------------------
  config.navigational_formats = []

  # ---------------------------------------------------------------------------
  # SKIP SESSION STORAGE
  # Tells Devise not to store anything in the session (we use tokens).
  # ---------------------------------------------------------------------------
  config.skip_session_storage = [:http_auth, :params_auth]

  # ---------------------------------------------------------------------------
  # SIGN OUT VIA HTTP DELETE
  # Standard REST verb for logout endpoints.
  # ---------------------------------------------------------------------------
  config.sign_out_via = :delete

  # ---------------------------------------------------------------------------
  # RESPONDER
  # Use the HTTP-status-based responder (raises UnauthorizedError etc.)
  # rather than redirect-based responses.
  # ---------------------------------------------------------------------------
  # config.responder.error_status = :unprocessable_entity
  # config.responder.redirect_status = :see_other
end
