# frozen_string_literal: true

source "https://rubygems.org"

# ============================================================
# CORE FRAMEWORK
# Rails 8.x API-only mode — no ActionView, no cookie sessions.
# API-only mode is set in config/application.rb via
#   config.api_only = true
# which strips out middleware unnecessary for JSON APIs.
# ============================================================
gem "rails", "~> 8.1.3", ">= 8.1.3.1"

# ============================================================
# DATABASE
# PostgreSQL adapter for ActiveRecord.
# Provides connection pooling, prepared statements, and
# support for PostgreSQL-specific features (jsonb, arrays, etc.)
# ============================================================
gem "pg", "~> 1.1"

# ============================================================
# WEB SERVER
# Puma — multi-threaded Rack HTTP server, default in Rails.
# Handles concurrent requests efficiently in production.
# ============================================================
gem "puma", ">= 5.0"

# ============================================================
# AUTHENTICATION — DEVISE
# Devise provides full authentication stack:
#   - Database-backed user accounts (Authenticatable)
#   - Password hashing via bcrypt (Encryptable)
#   - Email validation & password recovery (Recoverable)
#   - Account locking after N failed attempts (Lockable)
#   - Token-based remembering (Rememberable)
#
# In API-only mode we disable session-based auth and rely
# on Doorkeeper OAuth tokens instead.
# ============================================================
gem "devise", "~> 4.9"

# ============================================================
# AUTHENTICATION — DOORKEEPER (OAuth2)
# Doorkeeper adds a full OAuth2 provider to the app.
# It integrates with Devise users as the resource owner.
#
# Supported grant types we enable:
#   - password:           POST /oauth/token with email+password
#   - refresh_token:      Exchange a refresh token for a new access token
#   - client_credentials: Machine-to-machine tokens (future use)
#
# Every protected API endpoint calls:
#   before_action :doorkeeper_authorize!
# which validates the Bearer token in the Authorization header.
# ============================================================
gem "doorkeeper", "~> 5.7"

# ============================================================
# AUTHORIZATION — CANCANCAN
# CanCanCan provides role-based access control through a
# central Ability class (app/models/ability.rb).
#
# Usage in controllers:
#   authorize! :read, @project   # raises CanCan::AccessDenied if not allowed
#   @projects = Project.accessible_by(current_ability)
#
# Abilities are defined once and applied consistently across
# all controllers and background jobs.
# ============================================================
gem "cancancan", "~> 3.5"

# ============================================================
# JSON SERIALIZATION
# active_model_serializers — declarative, class-based
# serializers that shape JSON responses cleanly.
# Separates serialization concerns from models/controllers.
# ============================================================
gem "active_model_serializers", "~> 0.10.14"

# ============================================================
# CORS (Cross-Origin Resource Sharing)
# rack-cors allows JavaScript frontends on different origins
# to make API requests by setting proper CORS headers.
# Configured in config/initializers/cors.rb
# ============================================================
gem "rack-cors", "~> 2.0"

# ============================================================
# PERFORMANCE & CACHING
# ============================================================
# Solid Cache — database-backed Rails cache store.
gem "solid_cache"
# Solid Queue — database-backed Active Job backend.
gem "solid_queue"
# Solid Cable — database-backed Action Cable adapter.
gem "solid_cable"
# Bootsnap — reduces boot time by caching require resolution.
gem "bootsnap", require: false

# ============================================================
# ACTIVE STORAGE — IMAGE PROCESSING
# image_processing provides MiniMagick/Vips transformations
# for images attached via Active Storage (has_one_attached,
# has_many_attached). Required for variants (thumbnails, etc.)
# ============================================================
gem "image_processing", "~> 1.2"

# ============================================================
# UTILITIES
# ============================================================
# Windows timezone data — no-op on macOS/Linux.
gem "tzinfo-data", platforms: %i[windows jruby]

# ============================================================
# DEPLOYMENT (optional, not required for local dev)
# ============================================================
gem "kamal", require: false
gem "thruster", require: false

# ============================================================
# DEVELOPMENT & TEST
# ============================================================
group :development, :test do
  # Debugger — use `binding.break` or `debugger` in code.
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"

  # Security audit for known CVEs in gem dependencies.
  gem "bundler-audit", require: false

  # Static analysis scanner for security vulnerabilities.
  gem "brakeman", require: false

  # Rails-opinionated RuboCop rules.
  gem "rubocop-rails-omakase", require: false

  # FactoryBot — test data factories (used in seeds too).
  gem "factory_bot_rails", "~> 6.4"

  # Faker — realistic fake data for seeds and tests.
  gem "faker", "~> 3.4"
end

group :development do
  # Listen for file changes to reload in dev.
  gem "listen", "~> 3.8"
end

group :test do
  # RSpec — BDD test framework (optional but recommended).
  # gem "rspec-rails", "~> 7.0"
  # gem "shoulda-matchers", "~> 6.0"
end
