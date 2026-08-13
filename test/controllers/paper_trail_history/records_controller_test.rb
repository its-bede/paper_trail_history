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

    test 'redirects for a model that is not trackable' do
      get "/paper_trail_history/models/NoSuchModel/records/#{@user.id}"

      assert_redirected_to models_path
    end
  end
end
