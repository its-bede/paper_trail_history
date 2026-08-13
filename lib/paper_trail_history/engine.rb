# frozen_string_literal: true

module PaperTrailHistory
  # Engine to integrate PaperTrailHistory into a Rails application.
  class Engine < ::Rails::Engine
    isolate_namespace PaperTrailHistory

    # The engine caches the trackable models and their version classes, because
    # the discovery is expensive. The caches hold class objects, and a code
    # reload in development replaces those objects. A cache that survives the
    # reload gives classes that Rails removed from the module tree, thus the
    # engine empties the caches on each reload.
    config.to_prepare do
      PaperTrailHistory::TrackableModel.clear_cache!
      PaperTrailHistory::VersionService.clear_cache!
    end
  end
end
