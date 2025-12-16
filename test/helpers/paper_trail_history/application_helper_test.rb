# frozen_string_literal: true

require 'test_helper'

module PaperTrailHistory
  class ApplicationHelperTest < ActionView::TestCase
    include Engine.routes.url_helpers

    setup do
      @version = create_test_version
    end

    test 'version_link_path includes model_name from version' do
      path = version_link_path(@version)
      assert_includes path, 'model_name=User'
    end

    test 'version_link_path accepts model_name option' do
      path = version_link_path(@version, model_name: 'CustomModel')
      assert_includes path, 'model_name=CustomModel'
    end

    test 'restore_version_link_path includes model_name from version' do
      path = restore_version_link_path(@version)
      assert_includes path, 'model_name=User'
    end

    test 'restore_version_link_path accepts model_name option' do
      path = restore_version_link_path(@version, model_name: 'CustomModel')
      assert_includes path, 'model_name=CustomModel'
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
