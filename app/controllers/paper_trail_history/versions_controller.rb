# frozen_string_literal: true

module PaperTrailHistory
  # Controller for managing version operations like viewing and restoring specific versions
  class VersionsController < ApplicationController
    before_action :authorize_restore, only: :restore
    before_action :find_version, only: %i[show restore]

    def show
      @trackable_model = TrackableModel.find(@version.item_type)
      return redirect_to_missing_model unless @trackable_model

      @decorated_version = VersionDecorator.decorate(@version)
    end

    def restore
      result = VersionService.restore_version(@version)

      if result[:success]
        redirect_back_or_to(version_path(@version, model_name: @version.item_type), notice: result[:message])
      else
        redirect_back_or_to(version_path(@version, model_name: @version.item_type),
                            alert: t('paper_trail_history.errors.restore_failed', error: result[:error]))
      end
    end

    private

    # The version keeps the name of its model as text. An application that
    # renames or deletes a model keeps versions that point to a name which is not
    # trackable now. The page must not fail with an error in this case.
    def redirect_to_missing_model
      redirect_to models_path,
                  alert: t('paper_trail_history.errors.model_not_found', model_name: @version.item_type)
    end

    def find_version
      @version = VersionService.find_version(params[:id], params[:model_name])

      return if @version

      redirect_to root_path, alert: t('paper_trail_history.errors.version_not_found')
    end
  end
end
