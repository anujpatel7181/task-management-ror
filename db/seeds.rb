# frozen_string_literal: true

# =============================================================================
# DATABASE SEEDS — db/seeds.rb
# =============================================================================
# Populates the development database with realistic test data.
#
# Run with:   rails db:seed
# Reset+seed: rails db:reset db:seed  (WARNING: drops and recreates DB)
#
# WHAT GETS CREATED:
#   1. One Doorkeeper OAuth application (the API client)
#   2. 1 Admin user
#   3. 3 Member users (with profiles)
#   4. 3 Projects (owned by admin and members)
#   5. Tasks with sub-tasks (nested up to 2 levels)
#   6. Polymorphic comments on projects and tasks
#
# After seeding, print login credentials and OAuth token request examples.
#
# DEPENDENCIES:
#   Faker gem provides realistic random data (names, emails, sentences, etc.)
# =============================================================================

require "faker"

puts "\n#{'=' * 60}"
puts "Starting database seed..."
puts "=" * 60

# Clean up in the right order to respect foreign key constraints.
puts "\n🧹 Cleaning existing data..."
ActiveStorage::Attachment.delete_all
ActiveStorage::Blob.delete_all
Comment.delete_all
Task.delete_all
Project.delete_all
Profile.delete_all
Doorkeeper::AccessToken.delete_all
Doorkeeper::AccessGrant.delete_all
Doorkeeper::Application.delete_all
User.delete_all

# =============================================================================
# STEP 1: Create Doorkeeper OAuth Application
# =============================================================================
# This represents the API "client" (e.g., a mobile app, Postman, Bruno).
# In production, each client app registers separately.
#
# The uid and secret are the "client_id" and "client_secret" used in
# POST /oauth/token requests.
# =============================================================================
puts "\n🔑 Creating Doorkeeper OAuth Application..."

oauth_app = Doorkeeper::Application.create!(
  name: "Rails API Learning Hub — Dev Client",
  # redirect_uri is blank because we use the password grant flow.
  # Password grant doesn't redirect — it returns the token directly.
  redirect_uri: "",
  # scopes: "" means the app can request any scope.
  scopes: "",
  # confidential: false — allows token requests WITHOUT a client_secret.
  # This is the correct setting for mobile apps, SPAs, and Bruno/Postman.
  # A "confidential" app (true) requires the client_secret in every token request,
  # which is only safe for server-side apps that can store secrets securely.
  confidential: false
)

puts "  ✅ OAuth App created:"
puts "     Name:          #{oauth_app.name}"
puts "     Client ID:     #{oauth_app.uid}"
puts "     Client Secret: #{oauth_app.secret}"

# =============================================================================
# STEP 2: Create Users
# =============================================================================
puts "\n👤 Creating users..."

# ADMIN USER
admin = User.create!(
  email: "admin@railshub.dev",
  password: "Admin@123456",
  password_confirmation: "Admin@123456",
  full_name: "Alex Admin",
  role: :admin
)
puts "  ✅ Admin: #{admin.email} / Admin@123456"

# Create profile for admin
admin.create_profile!(
  bio: "Platform administrator. Full system access.",
  website_url: "https://railshub.dev/admin",
  location: "San Francisco, CA"
)

# MEMBER USERS
member_data = [
  { email: "alice@railshub.dev", full_name: "Alice Johnson", location: "New York, NY" },
  { email: "bob@railshub.dev",   full_name: "Bob Smith",     location: "Austin, TX" },
  { email: "carol@railshub.dev", full_name: "Carol Davis",   location: "Chicago, IL" }
]

members = member_data.map do |data|
  user = User.create!(
    email: data[:email],
    password: "Member@123456",
    password_confirmation: "Member@123456",
    full_name: data[:full_name],
    role: :member
  )
  puts "  ✅ Member: #{user.email} / Member@123456"

  user.create_profile!(
    bio: Faker::Lorem.paragraph(sentence_count: 2),
    website_url: "https://#{data[:email].split('@').first}.dev",
    location: data[:location]
  )

  user
end

alice, bob, carol = members

# =============================================================================
# STEP 3: Create Projects
# =============================================================================
puts "\n📁 Creating projects..."

# Project 1: Admin's project (e-commerce platform)
ecommerce_project = Project.create!(
  name: "E-Commerce Platform v2",
  description: "Complete rewrite of the legacy e-commerce system using Rails API + React frontend.",
  status: :active,
  owner: admin
)
puts "  ✅ Project: '#{ecommerce_project.name}' (owner: admin)"

# Project 2: Alice's project (mobile app)
mobile_project = Project.create!(
  name: "Mobile App Backend API",
  description: "RESTful API for the iOS/Android mobile application. Includes auth, push notifications.",
  status: :active,
  owner: alice
)
puts "  ✅ Project: '#{mobile_project.name}' (owner: alice)"

# Project 3: Bob's project (analytics dashboard) — completed
analytics_project = Project.create!(
  name: "Analytics Dashboard",
  description: "Real-time analytics dashboard. Historical data visualization.",
  status: :completed,
  owner: bob
)
puts "  ✅ Project: '#{analytics_project.name}' (owner: bob)"

# =============================================================================
# STEP 4: Create Tasks with Sub-Tasks
# =============================================================================
puts "\n✅ Creating tasks and sub-tasks..."

# ---- E-Commerce Project Tasks ----

# Parent Task 1: Authentication System
auth_task = Task.create!(
  title: "Implement Authentication System",
  description: "Build OAuth2 + Devise based authentication for all user types.",
  status: :in_progress,
  priority: :critical,
  project: ecommerce_project,
  assignee: alice,
  due_date: 2.weeks.from_now
)
puts "  ✅ Task: '#{auth_task.title}'"

# Sub-tasks of auth_task (level 1)
auth_subtask_1 = Task.create!(
  title: "Design JWT token schema",
  description: "Decide token expiry, refresh strategy, and signing algorithm.",
  status: :done,
  priority: :high,
  project: ecommerce_project,
  assignee: alice,
  parent_task: auth_task   # ← SELF-REFERENTIAL: this is a sub-task of auth_task
)

auth_subtask_2 = Task.create!(
  title: "Implement password reset flow",
  description: "Email-based reset using Devise recoverable + custom API endpoints.",
  status: :in_progress,
  priority: :high,
  project: ecommerce_project,
  assignee: carol,
  parent_task: auth_task   # ← SELF-REFERENTIAL: also a sub-task of auth_task
)
puts "    ↳ Sub-task: '#{auth_subtask_1.title}' [done]"
puts "    ↳ Sub-task: '#{auth_subtask_2.title}' [in_progress]"

# Nested sub-sub-task (level 2): sub-task of auth_subtask_2
Task.create!(
  title: "Write password reset email template",
  description: "HTML email template for the reset link. Must be mobile-responsive.",
  status: :todo,
  priority: :medium,
  project: ecommerce_project,
  assignee: carol,
  parent_task: auth_subtask_2  # ← Level 2: sub-task of a sub-task
)
puts "      ↳↳ Sub-sub-task: 'Write password reset email template'"

# Parent Task 2: Product Catalog
catalog_task = Task.create!(
  title: "Build Product Catalog API",
  description: "CRUD endpoints for products, categories, and inventory.",
  status: :todo,
  priority: :high,
  project: ecommerce_project,
  assignee: bob,
  due_date: 3.weeks.from_now
)
puts "  ✅ Task: '#{catalog_task.title}'"

Task.create!(
  title: "Add product search with Elasticsearch",
  description: "Full-text search with filters for price, category, rating.",
  status: :todo,
  priority: :medium,
  project: ecommerce_project,
  assignee: bob,
  parent_task: catalog_task
)
puts "    ↳ Sub-task: 'Add product search with Elasticsearch'"

# ---- Mobile App Project Tasks ----

push_task = Task.create!(
  title: "Push Notification Service",
  description: "Integrate Firebase Cloud Messaging for iOS and Android.",
  status: :todo,
  priority: :high,
  project: mobile_project,
  assignee: carol,
  due_date: 4.weeks.from_now
)
puts "  ✅ Task: '#{push_task.title}'"

Task.create!(
  title: "FCM credential setup",
  description: "Obtain FCM server key and configure in the application.",
  status: :done,
  priority: :critical,
  project: mobile_project,
  assignee: carol,
  parent_task: push_task
)
puts "    ↳ Sub-task: 'FCM credential setup'"

# ---- Analytics Project Tasks (completed project) ----

analytics_task = Task.create!(
  title: "Data Pipeline Setup",
  description: "ETL pipeline to aggregate raw events into analytics tables.",
  status: :done,
  priority: :critical,
  project: analytics_project,
  assignee: alice
)
puts "  ✅ Task: '#{analytics_task.title}' [done]"

# =============================================================================
# STEP 5: Polymorphic Comments
# =============================================================================
puts "\n💬 Creating polymorphic comments..."

# Comments ON A PROJECT (commentable_type = "Project")
project_comment_1 = ecommerce_project.comments.create!(
  body: "This project is looking great! The API design is solid.",
  user: alice
)
puts "  ✅ Project comment by #{alice.full_name}: '#{project_comment_1.body.truncate(50)}'"

project_comment_2 = ecommerce_project.comments.create!(
  body: "Let's make sure we handle rate limiting on the auth endpoints.",
  user: admin
)
puts "  ✅ Project comment by #{admin.full_name}: '#{project_comment_2.body.truncate(50)}'"

mobile_project.comments.create!(
  body: "Can we add WebSocket support for real-time features?",
  user: bob
)

# Comments ON A TASK (commentable_type = "Task")
task_comment_1 = auth_task.comments.create!(
  body: "I'm using Doorkeeper 5.x — the password grant flow works perfectly.",
  user: alice
)
puts "  ✅ Task comment by #{alice.full_name}: '#{task_comment_1.body.truncate(50)}'"

task_comment_2 = auth_task.comments.create!(
  body: "Make sure to set reuse_access_token in the Doorkeeper initializer for dev.",
  user: admin
)
puts "  ✅ Task comment by #{admin.full_name}: '#{task_comment_2.body.truncate(50)}'"

auth_subtask_2.comments.create!(
  body: "The reset email should expire after 6 hours. Check devise.rb config.",
  user: carol
)

catalog_task.comments.create!(
  body: "Don't forget to add pagination to the product list endpoint.",
  user: bob
)

# =============================================================================
# SUMMARY OUTPUT
# =============================================================================
puts "\n#{'=' * 60}"
puts "✅ SEED COMPLETE!"
puts "=" * 60

puts "\n📊 Database Summary:"
puts "   Users:    #{User.count} (#{User.admin.count} admin, #{User.member.count} members)"
puts "   Profiles: #{Profile.count}"
puts "   Projects: #{Project.count}"
puts "   Tasks:    #{Task.count} (#{Task.where.not(parent_task_id: nil).count} sub-tasks)"
puts "   Comments: #{Comment.count} (#{Comment.where(commentable_type: 'Project').count} on projects, #{Comment.where(commentable_type: 'Task').count} on tasks)"
puts "   OAuth Apps: #{Doorkeeper::Application.count}"

puts "\n🔐 OAuth Token — Request Example (curl):"
puts "=" * 60
puts <<~CURL
  # Get Bearer token for admin:
  curl -X POST http://localhost:3000/oauth/token \\
    -H "Content-Type: application/x-www-form-urlencoded" \\
    -d "grant_type=password" \\
    -d "username=admin@railshub.dev" \\
    -d "password=Admin@123456" \\
    -d "client_id=#{oauth_app.uid}" \\
    -d "client_secret=#{oauth_app.secret}"

  # Then use the returned access_token in subsequent requests:
  curl -X GET http://localhost:3000/api/v1/users/me \\
    -H "Authorization: Bearer <access_token>"
CURL

puts "\n👤 Test Credentials:"
puts "-" * 40
puts "  Admin:  admin@railshub.dev  / Admin@123456"
puts "  Alice:  alice@railshub.dev  / Member@123456"
puts "  Bob:    bob@railshub.dev    / Member@123456"
puts "  Carol:  carol@railshub.dev  / Member@123456"

puts "\n🔑 OAuth Application:"
puts "-" * 40
puts "  Client ID:     #{oauth_app.uid}"
puts "  Client Secret: #{oauth_app.secret}"
puts "=" * 60
puts "\n"
