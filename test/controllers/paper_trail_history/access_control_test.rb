# frozen_string_literal: true

require 'test_helper'

module PaperTrailHistory
  class AccessControlTest < ActionDispatch::IntegrationTest
    setup do
      @version = PaperTrail::Version.create!(
        item_type: 'User',
        item_id: 1,
        event: 'update',
        whodunnit: 'test_user',
        object: { name: 'old_name' }.to_yaml,
        object_changes: { name: %w[old_name new_name] }.to_yaml,
        created_at: Time.current
      )
    end

    teardown do
      PaperTrailHistory.reset_config!
    end

    test 'gives access in a local environment when the host application configures nothing' do
      get '/paper_trail_history/models'

      assert_response :success
    end

    test 'refuses access outside a local environment when the host application configures nothing' do
      enforcing_access_control do
        get '/paper_trail_history/models'
      end

      assert_response :forbidden
    end

    test 'gives access outside a local environment when the host application allows it' do
      PaperTrailHistory.configure { |config| config.allow_unauthenticated_access = true }

      enforcing_access_control do
        get '/paper_trail_history/models'
      end

      assert_response :success
    end

    test 'gives access outside a local environment when an authentication callback is set' do
      PaperTrailHistory.configure { |config| config.authenticate_with = -> { true } }

      enforcing_access_control do
        get '/paper_trail_history/models'
      end

      assert_response :success
    end

    test 'runs the authentication callback' do
      PaperTrailHistory.configure { |config| config.authenticate_with = -> { head :unauthorized } }

      get '/paper_trail_history/models'

      assert_response :unauthorized
    end

    test 'runs the authentication callback in the context of the controller' do
      PaperTrailHistory.configure do |config|
        config.authenticate_with = -> { head :unauthorized if params[:blocked].present? }
      end

      get '/paper_trail_history/models', params: { blocked: '1' }

      assert_response :unauthorized
    end

    test 'refuses a restore when the restore callback gives false' do
      PaperTrailHistory.configure { |config| config.authorize_restore_with = -> { false } }

      patch "/paper_trail_history/versions/#{@version.id}/restore"

      assert_equal I18n.t('paper_trail_history.errors.restore_not_allowed'), flash[:alert]
    end

    test 'does not restore the version when the restore callback gives false' do
      PaperTrailHistory.configure { |config| config.authorize_restore_with = -> { false } }
      restored = false

      VersionService.stub(:restore_version, ->(*) { restored = true }) do
        patch "/paper_trail_history/versions/#{@version.id}/restore"
      end

      assert_not restored
    end

    test 'restores the version when the restore callback gives true' do
      PaperTrailHistory.configure { |config| config.authorize_restore_with = -> { true } }
      restored = false

      VersionService.stub(:restore_version, lambda { |*|
        restored = true
        { success: true, message: 'Restored' }
      }) do
        patch "/paper_trail_history/versions/#{@version.id}/restore"
      end

      assert restored
    end

    test 'restores the version when the host application sets no restore callback' do
      restored = false

      VersionService.stub(:restore_version, lambda { |*|
        restored = true
        { success: true, message: 'Restored' }
      }) do
        patch "/paper_trail_history/versions/#{@version.id}/restore"
      end

      assert restored
    end

    private

    def enforcing_access_control(&)
      PaperTrailHistory.config.stub(:enforce_access_control?, true, &)
    end
  end
end
