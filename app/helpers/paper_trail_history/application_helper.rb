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

    # Gives the nonce of the Content Security Policy, or nil.
    #
    # An empty nonce attribute is not useful: the browser refuses it and writes
    # an error. The engine writes no attribute if the host application makes no
    # nonce.
    #
    # @return [String, nil]
    def engine_csp_nonce
      content_security_policy_nonce.presence
    end

    # Makes the link tag for one of the stylesheets of the interface.
    #
    # The tag carries the integrity value, and a nonce when the host application
    # uses a Content Security Policy with nonces. A policy that permits no other
    # origin thus still works, if the host application serves the file itself.
    #
    # @param name [Symbol] key in the assets configuration
    # @return [ActiveSupport::SafeBuffer]
    def engine_stylesheet_tag(name)
      asset = PaperTrailHistory.config.assets.fetch(name)

      tag.link(rel: 'stylesheet', href: asset[:href], **asset_integrity_options(asset))
    end

    # Makes the script tag for one of the scripts of the interface.
    #
    # @param name [Symbol] key in the assets configuration
    # @return [ActiveSupport::SafeBuffer]
    def engine_javascript_tag(name)
      asset = PaperTrailHistory.config.assets.fetch(name)

      content_tag(:script, '', src: asset[:href], **asset_integrity_options(asset))
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

    private

    # A file of another origin needs crossorigin together with integrity, else
    # the browser cannot check the value. A file without an integrity value gets
    # neither of the two attributes.
    def asset_integrity_options(asset)
      options = { nonce: engine_csp_nonce }
      return options if asset[:integrity].blank?

      options.merge(integrity: asset[:integrity], crossorigin: 'anonymous')
    end
  end
end
