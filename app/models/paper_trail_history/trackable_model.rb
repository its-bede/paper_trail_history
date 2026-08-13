# frozen_string_literal: true

module PaperTrailHistory
  # Wraps an ActiveRecord class that uses PaperTrail and answers the questions
  # that the interface asks about it: which version class holds its versions, how
  # many versions exist, and which of them are the newest.
  #
  # The list of trackable classes is expensive to build, thus the class caches
  # it. {clear_cache!} empties the cache, and the engine calls that method on
  # each code reload.
  #
  # @example Read the versions of one model
  #   trackable = PaperTrailHistory::TrackableModel.find('User')
  #   trackable.total_versions_count # => 1234
  #   trackable.recent_versions(5)   # => the five newest versions
  class TrackableModel
    # Guards the cache. A Monitor is reentrant, thus the discovery can reach this
    # class again without a deadlock.
    #
    # @api private
    LOCK = Monitor.new

    # @return [String] name of the wrapped class
    # @return [Class] the wrapped ActiveRecord class
    # @return [Integer, nil] version count from a bulk count, or nil
    attr_reader :name, :klass, :cached_version_count

    # @param klass [Class] an ActiveRecord class that uses +has_paper_trail+
    # @param cached_version_count [Integer, nil] a count that {all_with_counts}
    #   read for every model at once
    def initialize(klass, cached_version_count = nil)
      @klass = klass
      @name = klass.name
      @cached_version_count = cached_version_count
    end

    # All classes of the application that use PaperTrail, sorted by name.
    #
    # The result comes from the cache after the first call.
    #
    # @return [Array<TrackableModel>]
    def self.all
      @all_models || LOCK.synchronize { @all_models ||= discover_all }
    end

    # Searches the application for classes that use PaperTrail.
    #
    # The search asks ActiveRecord for its descendants. It does not walk through
    # every object of the process, because that is slow and it also finds classes
    # that Rails removed at a code reload.
    #
    # The eager load is necessary: Rails loads a class only when the code asks
    # for it, thus a model that no request touched yet is not a descendant. The
    # engine calls the discovery one time for each code reload, thus the cost
    # happens one time and not on each request.
    #
    # @api private
    # @return [Array<TrackableModel>]
    def self.discover_all
      Rails.application.eager_load!

      # Only keep one instance per class name to avoid duplicates
      trackable_classes = {}
      ActiveRecord::Base.descendants.each do |klass|
        next if klass.name.nil? # an anonymous class has no name to show
        next if klass.abstract_class?
        next unless klass.included_modules.include?(PaperTrail::Model::InstanceMethods)

        trackable_classes[klass.name] = new(klass)
      end

      trackable_classes.values.sort_by(&:name)
    end

    # All trackable models, each one with its version count.
    #
    # The counts come from one query for each version table. Use this method for
    # a list of models, because {#total_versions_count} on each model alone makes
    # one query for each model.
    #
    # @return [Array<TrackableModel>]
    def self.all_with_counts
      models = all
      return models if models.empty?

      count_cache = build_count_cache(models)
      models_with_cached_counts(models, count_cache)
    end

    # @api private
    # @param models [Array<TrackableModel>]
    # @return [Hash{String => Integer}] count for each model name
    def self.build_count_cache(models)
      models_by_version_class = models.group_by(&:version_class)
      count_cache = {}
      populate_count_cache(models_by_version_class, count_cache)
      count_cache
    end

    # @api private
    # @param models_by_version_class [Hash{Class => Array<TrackableModel>}]
    # @param count_cache [Hash{String => Integer}] gets the counts
    # @return [void]
    def self.populate_count_cache(models_by_version_class, count_cache)
      models_by_version_class.each do |version_class, models_for_class|
        counts = fetch_version_counts(version_class, models_for_class)
        cache_counts_for_models(models_for_class, counts, count_cache)
      end
    end

    # Counts the versions of a version table with one query.
    #
    # The query also groups by item_subtype when the table has that column, thus
    # a subclass of a single table inheritance does not need its own query. One
    # query for each version table is the whole cost.
    #
    # @api private
    # @param version_class [Class] a PaperTrail version class
    # @param models_for_class [Array<TrackableModel>]
    # @return [Hash] count for each item type, or for each pair of item type and
    #   item subtype
    def self.fetch_version_counts(version_class, models_for_class)
      item_types = models_for_class.map(&:item_type_for_versions)
      scope = version_class.where(item_type: item_types)
      return scope.group(:item_type).count unless version_class.column_names.include?('item_subtype')

      scope.group(:item_type, :item_subtype).count
    end

    # @api private
    # @param models_for_class [Array<TrackableModel>]
    # @param counts [Hash]
    # @param count_cache [Hash{String => Integer}] gets the counts
    # @return [void]
    def self.cache_counts_for_models(models_for_class, counts, count_cache)
      models_for_class.each do |model|
        count_cache[model.name] = count_for(model, counts)
      end
    end

    # Reads the count of one model out of the grouped result.
    #
    # A subclass counts only the rows of its own subtype. A base class counts all
    # of its rows, thus the rows of its subclasses belong to it. This is the same
    # rule that ActiveRecord uses for a query on the base class.
    #
    # @api private
    # @param model [TrackableModel]
    # @param counts [Hash]
    # @return [Integer]
    def self.count_for(model, counts)
      return counts[model.item_type_for_versions].to_i unless counts.keys.first.is_a?(Array)
      return counts.fetch([model.item_type_for_versions, model.name], 0) if model.sti_subclass?

      counts.sum { |(item_type, _subtype), count| item_type == model.item_type_for_versions ? count : 0 }
    end

    # @api private
    # @param models [Array<TrackableModel>]
    # @param count_cache [Hash{String => Integer}]
    # @return [Array<TrackableModel>] new wrappers that hold their count
    def self.models_with_cached_counts(models, count_cache)
      models.map { |model| new(model.klass, count_cache[model.name]) }
    end

    # Finds a trackable model by class name.
    #
    # @param model_name [String] name of the class, for example +'User'+
    # @return [TrackableModel, nil] nil if the class does not exist or does not
    #   use PaperTrail
    def self.find(model_name)
      all.find { |model| model.name == model_name }
    end

    # Clears the cached models. The engine calls this on each code reload,
    # because the cache holds class objects that a reload replaces.
    #
    # @return [void]
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
    #
    # @return [ActiveRecord::Relation]
    def versions
      scope = version_class.where(item_type: item_type_for_versions)
      return scope unless sti_subclass? && item_subtype_available?

      scope.where(item_subtype: klass.name)
    end

    # The value that PaperTrail writes into the item_type column for this model.
    #
    # @return [String] name of the base class
    def item_type_for_versions
      klass.base_class.name
    end

    # Tells if this model is a single table inheritance subclass.
    #
    # @return [Boolean]
    def sti_subclass?
      klass != klass.base_class
    end

    # Tells if the version table can separate the subclasses.
    #
    # @return [Boolean] true if the version table has an item_subtype column
    def item_subtype_available?
      version_class.column_names.include?('item_subtype')
    end

    # The number of versions of this model.
    #
    # The method uses the count of {all_with_counts} if it has one, otherwise it
    # makes a query.
    #
    # @return [Integer]
    def total_versions_count
      @cached_version_count || versions.count
    end

    # The newest versions of this model.
    #
    # The list of recent versions shows the name of the item of each version.
    # Without the preload, each row makes its own query.
    #
    # @param limit [Integer] how many versions
    # @return [ActiveRecord::Relation]
    def recent_versions(limit = 10)
      versions.includes(:item).order(created_at: :desc).limit(limit)
    end

    # The class that holds the versions of this model.
    #
    # A model can keep its versions in its own table with
    # +has_paper_trail versions: { class_name: 'ProductVersion' }+.
    #
    # @return [Class]
    def version_class
      @version_class ||= klass.paper_trail.version_class || PaperTrail::Version
    end

    # @return [String] name of the table that holds the versions
    def version_table_name
      version_class.table_name
    end

    # @!method table_name
    #   @return [String] name of the table of the wrapped class
    delegate :table_name, to: :klass

    # The name of the model for a person, in plural and in the current language.
    #
    # @return [String]
    def human_name
      klass.model_name.human(count: 2)
    end
  end
end
