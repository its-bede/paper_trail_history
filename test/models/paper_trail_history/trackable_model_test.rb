# frozen_string_literal: true

require 'test_helper'

module PaperTrailHistory
  class TrackableModelTest < ActiveSupport::TestCase
    test 'uses the name of the base class for the item type of a subclass' do
      assert_equal 'User', TrackableModel.find('Admin').item_type_for_versions
    end

    test 'finds the versions of a subclass' do
      admin = Admin.create!(name: 'Grace', email: "sti-#{SecureRandom.hex(4)}@example.com")

      assert_includes TrackableModel.find('Admin').versions.map(&:item_id), admin.id
    end

    test 'does not give the versions of the base class to a subclass' do
      plain_user = User.create!(name: 'Plain', email: "sti-#{SecureRandom.hex(4)}@example.com")

      assert_not_includes TrackableModel.find('Admin').versions.map(&:item_id), plain_user.id
    end

    test 'gives the versions of a subclass to the base class' do
      admin = Admin.create!(name: 'Grace', email: "sti-#{SecureRandom.hex(4)}@example.com")

      assert_includes TrackableModel.find('User').versions.map(&:item_id), admin.id
    end

    test 'counts only the versions of a subclass' do
      Admin.create!(name: 'Grace', email: "sti-#{SecureRandom.hex(4)}@example.com")
      User.create!(name: 'Plain', email: "sti-#{SecureRandom.hex(4)}@example.com")

      assert_equal Admin.count, TrackableModel.find('Admin').total_versions_count
    end

    test 'counts the versions of a subclass in the list of all models' do
      Admin.create!(name: 'Grace', email: "sti-#{SecureRandom.hex(4)}@example.com")

      model = TrackableModel.all_with_counts.find { |trackable| trackable.name == 'Admin' }

      assert_equal Admin.count, model.total_versions_count
    end

    test 'uses only the item type when the version table has no item subtype' do
      trackable_model = TrackableModel.find('Admin')
      columns = PaperTrail::Version.column_names - ['item_subtype']

      PaperTrail::Version.stub(:column_names, columns) do
        assert_no_match(/item_subtype/, trackable_model.versions.to_sql)
      end
    end

    test 'finds all trackable models' do
      trackable_models = TrackableModel.all
      assert_kind_of Array, trackable_models
      assert(trackable_models.all? { |model| model.is_a?(TrackableModel) })
    end

    test 'finds specific model by name' do
      trackable_models = TrackableModel.all
      return if trackable_models.empty?

      first_model = trackable_models.first
      found_model = TrackableModel.find(first_model.name)

      assert_not_nil found_model
      assert_equal first_model.name, found_model.name
    end

    test 'returns nil for non-existent model' do
      found_model = TrackableModel.find('NonExistentModel')
      assert_nil found_model
    end

    test 'returns versions for model' do
      trackable_models = TrackableModel.all
      return if trackable_models.empty?

      model = trackable_models.first
      versions = model.versions

      assert_respond_to versions, :where
      # versions should be a relation that includes the model's item_type
      assert_includes versions.to_sql, model.item_type_for_versions
    end

    test 'returns human name' do
      trackable_models = TrackableModel.all
      return if trackable_models.empty?

      model = trackable_models.first
      human_name = model.human_name

      assert_kind_of String, human_name
      assert human_name.present?
    end

    test 'returns table name' do
      trackable_models = TrackableModel.all
      return if trackable_models.empty?

      model = trackable_models.first
      table_name = model.table_name

      assert_kind_of String, table_name
      assert table_name.present?
    end
  end
end
