# frozen_string_literal: true

module PaperTrailHistory
  # Controller for managing version operations like viewing and restoring specific versions
  class VersionsController < ApplicationController
    before_action :find_version, only: %i[show restore]

    def show
      @decorated_version = VersionDecorator.decorate(@version)
      @trackable_model = TrackableModel.find(@version.item_type)
    end

    def restore
      result = VersionService.restore_version(@version.id)

      if result[:success]
        redirect_back_or_to(version_path(@version, model_name: @version.item_type), notice: result[:message])
      else
        redirect_back_or_to(version_path(@version, model_name: @version.item_type),
                            alert: t('paper_trail_history.errors.restore_failed', error: result[:error]))
      end
    end

    private

    def find_version
      @version = VersionService.find_version(params[:id], params[:model_name])

      return if @version

      redirect_to root_path, alert: t('paper_trail_history.errors.version_not_found')
    end
  end
end
