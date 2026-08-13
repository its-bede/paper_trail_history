# frozen_string_literal: true

require 'test_helper'

module PaperTrailHistory
  # The engine loads no Turbo and no rails-ujs, thus `data-confirm` does nothing.
  # The engine brings its own handler. These tests check the markup and the
  # handler. They do not run JavaScript, thus they cannot prove that the browser
  # opens the dialog.
  class RestoreConfirmationTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      @user = User.create!(name: 'Ada Lovelace', email: "r5-#{SecureRandom.hex(4)}@example.com")
      @user.update!(name: 'Ada L.')
      @version = PaperTrail::Version.where(item_type: 'User', item_id: @user.id, event: 'update').last
    end

    test 'asks for a confirmation before a restore in the version list' do
      get versions_model_url('User')

      assert_select 'form[data-pth-confirm]'
    end

    test 'asks for a confirmation before a restore on the version page' do
      get version_url(@version, model_name: 'User')

      assert_select 'form[data-pth-confirm]'
    end

    test 'uses the translated confirmation message' do
      get version_url(@version, model_name: 'User')

      assert_select 'form[data-pth-confirm=?]', I18n.t('paper_trail_history.confirmations.restore_version')
    end

    test 'does not ask for a confirmation when a restore is not possible' do
      create_version = PaperTrail::Version.where(item_type: 'User', item_id: @user.id, event: 'create').last

      get version_url(create_version, model_name: 'User')

      assert_select 'form[data-pth-confirm]', count: 0
    end

    test 'loads the handler that shows the dialog' do
      get versions_model_url('User')

      assert_match 'pthConfirm', response.body
    end
  end
end
