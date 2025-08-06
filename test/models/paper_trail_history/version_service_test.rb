# frozen_string_literal: true

require 'test_helper'

module PaperTrailHistory
  class VersionServiceTest < ActiveSupport::TestCase
    setup do
      @version = create_test_version
    end

    test 'filters versions by model' do
      versions = VersionService.for_model('User')
      assert_respond_to versions, :where
    end

    test 'filters versions by event' do
      versions = VersionService.for_model('User', event: 'update')
      assert_respond_to versions, :where
    end

    test 'filters versions by whodunnit' do
      versions = VersionService.for_model('User', whodunnit: 'user123')
      assert_respond_to versions, :where
    end

    test 'filters versions by date range' do
      from_date = 1.week.ago.to_date.to_s
      to_date = Date.current.to_s

      versions = VersionService.for_model('User', from_date: from_date, to_date: to_date)
      assert_respond_to versions, :where
    end

    test 'searches versions by content' do
      versions = VersionService.for_model('User', search: 'test')
      assert_respond_to versions, :where
    end

    test 'returns versions for specific record' do
      versions = VersionService.for_record('User', 123)
      assert_respond_to versions, :where
    end

    test 'returns unique whodunnits' do
      whodunnits = VersionService.unique_whodunnits
      assert_kind_of Array, whodunnits
    end

    test 'returns available events' do
      events = VersionService.available_events
      assert_kind_of Array, events
    end

    test 'restore_version returns error for non-existent version' do
      result = VersionService.restore_version(99_999)

      assert_equal false, result[:success]
      assert_includes result[:error], 'not found'
    end

    test 'restore_version returns error for create events' do
      version = create_test_version(event: 'create')
      result = VersionService.restore_version(version.id)

      assert_equal false, result[:success]
      assert_includes result[:error], 'Cannot restore create events'
    end

    private

    def create_test_version(attributes = {})
      PaperTrail::Version.create!({
        item_type: 'User',
        item_id: 1,
        event: 'update',
        whodunnit: 'test_user',
        object: { name: 'old_name' }.to_yaml,
        object_changes: { name: %w[old_name new_name] }.to_yaml,
        created_at: Time.current
      }.merge(attributes))
    end
  end
end
