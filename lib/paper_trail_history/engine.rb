# frozen_string_literal: true

module PaperTrailHistory
  # Engine to integrate PaperTrailHistory into a Rails application.
  class Engine < ::Rails::Engine
    isolate_namespace PaperTrailHistory
  end
end
