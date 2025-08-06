# frozen_string_literal: true

require 'test_helper'

module PaperTrailHistory
  class VersionDecoratorTest < ActiveSupport::TestCase
    setup do
      @version = create_test_version
      @decorator = VersionDecorator.new(@version)
    end

    test 'decorates single version' do
      decorator = VersionDecorator.decorate(@version)
      assert_kind_of VersionDecorator, decorator
      assert_equal @version, decorator.version
    end

    test 'decorates collection of versions' do
      versions = [@version, create_test_version]
      decorators = VersionDecorator.decorate_collection(versions)

      assert_equal 2, decorators.count
      assert(decorators.all? { |d| d.is_a?(VersionDecorator) })
    end

    test 'formats created_at date' do
      formatted = @decorator.formatted_created_at
      assert_kind_of String, formatted
      assert formatted.present?
    end

    test 'returns event label for create' do
      version = create_test_version(event: 'create')
      decorator = VersionDecorator.new(version)

      assert_equal 'Created', decorator.event_label
    end

    test 'returns event label for update' do
      version = create_test_version(event: 'update')
      decorator = VersionDecorator.new(version)

      assert_equal 'Updated', decorator.event_label
    end

    test 'returns event label for destroy' do
      version = create_test_version(event: 'destroy')
      decorator = VersionDecorator.new(version)

      assert_equal 'Deleted', decorator.event_label
    end

    test 'returns event class for create' do
      version = create_test_version(event: 'create')
      decorator = VersionDecorator.new(version)

      assert_equal 'success', decorator.event_class
    end

    test 'returns event class for update' do
      version = create_test_version(event: 'update')
      decorator = VersionDecorator.new(version)

      assert_equal 'warning', decorator.event_class
    end

    test 'returns event class for destroy' do
      version = create_test_version(event: 'destroy')
      decorator = VersionDecorator.new(version)

      assert_equal 'danger', decorator.event_class
    end

    test 'returns whodunnit display' do
      version = create_test_version(whodunnit: 'user123')
      decorator = VersionDecorator.new(version)

      assert_equal 'user123', decorator.whodunnit_display
    end

    test 'returns system for nil whodunnit' do
      version = create_test_version(whodunnit: nil)
      decorator = VersionDecorator.new(version)

      assert_equal 'System', decorator.whodunnit_display
    end

    test 'can restore non-create versions' do
      version = create_test_version(event: 'update')
      decorator = VersionDecorator.new(version)

      assert decorator.can_restore?
    end

    test 'cannot restore create versions' do
      version = create_test_version(event: 'create')
      decorator = VersionDecorator.new(version)

      assert_not decorator.can_restore?
    end

    test 'returns changed attributes' do
      changes = @decorator.changed_attributes
      assert_kind_of Array, changes

      if changes.any?
        change = changes.first
        assert change.key?(:attribute)
        assert change.key?(:old_value)
        assert change.key?(:new_value)
      end
    end

    test 'returns item display name' do
      display_name = @decorator.item_display_name
      assert_kind_of String, display_name
      assert display_name.present?
    end

    private

    def create_test_version(attributes = {})
      PaperTrail::Version.create!(
        {
          item_type: 'User',
          item_id: 1,
          event: 'update',
          whodunnit: 'test_user',
          object: { name: 'old_name' }.to_yaml,
          object_changes: { name: %w[old_name new_name] }.to_yaml,
          created_at: Time.current
        }.merge(attributes)
      )
    end
  end
end
