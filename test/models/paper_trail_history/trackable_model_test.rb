# frozen_string_literal: true

require 'test_helper'

module PaperTrailHistory
  class TrackableModelTest < ActiveSupport::TestCase
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
