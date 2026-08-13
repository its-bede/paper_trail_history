# frozen_string_literal: true

# Coverage must start before the code of the engine is loaded, else the lines
# that run at load time count as missed.
require 'simplecov'
SimpleCov.start do
  enable_coverage :branch
  skip '/test/'
  # The engine lives in app/ and lib/. Only those directories count.
  group 'Models', 'app/models'
  group 'Controllers', 'app/controllers'
  group 'Helpers', 'app/helpers'
  group 'Library', 'lib'
  minimum_coverage line: 90, branch: 70
end

# Configure Rails Environment
ENV['RAILS_ENV'] = 'test'

require_relative '../test/dummy/config/environment'
ActiveRecord::Migrator.migrations_paths = [File.expand_path('../test/dummy/db/migrate', __dir__)]
ActiveRecord::Migrator.migrations_paths << File.expand_path('../db/migrate', __dir__)
require 'rails/test_help'
require 'minitest/mock'

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_paths=)
  ActiveSupport::TestCase.fixture_paths = [File.expand_path('fixtures', __dir__)]
  ActionDispatch::IntegrationTest.fixture_paths = ActiveSupport::TestCase.fixture_paths
  ActiveSupport::TestCase.file_fixture_path = "#{File.expand_path('fixtures', __dir__)}/files"
  ActiveSupport::TestCase.fixtures :all
end

class ActiveSupport::TestCase
  # Collects the SQL of the block, so that a test can check the shape and the
  # number of the queries and not only the result.
  #
  # @return [Array<String>]
  def capture_sql
    statements = []
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      statements << payload[:sql]
    end
    yield

    statements
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end
