# frozen_string_literal: true

module PaperTrailHistory
  # Controller for managing individual record operations and their version histories
  class RecordsController < ApplicationController
    def show
      @trackable_model = find_trackable_model_or_redirect
      return unless @trackable_model

      load_record_data
      load_recent_versions
    end

    def versions
      @trackable_model = find_trackable_model_or_redirect
      return unless @trackable_model

      load_record_data
      load_versions_with_filters
      load_available_events
    end

    private

    def find_trackable_model_or_redirect
      trackable_model = TrackableModel.find(params[:model_name])
      unless trackable_model
        redirect_to models_path, alert: t('paper_trail_history.errors.model_not_found', model_name: params[:model_name])
        return nil
      end
      trackable_model
    end

    def load_record_data
      @record = @trackable_model.klass.find_by(id: params[:record_id])
      @record_id = params[:record_id]
    end

    def load_recent_versions
      @recent_versions = VersionDecorator.decorate_collection(
        VersionService.for_record(params[:model_name], params[:record_id], {}).limit(10)
      )
    end

    def load_versions_with_filters
      @versions = VersionService.for_record(params[:model_name], params[:record_id], filter_params)
      @decorated_versions = VersionDecorator.decorate_collection(@versions)
    end

    def load_available_events
      @available_events = VersionService.available_events(params[:model_name])
    end

    def filter_params
      params.permit(:event, :from_date, :to_date, :page)
    end
  end
end
