# frozen_string_literal: true

module PaperTrailHistory
  # Decorator for PaperTrail::Version objects providing formatted display methods
  class VersionDecorator
    attr_reader :version

    # Delegate common version methods to the underlying version object
    delegate :id, :event, :item_type, :item_id, :whodunnit, :object, :object_changes,
             :created_at, :updated_at, :item, :changeset, to: :version

    def initialize(version)
      @version = version
    end

    def self.decorate(version)
      return version if version.is_a?(VersionDecorator)

      new(version)
    end

    def self.decorate_collection(versions)
      versions.map { |version| decorate(version) }
    end

    def formatted_created_at
      format_time(version.created_at)
    end

    def event_label
      case version.event
      when 'create'
        I18n.t('paper_trail_history.events.created')
      when 'update'
        I18n.t('paper_trail_history.events.updated')
      when 'destroy'
        I18n.t('paper_trail_history.events.deleted')
      else
        version.event.humanize
      end
    end

    def event_class
      case version.event
      when 'create'
        'success'
      when 'update'
        'warning'
      when 'destroy'
        'danger'
      else
        'info'
      end
    end

    def whodunnit_display
      version.whodunnit || I18n.t('paper_trail_history.actors.system')
    end

    def changed_attributes
      return [] unless changeset

      changeset.map do |attr, (old_val, new_val)|
        build_change(attr, old_val, new_val)
      end
    end

    def can_restore?
      version.event != 'create'
    end

    def item_display_name
      return deleted_item_name unless version.item

      version.item.try(:name) || version.item.try(:title) || item_reference
    end

    private

    def item_reference
      "#{version.item_type} ##{version.item_id}"
    end

    def deleted_item_name
      I18n.t('paper_trail_history.display.deleted_item',
             item_type: version.item_type, item_id: version.item_id)
    end

    # Hides both values of an attribute that the host application filters. A
    # diff shows the old value and the new value, thus showing either of them
    # would expose the secret that the filter must protect.
    def build_change(attr, old_val, new_val)
      if PaperTrailHistory.config.filtered_attribute?(attr)
        filtered = I18n.t('paper_trail_history.display.filtered')
        return { attribute: attr, old_value: filtered, new_value: filtered }
      end

      {
        attribute: attr,
        old_value: format_value(old_val),
        new_value: format_value(new_val)
      }
    end

    def format_value(value)
      case value
      when nil then I18n.t('paper_trail_history.display.empty')
      when '' then I18n.t('paper_trail_history.display.blank')
      when Time then format_time(value)
      when Date then format_date(value)
      else value.to_s.truncate(100)
      end
    end

    # The format string comes from the locale, thus each language can order the
    # parts in its own way. I18n.l also translates the names of the months.
    def format_time(time)
      I18n.l(time, format: I18n.t('paper_trail_history.formats.datetime'))
    end

    def format_date(date)
      I18n.l(date, format: I18n.t('paper_trail_history.formats.date'))
    end
  end
end
