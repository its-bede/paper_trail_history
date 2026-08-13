# frozen_string_literal: true

require 'test_helper'

module PaperTrailHistory
  # Renders each page in German. The test environment raises for a missing
  # translation, thus a page with a forgotten text fails here.
  class TranslationsTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      @user = User.create!(name: 'Ada Lovelace', email: "i18n-#{SecureRandom.hex(4)}@example.com")
      @user.update!(name: 'Ada L.')
      @version = PaperTrail::Version.where(item_type: 'User', item_id: @user.id).last
    end

    test 'shows the model list in German' do
      in_german { get models_url }

      assert_select 'h1', 'Verfolgbare Modelle'
    end

    test 'shows the model page in German' do
      in_german { get model_url('User') }

      assert_select 'h5', 'Modellinformationen'
    end

    test 'shows the version list of a model in German' do
      in_german { get versions_model_url('User') }

      assert_select 'h1', /Alle Versionen/
    end

    test 'shows the record page in German' do
      in_german { get "/paper_trail_history/models/User/records/#{@user.id}" }

      assert_select 'h5', 'Aktueller Datensatz'
    end

    test 'shows the version list of a record in German' do
      in_german { get "/paper_trail_history/models/User/records/#{@user.id}/versions" }

      assert_select 'h1', /Alle Versionen/
    end

    test 'shows the version page in German' do
      in_german { get version_url(@version, model_name: 'User') }

      assert_select 'h1', 'Versionsdetails'
    end

    test 'translates the navigation in German' do
      in_german { get models_url }

      assert_select '.nav-link', 'Alle Modelle'
    end

    test 'translates the table headers in German' do
      in_german { get versions_model_url('User') }

      assert_select 'th', 'Ereignis'
    end

    test 'translates the confirmation of a restore in German' do
      in_german { get versions_model_url('User') }

      assert_select 'form[data-pth-confirm^=?]', 'Diese Version wiederherstellen?'
    end

    test 'writes the date in the German format' do
      in_german { get versions_model_url('User') }

      assert_select 'td small', /\d{2}\.\d{2}\.\d{4} um \d{2}:\d{2}/
    end

    test 'shows the English pages without a missing translation' do
      get versions_model_url('User')

      assert_response :success
    end

    private

    def in_german(&)
      original = I18n.default_locale
      I18n.default_locale = :de
      yield
    ensure
      I18n.default_locale = original
    end
  end
end
