# frozen_string_literal: true

# Clear existing data
puts '🧹 Clearing existing data...'
Comment.delete_all
Post.delete_all
User.delete_all
Product.delete_all
PaperTrail::Version.delete_all
ProductVersion.delete_all

# Set up PaperTrail to track changes
PaperTrail.enabled = true

puts '👥 Creating users with version history...'

# Create users with different change patterns
user1 = User.create!(
  name: 'Alice Johnson',
  email: 'alice@example.com',
  bio: 'Software developer',
  active: true
)
PaperTrail.request.whodunnit = 'admin'

# Update user multiple times to create version history
user1.update!(bio: 'Senior Software Developer')
sleep 0.1
user1.update!(bio: 'Senior Software Developer at TechCorp', last_login_at: 1.hour.ago)
sleep 0.1
user1.update!(active: false)
sleep 0.1
user1.update!(active: true, name: 'Alice Smith') # Name change (marriage)

user2 = User.create!(
  name: 'Bob Wilson',
  email: 'bob@example.com',
  bio: 'Product Manager'
)
PaperTrail.request.whodunnit = 'bob@example.com'
user2.update!(email: 'bob.wilson@example.com') # Email update

user3 = User.create!(
  name: 'Charlie Brown',
  email: 'charlie@example.com'
)

puts '📝 Creating posts with complex change history...'

PaperTrail.request.whodunnit = 'alice@example.com'
post1 = Post.create!(
  title: 'Getting Started with Rails',
  content: "This is a beginner's guide to Ruby on Rails...",
  user: user1,
  status: :draft
)

# Simulate editing process
post1.update!(content: "This is a comprehensive beginner's guide to Ruby on Rails development...")
sleep 0.1
post1.update!(title: 'Complete Guide to Rails for Beginners')
sleep 0.1
post1.update!(status: :published, published_at: Time.current)
sleep 0.1
post1.update!(featured: true, view_count: 150)

PaperTrail.request.whodunnit = 'bob@example.com'
post2 = Post.create!(
  title: 'Advanced Rails Patterns',
  content: "Let's explore some advanced patterns in Rails applications...",
  user: user2,
  status: :published,
  published_at: 2.days.ago
)

post2.update!(view_count: 45)
sleep 0.1
new_content = "Let's explore some advanced patterns in Rails applications, including service objects and decorators."
post2.update!(content: new_content)

puts '💬 Creating comments with approval workflow...'

PaperTrail.request.whodunnit = 'charlie@example.com'
comment1 = Comment.create!(
  content: 'Great article! Very helpful for beginners.',
  user: user3,
  post: post1,
  approved: false
)

PaperTrail.request.whodunnit = 'moderator'
comment1.update!(approved: true)

comment2 = Comment.create!(
  content: 'I disagree with some points made here.',
  user: user2,
  post: post1,
  approved: false
)
comment2.update!(content: 'I have some concerns about the approach mentioned in section 3.')
comment2.update!(approved: true)

puts '📦 Creating products with custom version table...'

PaperTrail.request.whodunnit = 'inventory_system'

product1 = Product.create!(
  name: 'MacBook Pro',
  sku: 'MBP-001',
  price: 1299.99,
  description: '13-inch MacBook Pro',
  category: :electronics,
  stock_quantity: 5
)

# Price changes and stock updates
product1.update!(price: 1199.99, description: '13-inch MacBook Pro - On Sale!')
sleep 0.1
product1.update!(stock_quantity: 3)
sleep 0.1
product1.update!(stock_quantity: 0, active: false) # Out of stock
sleep 0.1
product1.update!(stock_quantity: 10, active: true, price: 1299.99) # Restocked

product2 = Product.create!(
  name: 'Ruby Programming Book',
  sku: 'BOOK-001',
  price: 29.99,
  description: 'Learn Ruby programming from scratch',
  category: :books,
  stock_quantity: 25
)

product2.update!(description: 'Learn Ruby programming from scratch - 2nd Edition')
product2.update!(price: 24.99) # Price drop

PaperTrail.request.whodunnit = 'admin'
product3 = Product.create!(
  name: 'Cotton T-Shirt',
  sku: 'TEE-001',
  price: 19.99,
  category: :clothing,
  stock_quantity: 100
)

# Simulate seasonal price changes
product3.update!(price: 15.99) # Sale price
product3.update!(name: 'Premium Cotton T-Shirt', price: 22.99) # Rebrand with price increase

puts '🗑️  Creating some deletions to test destroy versions...'

# Create and then delete some records to test deletion versions
temp_user = User.create!(name: 'Temp User', email: 'temp@example.com')
temp_user.destroy!

temp_product = Product.create!(name: 'Discontinued Item', sku: 'DISC-001', price: 9.99, category: :electronics)
temp_product.destroy!

puts '📊 Summary:'
puts "- Users: #{User.count} (#{PaperTrail::Version.where(item_type: 'User').count} versions)"
puts "- Posts: #{Post.count} (#{PaperTrail::Version.where(item_type: 'Post').count} versions)"
puts "- Comments: #{Comment.count} (#{PaperTrail::Version.where(item_type: 'Comment').count} versions)"
puts "- Products: #{Product.count} (#{ProductVersion.where(item_type: 'Product').count} versions in custom table)"
puts "- Total Standard Versions: #{PaperTrail::Version.count}"
puts "- Total Product Versions: #{ProductVersion.count}"

puts '🎉 Seed data created successfully!'
puts 'Visit http://localhost:3000/paper_trail_history to explore the interface!'
