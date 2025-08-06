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
        redirect_back fallback_location: version_path(@version),
                      notice: result[:message]
      else
        redirect_back fallback_location: version_path(@version),
                      alert: t('paper_trail_history.errors.restore_failed', error: result[:error])
      end
    end

    private

    def find_version
      @version = PaperTrail::Version.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to root_path, alert: t('paper_trail_history.errors.version_not_found')
    end
  end
end
