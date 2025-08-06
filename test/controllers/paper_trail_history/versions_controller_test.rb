# frozen_string_literal: true

require 'test_helper'

module PaperTrailHistory
  class VersionsControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      @version = create_test_version
    end

    test 'should get show' do
      # Create a flexible mock that responds to any number of calls
      mock_model = Object.new
      def mock_model.name
        'User'
      end

      def mock_model.human_name
        'Users'
      end

      TrackableModel.stub :find, mock_model do
        get version_url(@version)
        assert_response :success
        assert_select 'h1', 'Version Details'
      end
    end

    test 'redirects for non-existent version' do
      get version_url(99_999)
      assert_redirected_to root_path
      follow_redirect!
      assert_select '.alert-danger'
    end

    test 'should restore version' do
      result = { success: true, message: 'Restored successfully' }

      VersionService.stub :restore_version, result do
        patch restore_version_url(@version)
        assert_redirected_to version_path(@version)
        follow_redirect!
        assert_select '.alert-success'
      end
    end

    test 'should handle restore failure' do
      result = { success: false, error: 'Restoration failed' }

      VersionService.stub :restore_version, result do
        patch restore_version_url(@version)
        assert_redirected_to version_path(@version)
        follow_redirect!
        assert_select '.alert-danger'
      end
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
