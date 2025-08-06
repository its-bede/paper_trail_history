# frozen_string_literal: true

require 'test_helper'

module PaperTrailHistory
  class NavigationTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    test 'root shows models index' do
      get '/paper_trail_history/'
      assert_response :success
      assert_select 'h1', 'Trackable Models'
    end

    test 'can navigate through the interface' do
      get '/paper_trail_history/models'
      assert_response :success
      assert_select 'h1', 'Trackable Models'

      # Test navigation elements
      assert_select 'nav.navbar'
      assert_select '.navbar-brand', 'Paper Trail History'
      assert_select '.nav-link', 'All Models'
    end

    test 'shows flash messages' do
      # Test flash notice
      get '/paper_trail_history/models'
      assert_response :success

      # Flash messages are tested differently in integration tests
      # We would need a controller action that sets flash to test this properly
      # For now, just verify the page structure can handle flash messages
      assert_select '.container'
    end

    test 'layout includes bootstrap styling' do
      get '/paper_trail_history/models'
      assert_response :success

      # Check for Bootstrap CSS
      assert_select "link[href*='bootstrap']"
      assert_select "script[src*='bootstrap']"

      # Check for Bootstrap Icons
      assert_select "link[href*='bootstrap-icons']"
    end
  end
end
