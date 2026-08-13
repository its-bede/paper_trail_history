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

    test 'names the attribute that changed' do
      change = @decorator.changed_attributes.first

      assert_equal 'name', change[:attribute]
    end

    test 'gives the value before the change' do
      change = @decorator.changed_attributes.first

      assert_equal 'old_name', change[:old_value]
    end

    test 'gives the value after the change' do
      change = @decorator.changed_attributes.first

      assert_equal 'new_name', change[:new_value]
    end

    test 'gives no change for a version without a changeset' do
      version = create_test_version(object_changes: nil)

      assert_empty VersionDecorator.new(version).changed_attributes
    end

    test 'hides the old value of an attribute that the host application filters' do
      change = filtered_change

      assert_equal I18n.t('paper_trail_history.display.filtered'), change[:old_value]
    end

    test 'hides the new value of an attribute that the host application filters' do
      change = filtered_change

      assert_equal I18n.t('paper_trail_history.display.filtered'), change[:new_value]
    end

    test 'shows the value of an attribute that the host application does not filter' do
      version = create_test_version(object_changes: { name: %w[old_name new_name] }.to_yaml)
      change = VersionDecorator.new(version).changed_attributes.first

      assert_equal 'new_name', change[:new_value]
    end

    test 'names the item by its type and id when the record is gone' do
      version = create_test_version(item_id: 999_999)

      assert_equal 'User #999999 (deleted)', VersionDecorator.new(version).item_display_name
    end

    test 'names the item by its name when the record exists' do
      user = User.create!(name: 'Ada Lovelace', email: "vd-#{SecureRandom.hex(4)}@example.com")
      version = create_test_version(item_id: user.id)

      assert_equal 'Ada Lovelace', VersionDecorator.new(version).item_display_name
    end

    private

    # The dummy application filters :email, thus the decorator must not show the
    # two address values of this change.
    def filtered_change
      version = create_test_version(
        object_changes: { email: %w[old@example.com new@example.com] }.to_yaml
      )

      VersionDecorator.new(version).changed_attributes.first
    end

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
