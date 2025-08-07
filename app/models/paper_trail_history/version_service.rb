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

    def self.restore_version(version_id)
      version = find_version_across_tables(version_id)
      return validate_version_for_restore(version) unless version_restorable?(version)

      perform_version_restore(version)
    rescue StandardError => e
      { success: false, error: e.message }
    end

    def self.unique_whodunnits(model_name = nil)
      if model_name
        trackable_model = TrackableModel.find(model_name)
        return [] unless trackable_model

        scope = trackable_model.version_class.where(item_type: trackable_model.item_type_for_versions)
      else
        scope = all_version_classes.flat_map(&:all)
        return scope.map(&:whodunnit).compact.uniq.sort
      end

      scope.distinct.pluck(:whodunnit).compact.sort
    end

    def self.available_events(model_name = nil)
      if model_name
        trackable_model = TrackableModel.find(model_name)
        return [] unless trackable_model

        scope = trackable_model.version_class.where(item_type: trackable_model.item_type_for_versions)
      else
        scope = all_version_classes.flat_map(&:all)
        return scope.map(&:event).compact.uniq.sort
      end

      scope.distinct.pluck(:event).compact.sort
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

    def self.all_version_classes
      @all_version_classes ||= begin
        classes = Set.new
        TrackableModel.all.each do |trackable_model|
          classes.add(trackable_model.version_class)
        end
        classes.to_a
      end
    end

    def self.filter_by_event(versions, event)
      versions.where(event: event)
    end

    def self.filter_by_whodunnit(versions, whodunnit)
      versions.where(whodunnit: whodunnit)
    end

    def self.filter_by_date_range(versions, from_date, to_date)
      versions = versions.where(created_at: Date.parse(from_date)..) if from_date.present?
      versions = versions.where(created_at: ..Date.parse(to_date).end_of_day) if to_date.present?
      versions
    end

    def self.search_object_changes(versions, search_term)
      versions.where('object_changes LIKE ? OR object LIKE ?', "%#{search_term}%", "%#{search_term}%")
    end

    def self.base_versions_for_model(trackable_model)
      trackable_model.version_class.where(item_type: trackable_model.item_type_for_versions)
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
      trackable_model.version_class.where(
        item_type: trackable_model.item_type_for_versions,
        item_id: item_id
      )
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
