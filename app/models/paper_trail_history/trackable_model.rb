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

    def self.all
      return @all_models if defined?(@all_models) && @all_models

      Rails.application.eager_load!

      # Use a Set to ensure uniqueness by class name
      trackable_classes = {}
      ObjectSpace.each_object(Class) do |klass|
        next unless klass < ActiveRecord::Base
        next if klass.abstract_class?
        next unless klass.included_modules.include?(PaperTrail::Model::InstanceMethods)

        # Only keep one instance per class name to avoid duplicates
        trackable_classes[klass.name] = new(klass)
      end

      @all_models = trackable_classes.values.sort_by(&:name)
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

    def self.cache_counts_for_models(models_for_class, counts, count_cache)
      models_for_class.each do |model|
        count_cache[model.name] = counts[model.item_type_for_versions] || 0
      end
    end

    def self.models_with_cached_counts(models, count_cache)
      models.map { |model| new(model.klass, count_cache[model.name]) }
    end

    def self.find(model_name)
      all.find { |model| model.name == model_name }
    end

    # Clear cached models (useful in development when adding new trackable models)
    def self.clear_cache!
      @all_models = nil
    end

    def versions
      version_class.where(item_type: item_type_for_versions)
    end

    def item_type_for_versions
      # PaperTrail stores item_type as the class name, but let's be explicit
      # and handle potential namespace issues
      klass.name
    end

    def total_versions_count
      # Use cached count if available (from all_with_counts), otherwise query
      @cached_version_count || versions.count
    end

    def recent_versions(limit = 10)
      versions.order(created_at: :desc).limit(limit)
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
