# frozen_string_literal: true

require 'test_helper'

module PaperTrailHistory
  # Makes sure that each language has the same keys. Without this test, a new
  # text reaches only the English file and the German interface shows the key.
  class LocalesTest < ActiveSupport::TestCase
    LOCALES = %i[en de].freeze

    test 'gives the same keys in every language' do
      reference = keys_of(:en)

      LOCALES.each do |locale|
        assert_equal reference, keys_of(locale), "the keys of #{locale} differ from the keys of en"
      end
    end

    test 'gives a text for every key in every language' do
      LOCALES.each do |locale|
        empty = flatten(load_locale(locale)).select { |_key, value| value.to_s.strip.empty? }

        assert_empty empty.keys, "#{locale} has keys without a text"
      end
    end

    test 'uses the same interpolation names in every language' do
      reference = interpolations_of(:en)

      LOCALES.each do |locale|
        assert_equal reference, interpolations_of(locale),
                     "the interpolations of #{locale} differ from the interpolations of en"
      end
    end

    private

    def keys_of(locale)
      flatten(load_locale(locale)).keys.sort
    end

    def interpolations_of(locale)
      flatten(load_locale(locale)).transform_values { |value| value.to_s.scan(/%\{(\w+)\}/).flatten.sort }
                                  .reject { |_key, names| names.empty? }
    end

    def load_locale(locale)
      YAML.load_file(Engine.root.join('config', 'locales', "#{locale}.yml")).fetch(locale.to_s)
    end

    def flatten(hash, prefix = nil)
      hash.each_with_object({}) do |(key, value), result|
        path = [prefix, key].compact.join('.')

        if value.is_a?(Hash)
          result.merge!(flatten(value, path))
        else
          result[path] = value
        end
      end
    end
  end
end
