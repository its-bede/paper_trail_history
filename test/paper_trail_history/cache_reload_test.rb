# frozen_string_literal: true

require 'test_helper'

module PaperTrailHistory
  # The caches hold class objects. Rails reloads the code in development and
  # makes new class objects, thus a cache that survives a reload gives classes
  # that Rails removed.
  class CacheReloadTest < ActiveSupport::TestCase
    teardown do
      TrackableModel.clear_cache!
      VersionService.clear_cache!
    end

    test 'keeps the model list until the cache is cleared' do
      assert_same TrackableModel.all, TrackableModel.all
    end

    test 'makes a new model list after the cache is cleared' do
      models = TrackableModel.all
      TrackableModel.clear_cache!

      assert_not_same models, TrackableModel.all
    end

    test 'makes a new version class list after the cache is cleared' do
      version_classes = VersionService.all_version_classes
      VersionService.clear_cache!

      assert_not_same version_classes, VersionService.all_version_classes
    end

    test 'clears the model cache when Rails prepares the code' do
      models = TrackableModel.all

      Rails.application.reloader.prepare!

      assert_not_same models, TrackableModel.all
    end

    test 'clears the version class cache when Rails prepares the code' do
      version_classes = VersionService.all_version_classes

      Rails.application.reloader.prepare!

      assert_not_same version_classes, VersionService.all_version_classes
    end

    test 'gives one model list to threads that ask at the same time' do
      TrackableModel.clear_cache!

      lists = Array.new(4) { Thread.new { TrackableModel.all } }.map(&:value)

      assert_equal 1, lists.map(&:object_id).uniq.size
    end
  end
end
