# frozen_string_literal: true

module PaperTrailHistory
  # Holds the settings that connect the engine to the host application.
  #
  # The engine has no authentication of its own. Because
  # {PaperTrailHistory::ApplicationController} does not descend from the host
  # application's +ApplicationController+, none of the host's +before_action+
  # filters run. The host application therefore has to grant access explicitly,
  # either by giving a parent controller, by giving an authentication callback,
  # or by allowing unauthenticated access on purpose.
  #
  # Set the configuration in an initializer. The engine reads
  # {#parent_controller} once, when Rails loads the controller for the first
  # request. A later change has no effect.
  #
  # @example config/initializers/paper_trail_history.rb
  #   PaperTrailHistory.configure do |config|
  #     config.parent_controller      = 'Admin::BaseController'
  #     config.authenticate_with      = -> { authenticate_user! }
  #     config.authorize_restore_with = -> { current_user.admin? }
  #   end
  class Configuration
    # Parent controller that the engine uses when the host application gives none.
    DEFAULT_PARENT_CONTROLLER = 'ActionController::Base'

    # @return [String] name of the controller class that the engine controllers descend from
    attr_accessor :parent_controller

    # Callback that runs as a +before_action+ on every engine request.
    #
    # The engine runs the callback with +instance_exec+ in the controller. Thus
    # the callback can use +current_user+, +session+, +redirect_to+, +head+ and
    # the route helpers of the host application. To refuse the request, stop the
    # filter chain in the usual Rails manner, for example with +redirect_to+ or
    # +head+.
    #
    # @return [Proc, nil]
    attr_accessor :authenticate_with

    # Callback that decides if the current user can restore a version.
    #
    # Different from {#authenticate_with}, this callback is a predicate: give
    # back +true+ to permit the restore and +false+ to refuse it. The engine
    # runs it with +instance_exec+ in the controller. If it is +nil+, each
    # request that passes {#authenticate_with} can restore a version.
    #
    # @return [Proc, nil]
    attr_accessor :authorize_restore_with

    # Lets the engine run without authentication outside development and test.
    #
    # Set this to +true+ only if a different layer protects the mount point, for
    # example a VPN or a reverse proxy.
    #
    # @return [Boolean]
    attr_accessor :allow_unauthenticated_access

    def initialize
      @parent_controller = DEFAULT_PARENT_CONTROLLER
      @authenticate_with = nil
      @authorize_restore_with = nil
      @allow_unauthenticated_access = false
    end

    # Tells if the host application granted access to the engine.
    #
    # @return [Boolean] true if the host application gave a parent controller,
    #   gave an authentication callback, or allowed unauthenticated access
    def access_configured?
      custom_parent_controller? || authenticate_with.present? || allow_unauthenticated_access
    end

    # Tells if the engine must refuse a request that no one configured access for.
    #
    # The engine stays open in development and in test, so that the dummy
    # application and the test suite work without an initializer.
    #
    # @return [Boolean]
    def enforce_access_control?
      !Rails.env.local?
    end

    # Resolves {#parent_controller} to a class.
    #
    # @return [Class] the controller class that the engine controllers descend from
    # @raise [PaperTrailHistory::ConfigurationError] if the constant does not
    #   exist or is not an ActionController::Base descendant
    def parent_controller_class
      klass = parent_controller.to_s.constantize
      unless klass.is_a?(Class) && klass <= ActionController::Base
        raise ConfigurationError,
              "PaperTrailHistory parent_controller #{parent_controller.inspect} " \
              'must be an ActionController::Base descendant'
      end

      klass
    rescue NameError => e
      raise ConfigurationError,
            "PaperTrailHistory parent_controller #{parent_controller.inspect} does not exist: #{e.message}"
    end

    private

    def custom_parent_controller?
      parent_controller.to_s != DEFAULT_PARENT_CONTROLLER
    end
  end
end
