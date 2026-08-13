# frozen_string_literal: true

require 'test_helper'

module PaperTrailHistory
  class ConfigurationTest < ActiveSupport::TestCase
    teardown do
      PaperTrailHistory.reset_config!
    end

    test 'uses ActionController::Base as the default parent controller' do
      assert_equal 'ActionController::Base', PaperTrailHistory.config.parent_controller
    end

    test 'access is not configured by default' do
      assert_not PaperTrailHistory.config.access_configured?
    end

    test 'access is configured when an authentication callback is set' do
      PaperTrailHistory.configure { |config| config.authenticate_with = -> { true } }

      assert PaperTrailHistory.config.access_configured?
    end

    test 'access is configured when the host application sets a parent controller' do
      PaperTrailHistory.configure { |config| config.parent_controller = 'ApplicationController' }

      assert PaperTrailHistory.config.access_configured?
    end

    test 'access is configured when the host application allows unauthenticated access' do
      PaperTrailHistory.configure { |config| config.allow_unauthenticated_access = true }

      assert PaperTrailHistory.config.access_configured?
    end

    test 'resolves the parent controller class' do
      assert_equal ActionController::Base, PaperTrailHistory.config.parent_controller_class
    end

    test 'refuses a parent controller that is not a controller' do
      PaperTrailHistory.configure { |config| config.parent_controller = 'String' }

      assert_raises(PaperTrailHistory::ConfigurationError) do
        PaperTrailHistory.config.parent_controller_class
      end
    end

    test 'refuses a parent controller that does not exist' do
      PaperTrailHistory.configure { |config| config.parent_controller = 'NoSuchController' }

      assert_raises(PaperTrailHistory::ConfigurationError) do
        PaperTrailHistory.config.parent_controller_class
      end
    end

    test 'does not enforce access control in a local environment' do
      assert_not PaperTrailHistory.config.enforce_access_control?
    end

    test 'reset_config! gives back the default configuration' do
      PaperTrailHistory.configure { |config| config.allow_unauthenticated_access = true }
      PaperTrailHistory.reset_config!

      assert_not PaperTrailHistory.config.allow_unauthenticated_access
    end
  end
end
