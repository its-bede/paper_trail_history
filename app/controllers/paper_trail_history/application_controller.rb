# frozen_string_literal: true

module PaperTrailHistory
  # Base controller of the engine. It applies the access rules that the host
  # application sets with PaperTrailHistory.configure.
  class ApplicationController < PaperTrailHistory.config.parent_controller_class
    include Pagy::Method

    # The engine keeps its own layout, also when it descends from a controller
    # of the host application that declares a different one.
    layout 'paper_trail_history/application'

    before_action :require_configured_access
    before_action :run_authentication_callback

    class << self
      # Writes the warning about unconfigured access one time for each process.
      def warn_about_unconfigured_access
        return if @unconfigured_access_warned

        @unconfigured_access_warned = true
        Rails.logger.warn(
          '[paper_trail_history] The engine runs without access control. It shows the full audit trail ' \
          'and can overwrite records. Set config.authenticate_with or config.parent_controller in an ' \
          'initializer before you deploy. See the README for details.'
        )
      end
    end

    private

    # Finds the trackable model of the request, or redirects.
    #
    # The name of the parameter differs between the controllers, thus the caller
    # gives the value.
    #
    # @param model_name [String] value of the parameter that names the model
    # @return [TrackableModel, nil] nil after a redirect
    def find_trackable_model_or_redirect(model_name)
      trackable_model = TrackableModel.find(model_name)
      return trackable_model if trackable_model

      redirect_to models_path, alert: t('paper_trail_history.errors.model_not_found', model_name: model_name)
      nil
    end

    # Reads one page of the given versions and decorates only that page.
    #
    # The engine passes the limit for each call instead of writing it into
    # Pagy::OPTIONS, because Pagy::OPTIONS is global and belongs to the host
    # application.
    def paginate_versions(versions)
      pagy, page_of_versions = pagy(:offset, versions, limit: PaperTrailHistory.config.page_limit)

      [pagy, VersionDecorator.decorate_collection(page_of_versions)]
    end

    def require_configured_access
      return if PaperTrailHistory.config.access_configured?

      unless PaperTrailHistory.config.enforce_access_control?
        self.class.warn_about_unconfigured_access
        return
      end

      render plain: t('paper_trail_history.errors.access_not_configured'), status: :forbidden
    end

    def run_authentication_callback
      callback = PaperTrailHistory.config.authenticate_with
      return if callback.nil?

      instance_exec(&callback)
    end

    def authorize_restore
      callback = PaperTrailHistory.config.authorize_restore_with
      return if callback.nil?
      return if instance_exec(&callback)

      redirect_back_or_to(root_path, alert: t('paper_trail_history.errors.restore_not_allowed'))
    end
  end
end
