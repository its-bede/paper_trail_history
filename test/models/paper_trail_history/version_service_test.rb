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

    test 'find_version with model_name uses specific version class' do
      version = create_test_version
      found = VersionService.find_version(version.id, 'User')

      assert_not_nil found
      assert_equal version.id, found.id
    end

    test 'find_version without model_name searches across tables' do
      version = create_test_version
      found = VersionService.find_version(version.id)

      assert_not_nil found
      assert_equal version.id, found.id
    end

    test 'find_version with invalid model_name returns nil' do
      version = create_test_version
      found = VersionService.find_version(version.id, 'NonExistentModel')

      assert_nil found
    end

    test 'find_version with nil version_id returns nil' do
      found = VersionService.find_version(99_999, 'User')

      assert_nil found
    end

    test 'restores a record that has timestamps to the values of the previous version' do
      user = changed_user

      VersionService.restore_version(user.versions.last)

      assert_equal 'Original', user.reload.name
    end

    test 'refuses the restore when Rails does not permit a class of the stored version' do
      user = changed_user

      result = without_permitted_yaml_classes { VersionService.restore_version(user.versions.last) }

      assert_not result[:success]
    end

    test 'names the Rails setting when Rails does not permit a class of the stored version' do
      user = changed_user

      result = without_permitted_yaml_classes { VersionService.restore_version(user.versions.last) }

      assert_includes result[:error], 'yaml_column_permitted_classes'
    end

    test 'restores the given version and not another version with the same id' do
      product_version = colliding_product_version

      result = VersionService.restore_version(product_version)

      assert result[:success]
    end

    test 'restores the values of the given version and not of another version with the same id' do
      product_version = colliding_product_version

      VersionService.restore_version(product_version)

      assert_equal 'Original', product_version.item.reload.name
    end

    private

    # Makes a user with an update version. The user has timestamps, thus the
    # stored YAML holds an ActiveSupport::TimeWithZone value.
    def changed_user
      user = User.create!(name: 'Original', email: "r9-#{SecureRandom.hex(4)}@example.com")
      user.update!(name: 'Changed')
      user
    end

    # Runs the block with the YAML rules of a Rails application that permits no
    # class. This is the default of a new Rails application.
    def without_permitted_yaml_classes
      original = ActiveRecord.yaml_column_permitted_classes
      ActiveRecord.yaml_column_permitted_classes = []
      yield
    ensure
      ActiveRecord.yaml_column_permitted_classes = original
    end

    # Makes an update version of a product, and a create version of a user that
    # has the same ID in the other version table. A restore that searches by ID
    # alone finds the user version first and refuses the restore.
    def colliding_product_version
      product = Product.create!(name: 'Original', price: 10, sku: "SKU-#{SecureRandom.hex(4)}")
      product.update!(name: 'Changed')
      product_version = product.versions.last

      PaperTrail::Version.where(id: product_version.id).delete_all
      create_test_version(id: product_version.id, event: 'create')

      product_version
    end

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
