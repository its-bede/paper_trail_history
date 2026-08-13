# frozen_string_literal: true

require 'test_helper'

module PaperTrailHistory
  # The dummy application uses a strict Content Security Policy, thus these
  # tests also show that the engine works in a host application with a policy.
  class AssetsTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    teardown do
      PaperTrailHistory.reset_config!
    end

    test 'protects the external stylesheet with an integrity value' do
      get models_url

      assert_select 'link[rel=stylesheet][integrity^=?]', 'sha384-'
    end

    test 'protects the external script with an integrity value' do
      get models_url

      assert_select 'script[src][integrity^=?]', 'sha384-'
    end

    test 'marks the external stylesheet as a request to another origin' do
      get models_url

      assert_select 'link[rel=stylesheet][integrity][crossorigin=?]', 'anonymous'
    end

    test 'gives the inline style a nonce that is not empty' do
      get models_url

      assert_not_empty css_select('style').first['nonce']
    end

    test 'gives the inline script a nonce that is not empty' do
      get models_url

      assert_not_empty css_select('script:not([src])').first['nonce']
    end

    test 'gives the external script a nonce that is not empty' do
      get models_url

      assert_not_empty css_select('script[src]').first['nonce']
    end

    test 'writes the inline script without HTML escaping' do
      get models_url

      assert_match 'event.target.dataset && event.target.dataset.pthConfirm', response.body
    end

    test 'writes the inline style without HTML escaping' do
      get models_url

      assert_match '.diff-line code {', response.body
    end

    test 'uses the asset that the host application sets' do
      PaperTrailHistory.configure do |config|
        config.assets = config.assets.merge(bootstrap_css: { href: '/vendor/bootstrap.css' })
      end

      get models_url

      assert_select 'link[href=?]', '/vendor/bootstrap.css'
    end

    test 'sets no integrity for an asset of the host application without one' do
      PaperTrailHistory.configure do |config|
        config.assets = config.assets.merge(bootstrap_css: { href: '/vendor/bootstrap.css' })
      end

      get models_url

      assert_select 'link[href="/vendor/bootstrap.css"][integrity]', count: 0
    end
  end
end
