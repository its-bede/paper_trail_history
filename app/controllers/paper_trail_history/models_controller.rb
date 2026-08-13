# frozen_string_literal: true

module PaperTrailHistory
  # Controller for managing trackable model operations and displaying version histories
  class ModelsController < ApplicationController
    def index
      @trackable_models = TrackableModel.all_with_counts
    end

    def show
      @trackable_model = find_trackable_model_or_redirect(params[:name])
      return unless @trackable_model

      @recent_versions = VersionDecorator.decorate_collection(
        @trackable_model.recent_versions(20)
      )
    end

    def versions
      @trackable_model = find_trackable_model_or_redirect(params[:name])
      return unless @trackable_model

      load_versions_data
      load_filter_options
    end

    private

    def load_versions_data
      @versions = VersionService.for_model(params[:name], filter_params).includes(:item)
      @pagy, @decorated_versions = paginate_versions(@versions)
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
