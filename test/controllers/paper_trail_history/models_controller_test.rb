# frozen_string_literal: true

require 'test_helper'

module PaperTrailHistory
  class ModelsControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    test 'should get index' do
      get models_url
      assert_response :success
      assert_select 'h1', 'Trackable Models'
    end

    test 'index shows message when no models' do
      TrackableModel.stub :all, [] do
        get models_url
        assert_response :success
        assert_select '.alert-info', text: /No trackable models found/
      end
    end

    test 'should redirect for non-existent model' do
      get model_url('NonExistentModel')
      assert_redirected_to models_path
      follow_redirect!
      assert_select '.alert-danger'
    end

    test 'should get versions for existing model' do
      # Create a flexible mock that responds to any number of calls
      mock_model = Object.new
      def mock_model.name
        'User'
      end

      def mock_model.human_name
        'Users'
      end

      TrackableModel.stub :find, mock_model do
        VersionService.stub :for_model, PaperTrail::Version.none do
          VersionService.stub :available_events, [] do
            VersionService.stub :unique_whodunnits, [] do
              get versions_model_url('User')
              assert_response :success
            end
          end
        end
      end
    end

    test 'versions redirects for non-existent model' do
      TrackableModel.stub :find, nil do
        get versions_model_url('NonExistentModel')
        assert_redirected_to models_path
        follow_redirect!
        assert_select '.alert-danger'
      end
    end
  end
end
