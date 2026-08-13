# frozen_string_literal: true

require 'test_helper'

module PaperTrailHistory
  class RecordsControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      @user = User.create!(name: 'Ada Lovelace', email: "s2-#{SecureRandom.hex(4)}@example.com")
    end

    teardown do
      PaperTrailHistory.reset_config!
    end

    test 'shows the record page' do
      get "/paper_trail_history/models/User/records/#{@user.id}"

      assert_response :success
    end

    test 'hides the value of an attribute that the host application filters' do
      get "/paper_trail_history/models/User/records/#{@user.id}"

      assert_no_match @user.email, response.body
    end

    test 'shows the value of an attribute that the host application does not filter' do
      get "/paper_trail_history/models/User/records/#{@user.id}"

      assert_match 'Ada Lovelace', response.body
    end

    test 'shows the version list of the record' do
      @user.update!(name: 'Ada L.')

      get "/paper_trail_history/models/User/records/#{@user.id}/versions"

      assert_select 'tbody tr', count: @user.versions.count
    end

    test 'shows only the versions with the event of the URL' do
      @user.update!(name: 'Ada L.')

      get "/paper_trail_history/models/User/records/#{@user.id}/versions", params: { event: 'create' }

      assert_select 'tbody tr', count: 1
    end

    test 'shows the version list for a record that is deleted' do
      id = @user.id
      @user.destroy!

      get "/paper_trail_history/models/User/records/#{id}/versions"

      assert_response :success
    end

    test 'redirects for a model that is not trackable' do
      get "/paper_trail_history/models/NoSuchModel/records/#{@user.id}"

      assert_redirected_to models_path
    end
  end
end
