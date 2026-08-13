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

    test 'finds a record of a model whose primary key is not id' do
      document = Document.create!(uuid: SecureRandom.uuid, title: 'Contract')

      get "/paper_trail_history/models/Document/records/#{document.uuid}"

      assert_select 'dd', text: 'Contract'
    end

    # The version list stays empty here, because the versions table of the dummy
    # application keeps item_id as bigint and PaperTrail writes the UUID as 0.
    # A host application with such a model needs a string item_id column. The
    # page must work in any case.
    test 'shows the version page of a record whose primary key is not id' do
      document = Document.create!(uuid: SecureRandom.uuid, title: 'Contract')
      document.update!(title: 'Contract v2')

      get "/paper_trail_history/models/Document/records/#{document.uuid}/versions"

      assert_response :success
    end

    test 'redirects for a model that is not trackable' do
      get "/paper_trail_history/models/NoSuchModel/records/#{@user.id}"

      assert_redirected_to models_path
    end
  end
end
