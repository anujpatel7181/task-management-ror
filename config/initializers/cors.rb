# frozen_string_literal: true

# =============================================================================
# CORS INITIALIZER
# =============================================================================
# Cross-Origin Resource Sharing (CORS) allows browsers on domain A to make
# requests to this API on domain B. Without CORS headers the browser blocks
# the request.
#
# In production, replace the wildcard "*" with your actual frontend origin(s):
#   origins "https://myapp.com", "https://staging.myapp.com"
#
# DO NOT use wildcard in production with credentials=true — browsers reject it.
# =============================================================================

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # ---------------------------------------------------------------------------
    # ALLOWED ORIGINS
    # "*" means any origin. Fine for a public API but dangerous if you rely on
    # HTTP-only cookies. Since we use Bearer tokens we're OK with wildcard in
    # development, but restrict in production.
    # ---------------------------------------------------------------------------
    origins ENV.fetch("CORS_ALLOWED_ORIGINS", "*")

    # ---------------------------------------------------------------------------
    # ALLOWED RESOURCE PATTERNS
    # Every route under "/" is accessible from the allowed origins.
    # ---------------------------------------------------------------------------
    resource "*",
      headers: :any,    # Accept any HTTP request headers from client
      methods: %i[get post put patch delete options head],
      # Expose the Authorization header so clients can read it if needed.
      expose: %w[Authorization],
      max_age: 600      # Cache preflight response for 10 minutes
  end
end
