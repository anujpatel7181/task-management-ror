# frozen_string_literal: true

# =============================================================================
# DOORKEEPER MANAGEMENT RAKE TASKS
# =============================================================================
# Professional automation for managing OAuth2 client applications and tokens.
#
# USAGE EXAMPLES:
#
# 1. Create a public client (for Mobile App / SPA / Bruno / Postman):
#    $ bundle exec rails "doorkeeper:create_app[Mobile App, , false]"
#
# 2. Create a confidential client (for Backend Microservice with secret):
#    $ bundle exec rails "doorkeeper:create_app[Payment Service, https://service.internal/oauth/callback, true]"
#
# 3. List all registered OAuth applications:
#    $ bundle exec rails doorkeeper:list_apps
#
# 4. Revoke all active tokens for a specific user:
#    $ bundle exec rails "doorkeeper:revoke_user_tokens[alice@railshub.dev]"
# =============================================================================

namespace :doorkeeper do
  desc "Create a new Doorkeeper OAuth Application [name, redirect_uri, confidential, scopes]"
  task :create_app, %i[name redirect_uri confidential scopes] => :environment do |_t, args|
    name         = args[:name].presence || "Client Application #{SecureRandom.hex(4)}"
    redirect_uri = args[:redirect_uri].to_s.strip
    confidential = args[:confidential].nil? ? false : ActiveModel::Type::Boolean.new.cast(args[:confidential])
    scopes       = args[:scopes].to_s.strip

    app = Doorkeeper::Application.new(
      name: name,
      redirect_uri: redirect_uri,
      confidential: confidential,
      scopes: scopes
    )

    if app.save
      puts "\n" + ("=" * 65)
      puts "🎉 Doorkeeper OAuth Application Created Successfully!"
      puts ("=" * 65)
      puts "  Name:          #{app.name}"
      puts "  Client ID:     #{app.uid}"
      puts "  Client Secret: #{app.secret}"
      puts "  Confidential:  #{app.confidential?} #{app.confidential? ? '(Secret REQUIRED during token requests)' : '(Public client - Secret NOT required)'}"
      puts "  Redirect URI:  #{app.redirect_uri.presence || '(None - suitable for password flow / mobile / SPA)'}"
      puts "  Scopes:        #{app.scopes.presence || '(Default/All)'}"
      puts ("=" * 65)
      puts "\nSample curl request to test token generation:"
      puts <<~CURL
        curl -X POST http://localhost:3000/oauth/token \\
          -H "Content-Type: application/x-www-form-urlencoded" \\
          -d "grant_type=password" \\
          -d "username=admin@railshub.dev" \\
          -d "password=Admin@123456" \\
          -d "client_id=#{app.uid}"#{app.confidential? ? " \\\n  -d \"client_secret=#{app.secret}\"" : ""}
      CURL
      puts "\n"
    else
      warn "❌ Failed to create Doorkeeper Application:"
      app.errors.full_messages.each { |msg| warn "  - #{msg}" }
      exit 1
    end
  end

  desc "List all registered Doorkeeper OAuth Applications"
  task list_apps: :environment do
    apps = Doorkeeper::Application.order(:id)
    if apps.empty?
      puts "No Doorkeeper OAuth applications found. Create one with: rails doorkeeper:create_app"
      next
    end

    puts "\n" + ("=" * 80)
    puts "Registered Doorkeeper OAuth Applications (#{apps.count})"
    puts ("=" * 80)
    apps.each do |app|
      puts "ID: #{app.id} | Name: #{app.name}"
      puts "  UID (Client ID):     #{app.uid}"
      puts "  Secret:              #{app.secret}"
      puts "  Confidential:        #{app.confidential}"
      puts "  Redirect URI:        #{app.redirect_uri.presence || '(blank)'}"
      puts "  Active Access Tokens: #{Doorkeeper::AccessToken.where(application_id: app.id, revoked_at: nil).count}"
      puts "-" * 80
    end
  end

  desc "Revoke all active OAuth tokens for a specific user by email"
  task :revoke_user_tokens, [:email] => :environment do |_t, args|
    email = args[:email]
    if email.blank?
      warn "Usage: bundle exec rails doorkeeper:revoke_user_tokens[user@example.com]"
      exit 1
    end

    user = User.find_by(email: email)
    unless user
      warn "❌ User with email '#{email}' not found."
      exit 1
    end

    tokens = Doorkeeper::AccessToken.where(resource_owner_id: user.id, revoked_at: nil)
    count = tokens.count
    tokens.update_all(revoked_at: Time.current)

    puts "✅ Revoked #{count} active OAuth token(s) for user: #{user.email} (ID: #{user.id})"
  end
end
