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

      def mock_model.version_class
        PaperTrail::Version
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
        assert_redirected_to version_path(@version, model_name: @version.item_type)
        follow_redirect!
        assert_select '.alert-success'
      end
    end

    test 'should handle restore failure' do
      result = { success: false, error: 'Restoration failed' }

      VersionService.stub :restore_version, result do
        patch restore_version_url(@version)
        assert_redirected_to version_path(@version, model_name: @version.item_type)
        follow_redirect!
        assert_select '.alert-danger'
      end
    end

    test 'should get show with model_name parameter' do
      mock_model = Object.new
      def mock_model.name
        'User'
      end

      def mock_model.human_name
        'Users'
      end

      def mock_model.version_class
        PaperTrail::Version
      end

      TrackableModel.stub :find, mock_model do
        get version_url(@version, model_name: 'User')
        assert_response :success
        assert_select 'h1', 'Version Details'
      end
    end

    test 'should get show without model_name parameter (backwards compatibility)' do
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

    test 'redirects for version with invalid model_name' do
      get version_url(@version, model_name: 'NonExistentModel')
      assert_redirected_to root_path
      follow_redirect!
      assert_select '.alert-danger'
    end

    test 'redirects when the model of the version is not trackable' do
      version = version_of_a_model_that_no_longer_exists

      get version_url(version)

      assert_redirected_to models_path
    end

    test 'tells the user when the model of the version is not trackable' do
      version = version_of_a_model_that_no_longer_exists

      get version_url(version)
      follow_redirect!

      assert_select '.alert-danger'
    end

    test 'restores the version of the model that the request names' do
      product = Product.create!(name: 'Original', price: 10, sku: "SKU-#{SecureRandom.hex(4)}")
      product.update!(name: 'Changed')
      product_version = product.versions.last
      PaperTrail::Version.where(id: product_version.id).delete_all
      create_test_version(id: product_version.id, event: 'create')

      patch restore_version_url(product_version.id, model_name: 'Product')

      assert_equal 'Original', product.reload.name
    end

    private

    # An application that renames or deletes a model keeps the versions of the
    # old name. The column gets the value directly, because the association
    # cannot resolve a class that does not exist.
    def version_of_a_model_that_no_longer_exists
      version = create_test_version
      # rubocop:disable Rails/SkipsModelValidations
      version.update_column(:item_type, 'GoneModel')
      # rubocop:enable Rails/SkipsModelValidations

      version
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
