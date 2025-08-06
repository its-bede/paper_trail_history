# frozen_string_literal: true

require_relative 'lib/paper_trail_history/version'

Gem::Specification.new do |spec|
  spec.name        = 'paper_trail_history'
  spec.version     = PaperTrailHistory::VERSION
  spec.authors     = ['Benjamin Deutscher']
  spec.email       = ['ben@bdeutscher.org']
  spec.homepage    = 'https://github.com/its-bede/paper_trail_history'
  spec.summary     = 'A Rails engine providing a web interface for managing PaperTrail versions.'
  spec.description = <<~DESCRIPTION
    PaperTrailHistory is a mountable Rails engine that provides a comprehensive web interface for viewing, searching,
    and managing audit trail versions created by the PaperTrail gem. Features include listing trackable models,
    browsing version history, filtering and searching changes, and restoring previous versions of records.
  DESCRIPTION
  spec.license = 'MIT'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  # spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/its-bede/paper_trail_history'
  spec.metadata['changelog_uri'] = 'https://github.com/its-bede/paper_trail_history/blob/main/CHANGELOG.md'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']
  end

  spec.required_ruby_version = '>= 3.1.0'

  spec.add_dependency 'paper_trail', '>= 15.0'
  spec.add_dependency 'rails', '>= 7.2'
end
