# frozen_string_literal: true

module PaperTrailHistory
  # Controller for managing trackable model operations and displaying version histories
  class ModelsController < ApplicationController
    def index
      @trackable_models = TrackableModel.all_with_counts
    end

    def show
      @trackable_model = TrackableModel.find(params[:name])

      unless @trackable_model
        redirect_to models_path, alert: t('paper_trail_history.errors.model_not_found', model_name: params[:name])
        return
      end

      @recent_versions = VersionDecorator.decorate_collection(
        @trackable_model.recent_versions(20)
      )
    end

    def versions
      @trackable_model = find_trackable_model_or_redirect
      return unless @trackable_model

      load_versions_data
      load_filter_options
    end

    private

    def find_trackable_model_or_redirect
      trackable_model = TrackableModel.find(params[:name])
      unless trackable_model
        redirect_to models_path, alert: t('paper_trail_history.errors.model_not_found', model_name: params[:name])
        return nil
      end
      trackable_model
    end

    def load_versions_data
      @versions = VersionService.for_model(params[:name], filter_params)
      @versions = @versions.includes(:item)
      @decorated_versions = VersionDecorator.decorate_collection(@versions)
    end

    def load_filter_options
      @available_events = VersionService.available_events(params[:name])
      @available_whodunnits = VersionService.unique_whodunnits(params[:name])
    end

    def filter_params
      params.permit(:event, :whodunnit, :from_date, :to_date, :search, :page)
    end
  end
end
