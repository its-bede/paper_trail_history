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

    test 'gives no nonce when the host application makes an empty one' do
      with_helper_method(:content_security_policy_nonce, '') do
        assert_nil engine_csp_nonce
      end
    end

    test 'gives no nonce when the host application uses no policy' do
      with_helper_method(:content_security_policy_nonce, nil) do
        assert_nil engine_csp_nonce
      end
    end

    test 'gives the nonce of the host application' do
      with_helper_method(:content_security_policy_nonce, 'abc123') do
        assert_equal 'abc123', engine_csp_nonce
      end
    end

    test 'writes no integrity for an asset without one' do
      PaperTrailHistory.configure do |config|
        config.assets = { bootstrap_css: { href: '/local.css' } }
      end

      with_helper_method(:content_security_policy_nonce, nil) do
        assert_no_match(/integrity/, engine_stylesheet_tag(:bootstrap_css))
      end
    ensure
      PaperTrailHistory.reset_config!
    end

    private

    # ActionView::TestCase mixes the helpers into the test case, thus the method
    # gets replaced on the test case for the time of the block. The name is not
    # `stub`, because Minitest already gives that name to each object.
    def with_helper_method(method_name, value)
      singleton_class.define_method(method_name) { value }
      yield
    ensure
      singleton_class.remove_method(method_name)
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
