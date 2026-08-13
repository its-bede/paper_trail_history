# frozen_string_literal: true

module PaperTrailHistory
  # Prepares one PaperTrail version for the interface: translated labels, dates
  # in the format of the current language, and a list of changed attributes that
  # hides the values which the host application filters.
  #
  # The decorator passes the usual reader methods of a version through, thus it
  # can stand in the place of the version itself in a view.
  #
  # @example
  #   decorated = PaperTrailHistory::VersionDecorator.decorate(version)
  #   decorated.event_label    # => "Updated"
  #   decorated.changed_attributes
  #   # => [{ attribute: 'name', old_value: 'old', new_value: 'new' }]
  class VersionDecorator
    # @return [ActiveRecord::Base] the version that this object decorates
    attr_reader :version

    # @!method id
    #   @return [Integer]
    # @!method event
    #   @return [String] +'create'+, +'update'+ or +'destroy'+
    # @!method item_type
    #   @return [String]
    # @!method item_id
    #   @return [Integer]
    # @!method whodunnit
    #   @return [String, nil]
    # @!method object
    #   @return [String, nil] the state before the change, as YAML
    # @!method object_changes
    #   @return [String, nil] the change, as YAML
    # @!method created_at
    #   @return [ActiveSupport::TimeWithZone]
    # @!method updated_at
    #   @return [ActiveSupport::TimeWithZone, nil]
    # @!method item
    #   @return [ActiveRecord::Base, nil] nil when the record is deleted
    # @!method changeset
    #   @return [Hash] attribute name to a pair of old and new value
    delegate :id, :event, :item_type, :item_id, :whodunnit, :object, :object_changes,
             :created_at, :updated_at, :item, :changeset, to: :version

    # @param version [ActiveRecord::Base] a PaperTrail version
    def initialize(version)
      @version = version
    end

    # Decorates a version. A version that is already decorated stays as it is.
    #
    # @param version [ActiveRecord::Base, VersionDecorator]
    # @return [VersionDecorator]
    def self.decorate(version)
      return version if version.is_a?(VersionDecorator)

      new(version)
    end

    # Decorates each version of a collection.
    #
    # @param versions [Enumerable]
    # @return [Array<VersionDecorator>]
    def self.decorate_collection(versions)
      versions.map { |version| decorate(version) }
    end

    # The time of the version in the format of the current language.
    #
    # @return [String]
    def formatted_created_at
      format_time(version.created_at)
    end

    # The name of the event in the current language.
    #
    # @return [String] the translated name, or the event itself for an event
    #   that this engine does not know
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

    # The Bootstrap suffix for the colour of the event.
    #
    # @return [String] +'success'+, +'warning'+, +'danger'+ or +'info'+
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

    # The person who made the change.
    #
    # @return [String] the whodunnit value, or the word for the system when
    #   PaperTrail stored no value
    def whodunnit_display
      version.whodunnit || I18n.t('paper_trail_history.actors.system')
    end

    # The attributes that this version changed.
    #
    # An attribute that the host application filters gets a placeholder for both
    # values, thus a password digest or an API token does not appear.
    #
    # @return [Array<Hash>] each entry has +:attribute+, +:old_value+ and
    #   +:new_value+
    def changed_attributes
      return [] unless changeset

      changeset.map do |attr, (old_val, new_val)|
        build_change(attr, old_val, new_val)
      end
    end

    # Tells if the engine can restore this version.
    #
    # @return [Boolean] false for the version that created the record
    def can_restore?
      version.event != 'create'
    end

    # A name for the record of this version.
    #
    # The method takes the name or the title of the record when it has one, and
    # falls back to the type and the ID.
    #
    # @return [String]
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
