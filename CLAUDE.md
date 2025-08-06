# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Ruby gem called `paper_trail_history` - a Rails engine designed to extend functionality related to audit trails. The gem follows standard Rails engine patterns and is built for Rails 8.0.2+.

## Development Commands

### Testing
- Run all tests: `bundle exec rake test`
- Run specific test: `bundle exec ruby -I test test/path/to/specific_test.rb`

### Gem Development
- Build gem: `bundle exec rake build`
- Install gem locally: `bundle exec rake install`
- Release gem: `bundle exec rake release` (requires proper configuration)

### Linting
- Run RuboCop with Rails Omakase rules: `bundle exec rubocop`
- Auto-fix issues: `bundle exec rubocop -a`

### Development Server (via test dummy app)
- Start Rails server: `cd test/dummy && bundle exec rails server`
- Rails console: `cd test/dummy && bundle exec rails console`

## Architecture

### Gem Structure
- **Main module**: `PaperTrailHistory` defined in `lib/paper_trail_history.rb`
- **Engine**: `PaperTrailHistory::Engine` in `lib/paper_trail_history/engine.rb` - Rails engine with isolated namespace
- **Version**: `PaperTrailHistory::VERSION` in `lib/paper_trail_history/version.rb`

### Rails Engine Pattern
This gem uses the Rails Engine pattern with:
- Isolated namespace (`isolate_namespace PaperTrailHistory`)
- Standard MVC structure under `app/` directory
- Engine-specific routes in `config/routes.rb`
- Test dummy application in `test/dummy/` for development and testing

### Test Structure
- Main test helper: `test/test_helper.rb` 
- Dummy Rails application in `test/dummy/` for testing the engine
- Tests use Rails' built-in testing framework with fixtures support
- Migration paths include both dummy app and engine migrations

### Dependencies
- **Core**: Rails >= 8.0.2, Ruby >= 3.1.0
- **Development**: sqlite3, puma, propshaft
- **Code Quality**: rubocop-rails (with custom configuration)

## Development Notes

### File Organization
- Engine controllers go in `app/controllers/paper_trail_history/`
- Engine models go in `app/models/paper_trail_history/`
- Engine views go in `app/views/layouts/paper_trail_history/`
- All engine classes should be namespaced under `PaperTrailHistory`

### Testing Approach
- Use the dummy Rails app for integration testing
- Engine-specific functionality should be tested through the engine's test suite
- Fixtures are supported and loaded automatically

### Gem Configuration
- Currently configured to prevent pushing to RubyGems.org
- Metadata URLs need to be updated before publishing
- Gem description and summary are placeholders and should be updated

## Code Quality & Standards

### RuboCop Configuration
The project uses a comprehensive RuboCop configuration in `.rubocop.yml` that includes:
- Rails-specific cops via `rubocop-rails` plugin
- Custom exclusions for test dummy app and generated files
- Metrics configurations for code complexity management
- Special handling for wrapper classes that don't follow ActiveRecord patterns

#### Key RuboCop Exclusions
- **Rails/FindEach**: Excluded for `version_service.rb` because `TrackableModel` is a wrapper class returning Arrays, not ActiveRecord relations
- **Metrics/ClassLength**: Excluded for `version_service.rb` due to service pattern complexity
- **Style/Documentation**: Excluded for test files and migrations

### Internationalization
The engine includes internationalization support:
- Locale files in `config/locales/en.yml`
- Error messages and user-facing strings should be localized
- Follow Rails i18n conventions for namespace organization