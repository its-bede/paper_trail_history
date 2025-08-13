# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.3] - 2025-08-13

### Changed
- **Layout Improvement**: Updated application layout to use `container-fluid` instead of `container` for full-width display

## [0.1.2] - 2025-08-07

### Fixed
- **acts_as_paranoid Compatibility**: Fixed `find_version_across_tables` method to work with soft-deleted version records by using `unscoped` to bypass default scopes including acts_as_paranoid

## [0.1.1] - 2025-08-06

### Fixed
- **Restore Action Routing**: Fixed routing error where restore actions were generating GET requests instead of PATCH requests
- **View Components**: Replaced `link_to` with `method: :patch` with proper `button_to` elements for restore actions

## [0.1.0] - 2025-08-06

### Released
- **🚀 Initial Release**: Successfully published to RubyGems.org as `paper_trail_history` v0.1.0
- **📦 Gem Available**: Install with `gem install paper_trail_history`
- **🔗 RubyGems**: https://rubygems.org/gems/paper_trail_history

### Changed
- **CI Optimization**: Moved RuboCop to separate lint job to avoid redundant execution across matrix builds
- **Timeout Reduction**: Reduced Rails server startup timeout from 30s to 10s in CI tests
- **Linting Configuration**: Replaced rubocop-rails-omakase with default rubocop-rails configuration

### Added

#### Core Features
- **Web Interface**: Complete Bootstrap-styled web interface for managing PaperTrail versions
- **Models Discovery**: Automatic discovery of all models using `has_paper_trail` via module inclusion detection
- **Multiple Version Tables**: Support for custom version classes and tables (e.g., `ProductVersion` → `product_versions`)
- **Version Listing**: Browse all versions for specific models or individual records
- **Version Details**: Detailed view showing exactly what changed in each version
- **Restore Functionality**: Safely restore records to previous versions with confirmation dialogs

#### User Interface
- **Git-style Diffs**: Beautiful diff display with syntax highlighting showing old vs new values
- **Responsive Design**: Mobile-friendly interface using Bootstrap 5.3
- **Icon-based Actions**: Compact action buttons with Bootstrap tooltips
- **Breadcrumb Navigation**: Clear navigation hierarchy between models, records, and versions
- **Search and Filtering**: Filter versions by event type, user, date range, and content search

#### Developer Experience
- **Rails Engine**: Mountable engine that integrates seamlessly into existing Rails applications
- **I18n Support**: Proper internationalization with model name pluralization via `model_name.human(count: 2)`
- **Performance Optimization**: Bulk count queries to minimize database load
- **Custom Version Classes**: Full support for PaperTrail's custom version table feature
- **Turbo Compatibility**: Works with both traditional Rails apps and Turbo-powered applications

#### Testing & Development
- **Comprehensive Test Suite**: Unit, integration, and controller tests
- **Dummy Application**: Full test application with sample models and rich seed data
- **Multi-Version Testing**: GitHub Actions CI testing against Ruby 3.1-3.3 and Rails 7.1-8.0+
- **Code Quality**: RuboCop with default Rails rules for consistent code style

#### Documentation
- **Complete README**: Installation, usage, and development instructions
- **API Documentation**: Inline code documentation for all classes and methods
- **Development Guide**: Detailed testing and contribution guidelines

### Technical Details

#### Models & Services
- `TrackableModel`: Discovers and manages models with PaperTrail
- `VersionService`: Handles version queries, filtering, and restoration
- `VersionDecorator`: Formats version data for display with git-style diffs

#### Controllers
- `ModelsController`: Lists trackable models and their versions
- `RecordsController`: Shows version history for specific records  
- `VersionsController`: Displays version details and handles restoration

#### Key Features
- Automatic model discovery using `PaperTrail::Model::InstanceMethods` inclusion
- Performance-optimized bulk queries grouped by version class
- Git-style diff display with proper syntax highlighting
- Bootstrap tooltips for enhanced user experience
- Comprehensive error handling and user feedback
- RESTful routing structure for intuitive navigation

### Dependencies

- **Rails**: >= 8.0.2 (with support for Rails 7.1+)
- **PaperTrail**: >= 15.0
- **Bootstrap**: 5.3.0 (loaded via CDN)
- **Bootstrap Icons**: 1.10.0 (loaded via CDN)

[Unreleased]: https://github.com/your-org/paper_trail_history/compare/v0.1.3...HEAD
[0.1.3]: https://github.com/your-org/paper_trail_history/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/your-org/paper_trail_history/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/your-org/paper_trail_history/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/your-org/paper_trail_history/releases/tag/v0.1.0