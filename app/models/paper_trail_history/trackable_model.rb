# frozen_string_literal: true

module PaperTrailHistory
  # Model wrapper for trackable ActiveRecord classes with PaperTrail versioning
  class TrackableModel
    attr_reader :name, :klass, :cached_version_count

    def initialize(klass, cached_version_count = nil)
      @klass = klass
      @name = klass.name
      @cached_version_count = cached_version_count
    end

    # Guards the cache. A Monitor is reentrant, thus the discovery can reach this
    # class again without a deadlock.
    LOCK = Monitor.new

    def self.all
      @all_models || LOCK.synchronize { @all_models ||= discover_all }
    end

    def self.discover_all
      Rails.application.eager_load!

      # Only keep one instance per class name to avoid duplicates
      trackable_classes = {}
      ObjectSpace.each_object(Class) do |klass|
        next unless klass < ActiveRecord::Base
        next if klass.abstract_class?
        next unless klass.included_modules.include?(PaperTrail::Model::InstanceMethods)

        trackable_classes[klass.name] = new(klass)
      end

      trackable_classes.values.sort_by(&:name)
    end

    def self.all_with_counts
      models = all
      return models if models.empty?

      count_cache = build_count_cache(models)
      models_with_cached_counts(models, count_cache)
    end

    def self.build_count_cache(models)
      models_by_version_class = models.group_by(&:version_class)
      count_cache = {}
      populate_count_cache(models_by_version_class, count_cache)
      count_cache
    end

    def self.populate_count_cache(models_by_version_class, count_cache)
      models_by_version_class.each do |version_class, models_for_class|
        counts = fetch_version_counts(version_class, models_for_class)
        cache_counts_for_models(models_for_class, counts, count_cache)
      end
    end

    def self.fetch_version_counts(version_class, models_for_class)
      item_types = models_for_class.map(&:item_type_for_versions)
      version_class.where(item_type: item_types).group(:item_type).count
    end

    # The grouped count uses item_type, thus it cannot separate the subclasses of
    # a single table inheritance. A subclass counts its own versions.
    def self.cache_counts_for_models(models_for_class, counts, count_cache)
      models_for_class.each do |model|
        count_cache[model.name] = if model.sti_subclass?
                                    model.versions.count
                                  else
                                    counts[model.item_type_for_versions] || 0
                                  end
      end
    end

    def self.models_with_cached_counts(models, count_cache)
      models.map { |model| new(model.klass, count_cache[model.name]) }
    end

    def self.find(model_name)
      all.find { |model| model.name == model_name }
    end

    # Clears the cached models. The engine calls this on each code reload,
    # because the cache holds class objects that a reload replaces.
    def self.clear_cache!
      LOCK.synchronize { @all_models = nil }
    end

    # The versions of this model.
    #
    # PaperTrail writes the name of the base class into item_type, thus a query
    # by the name of a subclass finds nothing. The engine asks for the base class
    # and narrows the result with item_subtype, which PaperTrail fills when the
    # version table has that column. A version table without item_subtype cannot
    # tell the subclasses apart, thus a subclass then shows the versions of its
    # base class.
    def versions
      scope = version_class.where(item_type: item_type_for_versions)
      return scope unless sti_subclass? && item_subtype_available?

      scope.where(item_subtype: klass.name)
    end

    def item_type_for_versions
      klass.base_class.name
    end

    # Tells if this model is a single table inheritance subclass.
    def sti_subclass?
      klass != klass.base_class
    end

    def item_subtype_available?
      version_class.column_names.include?('item_subtype')
    end

    def total_versions_count
      # Use cached count if available (from all_with_counts), otherwise query
      @cached_version_count || versions.count
    end

    # The list of recent versions shows the name of the item of each version.
    # Without the preload, each row makes its own query.
    def recent_versions(limit = 10)
      versions.includes(:item).order(created_at: :desc).limit(limit)
    end

    def version_class
      @version_class ||= klass.paper_trail.version_class || PaperTrail::Version
    end

    def version_table_name
      version_class.table_name
    end

    delegate :table_name, to: :klass

    def human_name
      klass.model_name.human(count: 2)
    end
  end
end
