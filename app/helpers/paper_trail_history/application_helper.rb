# frozen_string_literal: true

module PaperTrailHistory
  # Helper module providing utility methods for PaperTrailHistory views
  module ApplicationHelper
    # Generate version path with model_name context when available
    def version_link_path(version, options = {})
      model_name = options[:model_name] || version.item_type
      version_path(version.id, model_name: model_name)
    end

    # Generate restore version path with model_name context
    def restore_version_link_path(version, options = {})
      model_name = options[:model_name] || version.item_type
      restore_version_path(version.id, model_name: model_name)
    end
  end
end
