# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in paper_trail_history.gemspec.
gemspec

gem 'puma'

gem 'sqlite3'

gem 'propshaft'

# Default Ruby and Rails linting
gem 'rubocop-rails', require: false

# API documentation
gem 'yard', require: false

# Security checks: known vulnerable dependencies and static analysis
gem 'brakeman', require: false
gem 'bundler-audit', require: false

# Test coverage
gem 'simplecov', require: false

# The test suite uses minitest/mock for stubbing. Minitest 6 removed that file,
# thus the version stays on the 5 series until the stubs are replaced.
gem 'minitest', '~> 5.25'

# Start debugger with binding.b [https://github.com/ruby/debug]
# gem "debug", ">= 1.0.0"
