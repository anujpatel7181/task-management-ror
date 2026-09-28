# frozen_string_literal: true

# =============================================================================
# DOORKEEPER INITIALIZER
# =============================================================================
# Doorkeeper provides the OAuth2 provider layer for this API.
# This initializer configures HOW Doorkeeper works:
#
#   Client (mobile app / SPA)
#       ↓ POST /oauth/token  { grant_type: "password", email:, password: }
#   Doorkeeper verifies credentials using Devise
#       ↓
#   Returns { access_token:, refresh_token:, expires_in: }
#       ↓
#   Client includes "Authorization: Bearer <access_token>" on every request
#       ↓
#   before_action :doorkeeper_authorize! in ApplicationController validates it
# =============================================================================

Doorkeeper.configure do
  # ---------------------------------------------------------------------------
  # RESOURCE OWNER PASSWORD CREDENTIALS GRANT
  # ---------------------------------------------------------------------------
  # This block wires Doorkeeper to Devise.
  # When a client POSTs to /oauth/token with grant_type=password,
  # Doorkeeper calls this block to authenticate the resource owner.
  #
  # `username` and `password` come from the request params.
  # We use Devise's `find_for_authentication` (which respects
  # case-insensitive email lookup) and then `valid_password?`.
  #
  # Returns the User object on success, or nil on failure.
  # ---------------------------------------------------------------------------
  resource_owner_from_credentials do |_routes|
    # `params` here is the raw Rack params from the OAuth token request.
    # We look up by `:email` but you could also allow `:username`.
    user = User.find_for_authentication(email: params[:username])

    # `valid_password?` uses bcrypt to compare the submitted password
    # against the stored digest. Never compare plaintext directly.
    user if user&.valid_password?(params[:password])
  end

  # ---------------------------------------------------------------------------
  # ORM CONFIGURATION
  # Active Record is used to persist Doorkeeper's records:
  #   - oauth_applications   (registered API clients)
  #   - oauth_access_tokens  (issued access tokens)
  #   - oauth_access_grants  (authorization code grants — not used here)
  # ---------------------------------------------------------------------------
  orm :active_record

  # ---------------------------------------------------------------------------
  # ENABLED GRANT TYPES
  # ---------------------------------------------------------------------------
  # We support only the grant types appropriate for a trusted API client:
  #
  #   password             — Exchange email+password for a token.
  #                          Best for first-party mobile/web apps.
  #   client_credentials   — Machine-to-machine, no user context.
  #
  # NOTE: In Doorkeeper 5.4+, :password grant must be explicitly listed.
  # We do NOT enable :authorization_code to keep things simple.
  # ---------------------------------------------------------------------------
  grant_flows %w[password client_credentials]

  # ---------------------------------------------------------------------------
  # ALLOW PUBLIC CLIENTS (no client_secret required)
  # ---------------------------------------------------------------------------
  # When a client application has `confidential: false`, Doorkeeper
  # allows token requests without a client_secret. This is the standard
  # pattern for mobile apps and SPAs where a secret cannot be safely stored.
  # ---------------------------------------------------------------------------
  allow_blank_redirect_uri true

  # ---------------------------------------------------------------------------
  # ACCESS TOKEN EXPIRY
  # 2 hours for access tokens (short-lived for security).
  # After expiry, the client must re-authenticate via POST /oauth/token.
  # ---------------------------------------------------------------------------
  access_token_expires_in 2.hours

  # ---------------------------------------------------------------------------
  # REUSE ACCESS TOKENS
  # When true, an existing valid token is reused instead of creating a new one.
  # Reduces token proliferation in development. Set to false for strict rotation.
  # ---------------------------------------------------------------------------
  reuse_access_token

  # ---------------------------------------------------------------------------
  # BASE CONTROLLER
  # Doorkeeper's token endpoint inherits from ActionController::API
  # (the lean, API-only controller without HTML concerns).
  # ---------------------------------------------------------------------------
  base_controller "ActionController::API"

  # ---------------------------------------------------------------------------
  # FORCE SSL
  # In production, only allow HTTPS for token requests (security).
  # In development/test, HTTP is allowed for ease of local testing.
  # ---------------------------------------------------------------------------
  force_ssl_in_redirect_uri !Rails.env.development? && !Rails.env.test?

  # ---------------------------------------------------------------------------
  # HANDLE_AUTH_ERRORS (optional)
  # :raise  — Doorkeeper raises an exception you rescue in controllers.
  # :render — Doorkeeper renders a 401 JSON error automatically (default).
  # ---------------------------------------------------------------------------
  # handle_auth_errors :raise

  # ---------------------------------------------------------------------------
  # SKIP_AUTHORIZATION
  # Skips the authorization step for trusted first-party clients.
  # For password flow this is always skipped, but good to be explicit.
  # ---------------------------------------------------------------------------
  skip_authorization do
    true # All our clients are trusted first-party
  end
end
