# frozen_string_literal: true

module PaperTrailHistory
  # Queries and restores PaperTrail versions for the interface.
  #
  # The class knows about applications with more than one version table: it
  # resolves the version class through {TrackableModel} instead of assuming
  # +PaperTrail::Version+.
  #
  # @example List the versions of a model with a filter
  #   PaperTrailHistory::VersionService.for_model('User', event: 'update')
  class VersionService
    # The longest search text that the engine sends to the database. A longer
    # text costs time and gives no better result.
    SEARCH_TERM_LIMIT = 100

    # Marks a wildcard of the user as a normal character. A backslash would need
    # its own escaping in each database, this character does not.
    SEARCH_ESCAPE_CHARACTER = '!'

    # The versions of one model, newest first.
    #
    # @param model_name [String] name of a trackable class
    # @param params [Hash] filter values, see {apply_filters}
    # @option params [String] :event only this event
    # @option params [String] :whodunnit only this person
    # @option params [String] :from_date only versions from this date
    # @option params [String] :to_date only versions up to this date
    # @option params [String] :search only versions whose stored data contain
    #   this text
    # @return [ActiveRecord::Relation] an empty relation for a model that does
    #   not exist or is not trackable
    def self.for_model(model_name, params = {})
      trackable_model = TrackableModel.find(model_name)
      return PaperTrail::Version.none unless trackable_model

      versions = base_versions_for_model(trackable_model)
      apply_filters(versions, params).order(created_at: :desc)
    end

    # The versions of one record, newest first.
    #
    # @param model_name [String] name of a trackable class
    # @param item_id [Integer, String] ID of the record
    # @param params [Hash] filter values. This list has no +:whodunnit+ and no
    #   +:search+, because the interface does not offer them for one record.
    # @option params [String] :event only this event
    # @option params [String] :from_date only versions from this date
    # @option params [String] :to_date only versions up to this date
    # @return [ActiveRecord::Relation]
    def self.for_record(model_name, item_id, params = {})
      trackable_model = TrackableModel.find(model_name)
      return PaperTrail::Version.none unless trackable_model

      versions = base_versions_for_record(trackable_model, item_id)
      apply_record_filters(versions, params).order(created_at: :desc)
    end

    # Finds one version.
    #
    # Give the model name whenever you have it. Without it the method looks in
    # every version table, and an ID is not unique over more than one table.
    #
    # @param version_id [Integer, String]
    # @param model_name [String, nil] name of the trackable class
    # @return [ActiveRecord::Base, nil]
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

    # The different people that appear in the versions.
    #
    # @param model_name [String, nil] one model, or nil for all models
    # @return [Array<String>] sorted, without duplicates
    def self.unique_whodunnits(model_name = nil)
      distinct_column_values(:whodunnit, model_name)
    end

    # The different events that appear in the versions.
    #
    # @param model_name [String, nil] one model, or nil for all models
    # @return [Array<String>] sorted, without duplicates
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

    # @api private
    # @param column [Symbol]
    # @return [Array<String>]
    def self.all_distinct_column_values(column)
      all_version_classes.flat_map { |version_class| version_class.distinct.pluck(column) }
                         .compact.uniq.sort
    end

    # Looks for a version in every version table.
    #
    # An ID is not unique over more than one table. Prefer {find_version} with a
    # model name.
    #
    # @param version_id [Integer, String]
    # @return [ActiveRecord::Base, nil]
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
    #
    # @api private
    LOCK = Monitor.new

    # Every version class that the application uses.
    #
    # The result comes from a cache. {clear_cache!} empties it.
    #
    # @return [Array<Class>]
    def self.all_version_classes
      @all_version_classes || LOCK.synchronize { @all_version_classes ||= discover_version_classes }
    end

    # @api private
    # @return [Array<Class>]
    def self.discover_version_classes
      TrackableModel.all.map(&:version_class).uniq
    end

    # Clears the cached version classes. The engine calls this on each code
    # reload, because the cache holds class objects that a reload replaces.
    def self.clear_cache!
      LOCK.synchronize { @all_version_classes = nil }
    end

    # @api private
    # @param versions [ActiveRecord::Relation]
    # @param event [String]
    # @return [ActiveRecord::Relation]
    def self.filter_by_event(versions, event)
      versions.where(event: event)
    end

    # @api private
    # @param versions [ActiveRecord::Relation]
    # @param whodunnit [String]
    # @return [ActiveRecord::Relation]
    def self.filter_by_whodunnit(versions, whodunnit)
      versions.where(whodunnit: whodunnit)
    end

    # Narrows the versions to a range of days. An invalid date is ignored.
    #
    # @api private
    # @param versions [ActiveRecord::Relation]
    # @param from_date [String, nil]
    # @param to_date [String, nil]
    # @return [ActiveRecord::Relation]
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

    # Searches the stored YAML of the versions.
    #
    # The query uses LIKE with the text in the middle, thus the database cannot
    # use an index and reads the whole table. On a large version table this
    # search is slow. The README says this.
    #
    # The wildcards of the user are escaped, thus a search for a percent sign
    # looks for that character and does not match every row.
    #
    # @api private
    # @param versions [ActiveRecord::Relation]
    # @param search_term [String]
    # @return [ActiveRecord::Relation]
    def self.search_object_changes(versions, search_term)
      term = ActiveRecord::Base.sanitize_sql_like(search_term.to_s.first(SEARCH_TERM_LIMIT), SEARCH_ESCAPE_CHARACTER)

      versions.where(
        "object_changes LIKE :pattern ESCAPE '#{SEARCH_ESCAPE_CHARACTER}' " \
        "OR object LIKE :pattern ESCAPE '#{SEARCH_ESCAPE_CHARACTER}'",
        pattern: "%#{term}%"
      )
    end

    # @api private
    # @param trackable_model [TrackableModel]
    # @return [ActiveRecord::Relation]
    def self.base_versions_for_model(trackable_model)
      trackable_model.versions
    end

    # Applies the filters of the interface, one after the other.
    #
    # @api private
    # @param versions [ActiveRecord::Relation]
    # @param params [Hash]
    # @return [ActiveRecord::Relation]
    def self.apply_filters(versions, params)
      versions = filter_by_event(versions, params[:event]) if params[:event].present?
      versions = filter_by_whodunnit(versions, params[:whodunnit]) if params[:whodunnit].present?
      versions = apply_date_range_filter(versions, params) if date_range_params?(params)
      versions = search_object_changes(versions, params[:search]) if params[:search].present?
      versions
    end

    # @api private
    # @param versions [ActiveRecord::Relation]
    # @param params [Hash]
    # @return [ActiveRecord::Relation]
    def self.apply_date_range_filter(versions, params)
      filter_by_date_range(versions, params[:from_date], params[:to_date])
    end

    # Tells if the caller gave any part of a date range.
    #
    # @api private
    # @param params [Hash]
    # @return [Boolean]
    def self.date_range_params?(params)
      params[:from_date].present? || params[:to_date].present?
    end

    # @api private
    # @param trackable_model [TrackableModel]
    # @param item_id [Integer, String]
    # @return [ActiveRecord::Relation]
    def self.base_versions_for_record(trackable_model, item_id)
      trackable_model.versions.where(item_id: item_id)
    end

    # @api private
    # @param versions [ActiveRecord::Relation]
    # @param params [Hash]
    # @return [ActiveRecord::Relation]
    def self.apply_record_filters(versions, params)
      versions = filter_by_event(versions, params[:event]) if params[:event].present?
      versions = apply_date_range_filter(versions, params) if date_range_params?(params)
      versions
    end

    # Tells if the engine can restore the given version.
    #
    # @api private
    # @param version [ActiveRecord::Base, nil]
    # @return [Boolean] false for nil and for the version that created the record
    def self.version_restorable?(version)
      version && version.event != 'create'
    end

    # @api private
    # @param version [ActiveRecord::Base, nil]
    # @return [Hash] a result that says why the restore is not possible
    def self.validate_version_for_restore(version)
      return { success: false, error: I18n.t('paper_trail_history.errors.version_not_found') } unless version

      { success: false, error: I18n.t('paper_trail_history.errors.cannot_restore_create') }
    end

    # @api private
    # @param version [ActiveRecord::Base]
    # @return [Hash]
    def self.perform_version_restore(version)
      if version.event == 'destroy'
        restore_destroyed_record(version)
      else
        restore_previous_version(version)
      end
    end

    # Writes a deleted record back into the database.
    #
    # @api private
    # @param version [ActiveRecord::Base]
    # @return [Hash]
    def self.restore_destroyed_record(version)
      restored_item = version.reify
      restored_item.save!
      { success: true, item: restored_item, message: I18n.t('paper_trail_history.messages.restore_from_deletion') }
    end

    # Sets a record back to the state before this version.
    #
    # @api private
    # @param version [ActiveRecord::Base]
    # @return [Hash]
    def self.restore_previous_version(version)
      version.reify.save!
      { success: true, item: version.item, message: I18n.t('paper_trail_history.messages.restore_to_previous') }
    end

    # The methods above this line are the API of the class. Everything below is
    # internal and can change without notice.
    private_class_method :all_distinct_column_values
    private_class_method :find_version_across_tables
    private_class_method :discover_version_classes
    private_class_method :filter_by_event
    private_class_method :filter_by_whodunnit
    private_class_method :filter_by_date_range
    private_class_method :parse_date
    private_class_method :search_object_changes
    private_class_method :base_versions_for_model
    private_class_method :apply_filters
    private_class_method :apply_date_range_filter
    private_class_method :date_range_params?
    private_class_method :base_versions_for_record
    private_class_method :apply_record_filters
    private_class_method :version_restorable?
    private_class_method :validate_version_for_restore
    private_class_method :perform_version_restore
    private_class_method :restore_destroyed_record
    private_class_method :restore_previous_version
    private_class_method :distinct_column_values
  end
end
