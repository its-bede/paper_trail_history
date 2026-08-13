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

    # Number of versions on one page when the host application gives none.
    DEFAULT_PAGE_LIMIT = 25

    # The interface uses Bootstrap. The engine loads it from a public CDN and
    # protects each file with a subresource integrity value, thus the browser
    # refuses a file that somebody changed.
    #
    # The values belong to the pinned versions below. If you change a URL, you
    # must also change the integrity value or remove it.
    DEFAULT_ASSETS = {
      bootstrap_css: {
        href: 'https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css',
        integrity: 'sha384-9ndCyUaIbzAi2FUVXJi0CjmCapSmO7SnpJef0486qhLnuZ2cdeRhO02iuK6FUUVM'
      },
      bootstrap_icons_css: {
        href: 'https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.0/font/bootstrap-icons.css',
        integrity: 'sha384-l4UPAMHGzl7zwogLW4nOwaU2XTk6oiM1jhCRQstZEndoIiA2I5bg6fST3wzBSRBD'
      },
      bootstrap_js: {
        href: 'https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js',
        integrity: 'sha384-geWF76RCwLtnZ8qwWowPQNguL3RmwHVBC9FhGdlKrxdiJJigb/j/68SIy3Te4Bkz'
      }
    }.freeze

    # The files that the interface loads.
    #
    # Each entry has a +:href+ and an optional +:integrity+. Give your own URL to
    # serve the files from the host application. This is necessary for a network
    # without internet, and for a Content Security Policy that permits no other
    # origin. Remove the +:integrity+ value for a file that you serve yourself.
    #
    # @example Serve the files from the host application
    #   config.assets = {
    #     bootstrap_css:       { href: '/assets/bootstrap.css' },
    #     bootstrap_icons_css: { href: '/assets/bootstrap-icons.css' },
    #     bootstrap_js:        { href: '/assets/bootstrap.bundle.js' }
    #   }
    #
    # @return [Hash{Symbol => Hash}]
    attr_accessor :assets

    # Number of versions that the engine shows on one page.
    #
    # A version table of a production application can hold millions of rows.
    # The engine reads one page at a time, thus this value also limits the
    # memory that one request needs.
    #
    # @return [Integer]
    attr_accessor :page_limit

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
      @filter_attributes = nil
      @parameter_filter = nil
      @page_limit = DEFAULT_PAGE_LIMIT
      @assets = DEFAULT_ASSETS
    end

    # Attribute names whose values the engine must not show.
    #
    # The default is the list of the host application,
    # +Rails.application.config.filter_parameters+. Thus each attribute that
    # Rails keeps out of the log files also stays out of this interface. The
    # list accepts everything that +ActiveSupport::ParameterFilter+ accepts:
    # symbols, strings, regular expressions and procs.
    #
    # The engine reads the list of the host application one time. Change the
    # list in an initializer.
    #
    # @example Filter more attributes
    #   config.filter_attributes += [:internal_note, /_secret\z/]
    #
    # @return [Array]
    def filter_attributes
      @filter_attributes ||= Rails.application.config.filter_parameters
    end

    # Sets the attribute names whose values the engine must not show.
    #
    # @param value [Array]
    # @return [Array]
    def filter_attributes=(value)
      @parameter_filter = nil
      @filter_attributes = value
    end

    # Tells if the engine must hide the value of the given attribute.
    #
    # The method asks +ActiveSupport::ParameterFilter+ with a probe object. Thus
    # the engine hides exactly the attributes that Rails hides, also for a
    # regular expression or a proc in the list.
    #
    # @param name [String, Symbol] name of the attribute
    # @return [Boolean]
    def filtered_attribute?(name)
      probe = Object.new
      key = name.to_s

      !parameter_filter.filter(key => probe)[key].equal?(probe)
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

    def parameter_filter
      @parameter_filter ||= ActiveSupport::ParameterFilter.new(filter_attributes)
    end

    def custom_parent_controller?
      parent_controller.to_s != DEFAULT_PARENT_CONTROLLER
    end
  end
end
