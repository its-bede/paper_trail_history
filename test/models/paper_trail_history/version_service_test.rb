# frozen_string_literal: true

require 'test_helper'

module PaperTrailHistory
  class VersionServiceTest < ActiveSupport::TestCase
    setup do
      @version = create_test_version
    end

    test 'gives the versions of the named model' do
      wanted = create_test_version
      other = create_test_version(item_type: 'Post')

      ids = VersionService.for_model('User').map(&:id)

      assert_equal [wanted.id], ids & [wanted.id, other.id]
    end

    test 'gives no versions for a model that is not trackable' do
      assert_empty VersionService.for_model('NoSuchModel')
    end

    test 'gives the versions in the order of the newest first' do
      old_version = create_test_version(created_at: 2.days.ago)
      new_version = create_test_version(created_at: 1.hour.ago)

      ids = VersionService.for_model('User').map(&:id)

      assert_operator ids.index(new_version.id), :<, ids.index(old_version.id)
    end

    test 'keeps only the versions with the named event' do
      wanted = create_test_version(event: 'destroy')
      other = create_test_version(event: 'update')

      ids = VersionService.for_model('User', event: 'destroy').map(&:id)

      assert_equal [wanted.id], ids & [wanted.id, other.id]
    end

    test 'keeps only the versions of the named person' do
      wanted = create_test_version(whodunnit: 'ada')
      other = create_test_version(whodunnit: 'grace')

      ids = VersionService.for_model('User', whodunnit: 'ada').map(&:id)

      assert_equal [wanted.id], ids & [wanted.id, other.id]
    end

    test 'keeps only the versions inside the date range' do
      wanted = create_test_version(created_at: 2.days.ago)
      other = create_test_version(created_at: 20.days.ago)

      ids = VersionService.for_model('User', from_date: 5.days.ago.to_date.to_s).map(&:id)

      assert_equal [wanted.id], ids & [wanted.id, other.id]
    end

    test 'keeps only the versions whose stored data contain the search text' do
      wanted = create_test_version(object_changes: { name: %w[old needle] }.to_yaml)
      other = create_test_version(object_changes: { name: %w[old haystack] }.to_yaml)

      ids = VersionService.for_model('User', search: 'needle').map(&:id)

      assert_equal [wanted.id], ids & [wanted.id, other.id]
    end

    test 'treats a wildcard of the user as a normal character' do
      wanted = create_test_version(object_changes: { name: ['old', '50% off'] }.to_yaml)
      other = create_test_version(object_changes: { name: %w[old plain] }.to_yaml)

      ids = VersionService.for_model('User', search: '%').map(&:id)

      assert_equal [wanted.id], ids & [wanted.id, other.id]
    end

    test 'gives the versions of the named record' do
      wanted = create_test_version(item_id: 123)
      other = create_test_version(item_id: 456)

      ids = VersionService.for_record('User', 123).map(&:id)

      assert_equal [wanted.id], ids & [wanted.id, other.id]
    end

    test 'gives the people that appear in the versions' do
      create_test_version(whodunnit: 'ada')

      assert_includes VersionService.unique_whodunnits, 'ada'
    end

    test 'gives the events that appear in the versions' do
      create_test_version(event: 'destroy')

      assert_includes VersionService.available_events, 'destroy'
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

    test 'reads the whodunnit values with the database and not with Ruby' do
      queries = capture_sql { VersionService.unique_whodunnits }

      assert_not(queries.any? { |sql| sql.match?(/SELECT\s+"versions"\.\*/) })
    end

    test 'reads the event values with the database and not with Ruby' do
      queries = capture_sql { VersionService.available_events }

      assert_not(queries.any? { |sql| sql.match?(/SELECT\s+"versions"\.\*/) })
    end

    test 'gives the whodunnit values of all version tables' do
      create_test_version(whodunnit: 'zoe')

      assert_includes VersionService.unique_whodunnits, 'zoe'
    end

    test 'gives the event values of all version tables' do
      create_test_version(event: 'destroy')

      assert_includes VersionService.available_events, 'destroy'
    end

    test 'gives each whodunnit value one time' do
      create_test_version(whodunnit: 'twin')
      create_test_version(whodunnit: 'twin')

      assert_equal 1, VersionService.unique_whodunnits.count('twin')
    end

    test 'ignores a from date that is not a date' do
      versions = VersionService.for_model('User', from_date: 'not-a-date')

      assert_equal all_user_versions_count, versions.count
    end

    test 'ignores a to date that is not a date' do
      versions = VersionService.for_model('User', to_date: '2026-13-45')

      assert_equal all_user_versions_count, versions.count
    end

    test 'ignores a date that is not a date for a record' do
      versions = VersionService.for_record('User', 1, from_date: 'not-a-date')

      assert_equal PaperTrail::Version.where(item_type: 'User', item_id: 1).count, versions.count
    end

    test 'still uses a from date that is a date' do
      create_test_version(created_at: 10.days.ago)

      versions = VersionService.for_model('User', from_date: 1.day.ago.to_date.to_s)

      assert_not_includes versions.map(&:created_at).map(&:to_date), 10.days.ago.to_date
    end

    test 'still uses a to date that is a date' do
      recent_version = create_test_version(created_at: Time.current)

      versions = VersionService.for_model('User', to_date: 5.days.ago.to_date.to_s)

      assert_not_includes versions.map(&:id), recent_version.id
    end

    test 'gives back the record with the restored values' do
      user = changed_user

      result = VersionService.restore_version(user.versions.last)

      assert_equal 'Original', result[:item].name
    end

    test 'gives back the restored values also when the item was read before the restore' do
      user = changed_user
      version = user.versions.last
      version.item # loads and keeps the record as it is now

      result = VersionService.restore_version(version)

      assert_equal 'Original', result[:item].name
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

    def all_user_versions_count
      PaperTrail::Version.where(item_type: 'User').count
    end

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
