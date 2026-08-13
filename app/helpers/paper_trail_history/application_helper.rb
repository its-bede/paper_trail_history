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

    # Gives the attributes of a record for the interface. The value of an
    # attribute that the host application filters becomes a placeholder, thus a
    # password digest or an API token does not appear on the page.
    #
    # @param record [ActiveRecord::Base]
    # @return [Array<Array(String, Object)>] pairs of name and value
    def displayed_attributes(record)
      record.attributes.map do |name, value|
        next [name, t('paper_trail_history.display.filtered')] if PaperTrailHistory.config.filtered_attribute?(name)

        [name, value]
      end
    end
  end
end
