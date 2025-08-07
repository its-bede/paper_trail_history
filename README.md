# PaperTrailHistory

A Rails engine providing a comprehensive web interface for managing PaperTrail versions. View, search, filter, and restore audit trail records with an intuitive Bootstrap-styled interface.

## Features

- **List All Trackable Models**: Discover all models in your application that use `has_paper_trail`
- **Browse Version History**: View all versions for specific models or individual records
- **Advanced Filtering**: Filter versions by event type, user, date range, and search content
- **Detailed Version View**: See exactly what changed in each version with before/after comparisons
- **Restore Functionality**: Safely restore records to previous versions with confirmation
- **Responsive Design**: Clean, Bootstrap-styled interface that works on all devices
- **Breadcrumb Navigation**: Easy navigation between models, records, and versions

## Installation

Add this line to your application's Gemfile:

```ruby
gem "paper_trail_history"
```

And then execute:
```bash
$ bundle install
```

Mount the engine in your routes file (`config/routes.rb`):

```ruby
Rails.application.routes.draw do
  mount PaperTrailHistory::Engine, at: '/revisions'
  # your other routes...
end
```

## Prerequisites

This engine requires:
- Rails >= 7.2
- PaperTrail >= 15.0 (configured with `has_paper_trail` in your models)

Make sure you have PaperTrail properly configured in your Rails application before using this engine.

## Usage

After mounting the engine, navigate to `/revisions` (or whatever path you chose) in your browser to access the interface.

### Main Features

1. **Models Overview** (`/revisions/models`)
   - Lists all models with paper trail enabled
   - Shows version counts for each model
   - Quick access to recent versions

2. **Model Versions** (`/revisions/models/:model_name/versions`)
   - View all versions for a specific model
   - Filter by event type, user, date range
   - Search within version content
   - Pagination support

3. **Record Versions** (`/revisions/models/:model_name/:record_id/versions`)
   - View version history for a specific record
   - See current record state vs historical versions

4. **Version Details** (`/revisions/versions/:id`)
   - Detailed view of what changed in a specific version
   - Side-by-side comparison of old vs new values
   - Restore functionality with confirmation

### Filtering and Search

The interface provides several ways to filter and search versions:

- **Event Type**: Filter by create, update, or destroy events
- **User**: Filter by who made the changes (whodunnit)
- **Date Range**: Show versions within specific date ranges
- **Content Search**: Search within the stored object changes

### Restoring Versions

You can restore any version (except create events) by:

1. Navigate to the version details page
2. Click "Restore This Version"
3. Confirm the restoration

**Note**: Restoring a version will create a new version entry, so you can always see the restoration in the audit trail.

## Development

### Quick Start

After cloning the repository, run the setup script to get started:

```bash
# Automated setup - installs dependencies, sets up database, runs tests
bin/setup
```

This script will:
- Install bundler and project dependencies
- Set up the test dummy app with database and seed data
- Run initial tests to verify everything works
- Run the linter to check code quality

### Manual Setup (Alternative)

If you prefer manual setup:

```bash
# Install dependencies
bundle install

# Set up test database with sample data
cd test/dummy
bundle install --gemfile=../../Gemfile
bundle exec rails db:prepare
bundle exec rails db:seed
cd ../..
```

### Running Tests

```bash
# Run all tests
bundle exec rake test

# Run integration tests only
bundle exec rake test:integration

# Run specific test file
bundle exec ruby -I test test/models/paper_trail_history/trackable_model_test.rb

# Run with verbose output
bundle exec rake test TESTOPTS="-v"

# Run code quality checks
bundle exec rubocop
```

### Testing Different Components

```bash
# Test models only
bundle exec rake test TEST="test/models/**/*_test.rb"

# Test controllers only  
bundle exec rake test TEST="test/controllers/**/*_test.rb"

# Test integration features
bundle exec rake test TEST="test/integration/**/*_test.rb"
```

### Using the Dummy Application

The `test/dummy` directory contains a full Rails application with sample models and data for testing:

```bash
# Start the development server (from project root)
bin/dummy

# Alternative: manual approach
cd test/dummy && bundle exec rails server

# Visit the engine interface
open http://localhost:3000/paper_trail_history
```

The dummy app includes:
- **User, Post, Comment models** - Standard PaperTrail setup
- **Product model** - Custom version table (`ProductVersion`) 
- **Rich seed data** - Various change types, workflows, and scenarios
- **I18n translations** - Proper model pluralization

### Testing Against Multiple Rails Versions

For comprehensive compatibility testing, use the provided Gemfiles:

```bash
# Test against Rails 7.2
BUNDLE_GEMFILE=gemfiles/rails_7.2.gemfile bundle install
BUNDLE_GEMFILE=gemfiles/rails_7.2.gemfile bundle exec rake test

# Test against Rails 8.0
BUNDLE_GEMFILE=gemfiles/rails_8.0.gemfile bundle install  
BUNDLE_GEMFILE=gemfiles/rails_8.0.gemfile bundle exec rake test

# Test against Rails main branch
BUNDLE_GEMFILE=gemfiles/rails_main.gemfile bundle install
BUNDLE_GEMFILE=gemfiles/rails_main.gemfile bundle exec rake test
```

### Continuous Integration

The project uses GitHub Actions to test against multiple Ruby and Rails versions. See `.github/workflows/ci.yml` for the full matrix configuration.

## Contributing

1. Fork the project
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

---

Kindly supported by [aifinyo AG](https://aifinyo.de)
