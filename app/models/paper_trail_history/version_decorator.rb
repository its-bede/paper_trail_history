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
      version.created_at.strftime('%B %d, %Y at %I:%M %p')
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
        {
          attribute: attr,
          old_value: format_value(old_val),
          new_value: format_value(new_val)
        }
      end
    end

    def can_restore?
      version.event != 'create'
    end

    def item_display_name
      if version.item
        version.item.try(:name) || version.item.try(:title) || "#{version.item_type} ##{version.item_id}"
      else
        "#{version.item_type} ##{version.item_id} (deleted)"
      end
    end

    private

    def format_value(value)
      case value
      when nil then '(empty)'
      when '' then '(blank)'
      when Time then format_time(value)
      when Date then format_date(value)
      else value.to_s.truncate(100)
      end
    end

    def format_time(time)
      time.strftime('%B %d, %Y at %I:%M %p')
    end

    def format_date(date)
      date.strftime('%B %d, %Y')
    end
  end
end
