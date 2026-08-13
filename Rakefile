# frozen_string_literal: true

require 'bundler/setup'

APP_RAKEFILE = File.expand_path('test/dummy/Rakefile', __dir__)
load 'rails/tasks/engine.rake'

load 'rails/tasks/statistics.rake'

require 'bundler/gem_tasks'

# Load test tasks
require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = false
end

namespace :test do
  Rake::TestTask.new(:integration) do |t|
    t.libs << 'test'
    t.pattern = 'test/integration/**/*_test.rb'
    t.verbose = false
  end
end

begin
  require 'yard'

  YARD::Rake::YardocTask.new(:yard)

  namespace :yard do
    desc 'Fail when a public object of the API has no documentation'
    task :coverage do
      # The registry must be empty and the files must be read again. YARD keeps a
      # cache in .yardoc, and a run against that cache reports the state of the
      # last run instead of the state of the code.
      YARD::Registry.clear
      YARD::CLI::Yardoc.run('--no-output', '--no-save', '--no-stats', '--quiet')

      # The raw text of the docstring decides. `blank?` and `present?` do not
      # work here: YARD gives every method whose name ends with a question mark
      # an automatic `@return [Boolean]` tag, thus such a method looks
      # documented even without a single comment line.
      undocumented = YARD::Registry.all.reject do |object|
        object.docstring.all.to_s.strip.present? ||
          object.visibility != :public ||
          object.tag(:api)&.text == 'private'
      end

      unless undocumented.empty?
        undocumented.sort_by(&:path).each { |object| warn("undocumented: #{object.path}") }
        abort("#{undocumented.size} public objects of the API have no documentation.")
      end

      puts 'The public API is documented.'
    end
  end
rescue LoadError
  # YARD is a development dependency. The tasks are missing without it.
  nil
end

# The schema of the dummy application is in Git and names a Rails version. An
# older Rails refuses a newer schema with "Unknown migration version", thus the
# file must name the lowest supported Rails.
#
# This is a Rake task and not a test. The CI runs the migrations before the
# suite, and on a newer Rails that run rewrites the file. A test would then read
# the fresh file and not the file of the commit.
LOWEST_SUPPORTED_RAILS_SCHEMA = '8.0'

desc 'Check that the schema of the dummy application names the lowest supported Rails'
task :check_dummy_schema do
  path = File.expand_path('test/dummy/db/schema.rb', __dir__)
  declared = File.read(path)[/ActiveRecord::Schema\[([\d.]+)\]/, 1]

  if declared == LOWEST_SUPPORTED_RAILS_SCHEMA
    puts "The dummy schema names Rails #{declared}."
  else
    abort(
      "test/dummy/db/schema.rb names Rails #{declared.inspect}, expected " \
      "#{LOWEST_SUPPORTED_RAILS_SCHEMA.inspect}. Running the migrations on a newer Rails " \
      'rewrites this line. Set it back before you commit, else the matrix job of the ' \
      'lowest Rails cannot load the schema.'
    )
  end
end

task default: :test
