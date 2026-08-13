# frozen_string_literal: true

require 'test_helper'

module PaperTrailHistory
  # The model list is the root page of the engine. An application with one
  # version table for each model would need one count query for each table, and
  # a count reads the whole table. The engine therefore shows no count here
  # unless the host application asks for it.
  class ModelCountsTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    teardown do
      PaperTrailHistory.reset_config!
    end

    test 'reads no count for the model list' do
      queries = capture_sql { get models_url }

      assert_empty queries.grep(/COUNT/i)
    end

    test 'shows no count column in the model list' do
      get models_url

      assert_select 'th', text: 'Total Versions', count: 0
    end

    test 'shows the count column when the host application asks for it' do
      PaperTrailHistory.configure { |config| config.show_version_counts = true }

      get models_url

      assert_select 'th', text: 'Total Versions'
    end

    test 'reads the counts when the host application asks for it' do
      PaperTrailHistory.configure { |config| config.show_version_counts = true }

      queries = capture_sql { get models_url }

      assert_not_empty queries.grep(/COUNT/i)
    end

    test 'reads one count query for each version table and no more' do
      TrackableModel.all # the discovery must not count as a query of the counts
      version_tables = TrackableModel.all.map(&:version_class).uniq.size

      queries = capture_sql { TrackableModel.all_with_counts }

      assert_equal version_tables, queries.grep(/COUNT/i).size
    end

    # A plain user must exist too. With only one admin the count of the subclass
    # and the count of the base class are the same number, and the test would
    # pass also when the engine gives the count of the base class to the
    # subclass.
    test 'still counts the versions of a subclass separately' do
      Admin.create!(name: 'Grace', email: "mc-#{SecureRandom.hex(4)}@example.com")
      2.times { |i| User.create!(name: "Plain #{i}", email: "mc-#{SecureRandom.hex(4)}@example.com") }

      model = TrackableModel.all_with_counts.find { |trackable| trackable.name == 'Admin' }

      assert_equal 1, model.total_versions_count
    end

    test 'counts the versions of the subclasses into the base class' do
      Admin.create!(name: 'Grace', email: "mc-#{SecureRandom.hex(4)}@example.com")
      2.times { |i| User.create!(name: "Plain #{i}", email: "mc-#{SecureRandom.hex(4)}@example.com") }

      model = TrackableModel.all_with_counts.find { |trackable| trackable.name == 'User' }

      assert_equal 3, model.total_versions_count
    end

    test 'shows the count on the page of one model' do
      get model_url('User')

      assert_select 'dd .badge'
    end
  end
end
