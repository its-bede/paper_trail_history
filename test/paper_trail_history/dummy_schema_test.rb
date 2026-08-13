# frozen_string_literal: true

require 'test_helper'

module PaperTrailHistory
  # The schema of the dummy application is in Git and names a Rails version. An
  # older Rails refuses a schema of a newer Rails with "Unknown migration
  # version". The CI runs the suite against the lowest supported Rails, thus the
  # schema must name that version and no other.
  #
  # Whoever runs the migrations on a newer Rails gets a new version in the file.
  # This test makes that visible here and not later in the CI.
  class DummySchemaTest < ActiveSupport::TestCase
    # The lowest Rails version of the gemspec and of the CI matrix.
    LOWEST_SUPPORTED_RAILS = '8.0'

    test 'the schema of the dummy application names the lowest supported Rails version' do
      declared = schema.match(/ActiveRecord::Schema\[([\d.]+)\]/)&.captures&.first

      assert_equal LOWEST_SUPPORTED_RAILS, declared,
                   'Set the version back after you ran the migrations on a newer Rails.'
    end

    private

    def schema
      Engine.root.join('test', 'dummy', 'db', 'schema.rb').read
    end
  end
end
