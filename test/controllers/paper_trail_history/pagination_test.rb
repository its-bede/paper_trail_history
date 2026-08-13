# frozen_string_literal: true

require 'test_helper'

module PaperTrailHistory
  class PaginationTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      @user = User.create!(name: 'Ada Lovelace', email: "p1-#{SecureRandom.hex(4)}@example.com")
      # Creating the user writes its own create version. Remove it, so that the
      # tests count exactly the 30 versions that they make.
      PaperTrail::Version.where(item_type: 'User').delete_all
      create_versions(30)
    end

    teardown do
      PaperTrailHistory.reset_config!
    end

    test 'shows only one page of the versions of a model' do
      PaperTrailHistory.configure { |config| config.page_limit = 25 }

      get versions_model_path('User')

      assert_select 'tbody tr', count: 25
    end

    test 'shows the rest of the versions of a model on the next page' do
      PaperTrailHistory.configure { |config| config.page_limit = 25 }

      get versions_model_path('User', page: 2)

      assert_select 'tbody tr', count: 5
    end

    test 'shows the navigation when more than one page exists' do
      PaperTrailHistory.configure { |config| config.page_limit = 25 }

      get versions_model_path('User')

      assert_select 'nav[aria-label=?] .pagination', 'Pagination'
    end

    test 'does not show the navigation when one page is enough' do
      PaperTrailHistory.configure { |config| config.page_limit = 100 }

      get versions_model_path('User')

      assert_select 'nav[aria-label=?] .pagination', 'Pagination', count: 0
    end

    test 'counts all versions and not only the versions of the page' do
      PaperTrailHistory.configure { |config| config.page_limit = 25 }

      get versions_model_path('User')

      assert_select '.badge', text: '30 versions'
    end

    test 'uses the page limit that the host application sets' do
      PaperTrailHistory.configure { |config| config.page_limit = 10 }

      get versions_model_path('User')

      assert_select 'tbody tr', count: 10
    end

    test 'shows only one page of the versions of a record' do
      PaperTrailHistory.configure { |config| config.page_limit = 25 }

      get versions_model_record_path('User', @user.id)

      assert_select 'tbody tr', count: 25
    end

    test 'keeps a filter on the next page' do
      PaperTrailHistory.configure { |config| config.page_limit = 25 }

      get versions_model_path('User', event: 'update', page: 2)

      assert_select 'tbody tr', count: 5
    end

    private

    def create_versions(count)
      count.times do |index|
        PaperTrail::Version.create!(
          item_type: 'User',
          item_id: @user.id,
          event: 'update',
          whodunnit: "user_#{index}",
          object: { name: 'old_name' }.to_yaml,
          object_changes: { name: %w[old_name new_name] }.to_yaml,
          created_at: index.hours.ago
        )
      end
    end
  end
end
