# frozen_string_literal: true

require 'paper_trail'
require 'paper_trail_history/version'
require 'paper_trail_history/configuration'
require 'paper_trail_history/engine'

# PaperTrailHistory is a Ruby on Rails engine that provides a history of changes made to models using
# the PaperTrail gem. It allows you to track changes, view previous versions of records, and restore them if needed.
#
# This engine integrates with the PaperTrail gem to provide a user-friendly interface for viewing and managing
# the history of changes made to your models. It includes routes, controllers, and views to display the history
# of changes in a structured manner.
#
# The engine shows the full audit trail and can overwrite records. It has no
# authentication of its own. Give it the access rules of the host application
# with {PaperTrailHistory.configure}.
module PaperTrailHistory
  # Base class for all errors of this engine.
  class Error < StandardError; end

  # Raised when the configuration of the host application is not usable.
  class ConfigurationError < Error; end

  class << self
    # Gives the configuration of the engine.
    #
    # @return [PaperTrailHistory::Configuration]
    def config
      @config ||= Configuration.new
    end

    # Configures the engine.
    #
    # @example
    #   PaperTrailHistory.configure do |config|
    #     config.authenticate_with = -> { authenticate_user! }
    #   end
    #
    # @yieldparam config [PaperTrailHistory::Configuration]
    # @return [PaperTrailHistory::Configuration]
    def configure
      yield config
      config
    end

    # Gives back the default configuration.
    #
    # This method exists for the test suite. Do not use it in an application.
    #
    # @return [PaperTrailHistory::Configuration]
    def reset_config!
      @config = Configuration.new
    end
  end
end
