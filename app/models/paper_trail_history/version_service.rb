# frozen_string_literal: true

module PaperTrailHistory
  # Service class for querying and managing PaperTrail version records
  class VersionService
    def self.for_model(model_name, params = {})
      trackable_model = TrackableModel.find(model_name)
      return PaperTrail::Version.none unless trackable_model

      versions = base_versions_for_model(trackable_model)
      apply_filters(versions, params).order(created_at: :desc)
    end

    def self.for_record(model_name, item_id, params = {})
      trackable_model = TrackableModel.find(model_name)
      return PaperTrail::Version.none unless trackable_model

      versions = base_versions_for_record(trackable_model, item_id)
      apply_record_filters(versions, params).order(created_at: :desc)
    end

    def self.find_version(version_id, model_name = nil)
      if model_name.present?
        # Direct query when model_name is known (fast)
        trackable_model = TrackableModel.find(model_name)
        return nil unless trackable_model

        trackable_model.version_class.unscoped.find_by(id: version_id)
      else
        # Fall back to searching across all tables (backwards compatible)
        find_version_across_tables(version_id)
      end
    end

    # Restores a record to the state of the given version.
    #
    # Give the version record itself whenever you have it. An ID alone is not
    # unique: an application with more than one version table (PaperTrail's
    # +versions+ plus a custom class such as +ProductVersion+) can hold the same
    # ID in each table, and a search by ID finds whichever table comes first.
    #
    # PaperTrail keeps the previous state of a record as YAML. Rails loads only
    # permitted classes from a YAML column, thus the host application has to list
    # the types that its models use in
    # +config.active_record.yaml_column_permitted_classes+. If a class is
    # missing, this method gives back an error that names the setting.
    #
    # @param version [ActiveRecord::Base, Integer, String] the version record, or
    #   its ID for backwards compatibility
    # @return [Hash] +:success+, and either +:item+ and +:message+ or +:error+
    def self.restore_version(version)
      version = find_version_across_tables(version) unless version.is_a?(ActiveRecord::Base)
      return validate_version_for_restore(version) unless version_restorable?(version)

      perform_version_restore(version)
    rescue Psych::DisallowedClass => e
      {
        success: false,
        error: I18n.t('paper_trail_history.errors.yaml_class_not_permitted', message: e.message)
      }
    rescue StandardError => e
      { success: false, error: e.message }
    end

    def self.unique_whodunnits(model_name = nil)
      distinct_column_values(:whodunnit, model_name)
    end

    def self.available_events(model_name = nil)
      distinct_column_values(:event, model_name)
    end

    # Collects the different values of one column for the filter lists.
    #
    # Each version class reads its own values with DISTINCT. The engine must not
    # load the rows, because a version table of a production application can hold
    # millions of them.
    #
    # @param column [Symbol] name of the column
    # @param model_name [String, nil] name of a trackable model, or nil for all
    # @return [Array<String>]
    def self.distinct_column_values(column, model_name)
      return all_distinct_column_values(column) unless model_name

      trackable_model = TrackableModel.find(model_name)
      return [] unless trackable_model

      trackable_model.versions.distinct.pluck(column).compact.sort
    end

    def self.all_distinct_column_values(column)
      all_version_classes.flat_map { |version_class| version_class.distinct.pluck(column) }
                         .compact.uniq.sort
    end

    def self.find_version_across_tables(version_id)
      # Try to find the version in all possible version classes, using unscoped to bypass any default scope
      # and/or soft delete mechanism like acts_as_paranoid
      all_version_classes.each do |version_class|
        version = version_class.unscoped.find_by(id: version_id)
        return version if version
      end
      nil
    end

    # Guards the cache. A Monitor is reentrant, thus the discovery can reach this
    # class again without a deadlock.
    LOCK = Monitor.new

    def self.all_version_classes
      @all_version_classes || LOCK.synchronize { @all_version_classes ||= discover_version_classes }
    end

    def self.discover_version_classes
      TrackableModel.all.map(&:version_class).uniq
    end

    # Clears the cached version classes. The engine calls this on each code
    # reload, because the cache holds class objects that a reload replaces.
    def self.clear_cache!
      LOCK.synchronize { @all_version_classes = nil }
    end

    def self.filter_by_event(versions, event)
      versions.where(event: event)
    end

    def self.filter_by_whodunnit(versions, whodunnit)
      versions.where(whodunnit: whodunnit)
    end

    def self.filter_by_date_range(versions, from_date, to_date)
      from = parse_date(from_date)
      to = parse_date(to_date)

      versions = versions.where(created_at: from..) if from
      versions = versions.where(created_at: ..to.end_of_day) if to
      versions
    end

    # Reads a date out of a URL parameter.
    #
    # The value comes from the user, thus it can be any text. An invalid value
    # gives +nil+, and the caller then does not use this part of the filter. A
    # wrong date must not stop the page with an error.
    #
    # @param value [String, nil]
    # @return [Date, nil]
    def self.parse_date(value)
      return nil if value.blank?

      Date.parse(value.to_s)
    rescue Date::Error
      nil
    end

    def self.search_object_changes(versions, search_term)
      versions.where('object_changes LIKE ? OR object LIKE ?', "%#{search_term}%", "%#{search_term}%")
    end

    def self.base_versions_for_model(trackable_model)
      trackable_model.versions
    end

    def self.apply_filters(versions, params)
      versions = filter_by_event(versions, params[:event]) if params[:event].present?
      versions = filter_by_whodunnit(versions, params[:whodunnit]) if params[:whodunnit].present?
      versions = apply_date_range_filter(versions, params) if date_range_params?(params)
      versions = search_object_changes(versions, params[:search]) if params[:search].present?
      versions
    end

    def self.apply_date_range_filter(versions, params)
      filter_by_date_range(versions, params[:from_date], params[:to_date])
    end

    def self.date_range_params?(params)
      params[:from_date].present? || params[:to_date].present?
    end

    def self.base_versions_for_record(trackable_model, item_id)
      trackable_model.versions.where(item_id: item_id)
    end

    def self.apply_record_filters(versions, params)
      versions = filter_by_event(versions, params[:event]) if params[:event].present?
      versions = apply_date_range_filter(versions, params) if date_range_params?(params)
      versions
    end

    def self.version_restorable?(version)
      version && version.event != 'create'
    end

    def self.validate_version_for_restore(version)
      return { success: false, error: I18n.t('paper_trail_history.errors.version_not_found') } unless version

      { success: false, error: I18n.t('paper_trail_history.errors.cannot_restore_create') }
    end

    def self.perform_version_restore(version)
      if version.event == 'destroy'
        restore_destroyed_record(version)
      else
        restore_previous_version(version)
      end
    end

    def self.restore_destroyed_record(version)
      restored_item = version.reify
      restored_item.save!
      { success: true, item: restored_item, message: I18n.t('paper_trail_history.messages.restore_from_deletion') }
    end

    def self.restore_previous_version(version)
      version.reify.save!
      { success: true, item: version.item, message: I18n.t('paper_trail_history.messages.restore_to_previous') }
    end
  end
end
