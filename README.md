# PaperTrailHistory

A Rails engine providing a comprehensive web interface for managing PaperTrail versions. View, search, filter, and restore audit trail records with an intuitive Bootstrap-styled interface.

## Features

- **List All Trackable Models**: Discover all models in your application that use `has_paper_trail`
- **Browse Version History**: View all versions for specific models or individual records
- **Advanced Filtering**: Filter versions by event type, user, date range, and search content
- **Detailed Version View**: See exactly what changed in each version with before/after comparisons
- **Restore Functionality**: Safely restore records to previous versions with confirmation
- **Responsive Design**: Clean, Bootstrap-styled interface that works on all devices
- **Breadcrumb Navigation**: Easy navigation between models, records, and versions

## Installation

Add this line to your application's Gemfile:

```ruby
gem "paper_trail_history"
```

And then execute:
```bash
$ bundle install
```

Mount the engine in your routes file (`config/routes.rb`):

```ruby
Rails.application.routes.draw do
  mount PaperTrailHistory::Engine, at: '/revisions'
  # your other routes...
end
```

Then configure access control - **mounting alone is not enough**, see below.

## Security

> [!IMPORTANT]
> This engine has **no authentication of its own**. It exposes the complete audit
> trail of every versioned model - including historical values of attributes that
> may since have been changed or redacted - and it exposes a `PATCH` endpoint that
> overwrites live records. Treat the mount point like an admin console.

`PaperTrailHistory::ApplicationController` does **not** inherit from your
application's `ApplicationController`, so none of your `before_action` filters run
inside the engine. You have to grant access explicitly.

Since 0.3.0 the engine **refuses every request with `403 Forbidden` unless you
configure it**. Development and test environments stay open (with a log warning) so
that the dummy app and your test suite keep working without an initializer.

### Configuration

Create `config/initializers/paper_trail_history.rb`:

```ruby
PaperTrailHistory.configure do |config|
  # Option A: inherit from a controller that already authenticates.
  # The engine keeps its own layout, only the filters are inherited.
  config.parent_controller = 'Admin::BaseController'

  # Option B: run your own filter. Executed via instance_exec in the controller,
  # so current_user, session, redirect_to, head and main_app.* are all available.
  config.authenticate_with = -> { redirect_to main_app.root_path unless current_user&.admin? }

  # Optional: a separate gate for the destructive restore action.
  # This one is a PREDICATE - return true to allow, false to deny.
  # If unset, anyone who passes authentication may restore.
  config.authorize_restore_with = -> { current_user.owner? }
end
```

### Assets and Content Security Policy

The interface uses Bootstrap, loaded from jsDelivr by default and pinned with a
subresource integrity hash so a tampered file is rejected by the browser. The
engine's own inline `<style>` and `<script>` carry the CSP nonce when your
application generates one, so a nonce-based policy works without `unsafe-inline`.

To serve the files yourself - required for an air-gapped network, or a policy
that allows no third-party origin - point them at your own assets and drop the
integrity hashes:

```ruby
config.assets = {
  bootstrap_css:       { href: '/assets/bootstrap.css' },
  bootstrap_icons_css: { href: '/assets/bootstrap-icons.css' },
  bootstrap_js:        { href: '/assets/bootstrap.bundle.js' }
}
```

> [!WARNING]
> If your nonce generator returns an empty string the browser rejects the whole
> nonce source and blocks all inline style and script. Rails' commented-out
> suggestion, `request.session.id.to_s`, does exactly that on a request with no
> session yet. Prefer something that always yields a value, e.g.
> `->(_request) { SecureRandom.base64(16) }`.

### Models with a non-integer primary key

The engine looks records up by the model's own primary key, so a model using a
UUID or any other custom key works.

> [!NOTE]
> PaperTrail's generated `versions` table declares `item_id` as `bigint`. A UUID
> written into that column becomes `0`, and the version history for such a model
> stays empty. This is a property of your versions table, not of this engine - if
> you version models with non-integer keys, `item_id` has to be a string column.

### Single table inheritance

PaperTrail records the **base class** name in `item_type`, so a version created
by `Admin < User` is stored as `"User"`. The engine looks versions up by base
class and narrows them with PaperTrail's optional `item_subtype` column, which
holds the real class name.

If your versions table has an `item_subtype` column, each STI subclass shows
exactly its own history, and the base class shows all of it (matching
ActiveRecord's own STI semantics). Without that column the subtypes are
indistinguishable in the data, so a subclass falls back to showing its base
class's versions. To add it:

```ruby
add_column :versions, :item_subtype, :string
add_index  :versions, %i[item_type item_subtype]
```

### Page size

Version tables grow without bound, so the engine reads one page at a time rather
than loading a model's entire history into memory. The default is 25 rows:

```ruby
config.page_limit = 50
```

Pagination uses [Pagy](https://github.com/ddnexus/pagy). The limit is passed per
query rather than written into `Pagy::OPTIONS`, so mounting this engine does not
change pagination defaults elsewhere in your application.

### Translations

Every string in the interface goes through I18n. The gem ships **English and
German**; dates and times use per-locale format strings, so each language orders
them its own way.

To translate the interface into another language, add a locale file under the
`paper_trail_history` scope - see `config/locales/en.yml` in this gem for the
full set of keys. To override individual strings, define the same key in your
application; your locale files load after the engine's and win.

> [!NOTE]
> Because only `en` and `de` ship, an application running under a third locale
> gets missing-translation errors unless I18n fallbacks are enabled:
> ```ruby
> config.i18n.fallbacks = [:en]
> ```

### Redacting sensitive attributes

The interface shows every attribute of a record, and every before/after value in
a version diff. Without redaction that means password digests, API tokens and
session keys - including *historical* values that have since been rotated.

By default the engine hides whatever your application already hides from its
logs, i.e. `Rails.application.config.filter_parameters`. Attributes matched by
that list render as `[FILTERED]` on both the record page and the diff. To hide
more:

```ruby
config.filter_attributes += [:internal_note, /_secret\z/]
```

The list accepts everything `ActiveSupport::ParameterFilter` accepts - symbols,
strings (substring match), regular expressions and procs - and matching is
delegated to that class, so it behaves exactly like Rails log filtering.

> [!NOTE]
> Rails' default `filter_parameters` includes `:email`, so email addresses are
> redacted out of the box. Set `config.filter_attributes` explicitly if that is
> not what you want.

Either `parent_controller` or `authenticate_with` satisfies the check; you can use
both. Note the asymmetry: `authenticate_with` is a **filter** (halt the chain
yourself with `redirect_to`/`head`, which lets you pass Devise's
`authenticate_user!` straight in), while `authorize_restore_with` is a
**predicate** that returns a boolean.

`parent_controller` is read once, when Rails first loads the engine controller.
Set it in an initializer - changing it at runtime has no effect.

### Route-level protection

Configuration composes with a route constraint, and using both is a good idea:

```ruby
authenticate :user, ->(user) { user.admin? } do
  mount PaperTrailHistory::Engine, at: '/revisions'
end
```

### Running without authentication

If a different layer protects the mount point (a VPN, a reverse proxy, an
IP allowlist), opt out explicitly:

```ruby
config.allow_unauthenticated_access = true
```

## Prerequisites

This engine requires:
- Ruby >= 3.3.0
- Rails >= 8.0
- PaperTrail >= 15.0 (configured with `has_paper_trail` in your models)
- Pagy ~> 43.0 (installed automatically, see the note in the changelog)

Make sure you have PaperTrail properly configured in your Rails application before using this engine.

### YAML deserialization (required for restoring)

PaperTrail stores the previous state of a record as YAML. Since Rails 7.1, Rails
loads only an explicitly permitted set of classes out of a YAML column, and that
set does **not** include `ActiveSupport::TimeWithZone`. Every model with
`created_at`/`updated_at` therefore fails to reify, and restoring dies with:

```
Tried to load unspecified class: ActiveSupport::TimeWithZone
```

Browsing history is unaffected - only restoring breaks. Permit the types your
models actually store, in `config/application.rb`:

```ruby
config.active_record.yaml_column_permitted_classes = [
  Symbol, Date, Time, ActiveSupport::TimeWithZone, ActiveSupport::TimeZone, BigDecimal
]
```

Add any other class your models serialize (for example `ActiveSupport::HashWithIndifferentAccess`).
If a class is missing, the engine reports which setting to change instead of
showing the raw Psych error.

## Usage

After mounting the engine, navigate to `/revisions` (or whatever path you chose) in your browser to access the interface.

### Main Features

1. **Models Overview** (`/revisions/models`)
   - Lists all models with paper trail enabled
   - Shows version counts for each model
   - Quick access to recent versions

2. **Model Versions** (`/revisions/models/:model_name/versions`)
   - View all versions for a specific model
   - Filter by event type, user, date range
   - Search within version content
   - Pagination (25 rows per page by default, see `config.page_limit`)

3. **Record Versions** (`/revisions/models/:model_name/:record_id/versions`)
   - View version history for a specific record
   - See current record state vs historical versions

4. **Version Details** (`/revisions/versions/:id`)
   - Detailed view of what changed in a specific version
   - Side-by-side comparison of old vs new values
   - Restore functionality with confirmation

### Filtering and Search

The interface provides several ways to filter and search versions:

- **Event Type**: Filter by create, update, or destroy events
- **User**: Filter by who made the changes (whodunnit)
- **Date Range**: Show versions within specific date ranges
- **Content Search**: Search within the stored object changes

### Restoring Versions

You can restore any version (except create events) by:

1. Navigate to the version details page
2. Click "Restore This Version"
3. Confirm the restoration

**Note**: Restoring a version will create a new version entry, so you can always see the restoration in the audit trail.

## Development

### Quick Start

After cloning the repository, run the setup script to get started:

```bash
# Automated setup - installs dependencies, sets up database, runs tests
bin/setup
```

This script will:
- Install bundler and project dependencies
- Set up the test dummy app with database and seed data
- Run initial tests to verify everything works
- Run the linter to check code quality

### Manual Setup (Alternative)

If you prefer manual setup:

```bash
# Install dependencies
bundle install

# Set up test database with sample data
cd test/dummy
bundle install --gemfile=../../Gemfile
bundle exec rails db:prepare
bundle exec rails db:seed
cd ../..
```

### Running Tests

```bash
# Run all tests
bundle exec rake test

# Run integration tests only
bundle exec rake test:integration

# Run specific test file
bundle exec ruby -I test test/models/paper_trail_history/trackable_model_test.rb

# Run with verbose output
bundle exec rake test TESTOPTS="-v"

# Run code quality checks
bundle exec rubocop
```

### API Documentation

The public API is documented with YARD. CI fails if a public object loses its
documentation, so new API needs a docstring to merge.

```bash
# Generate HTML docs into doc/
bundle exec rake yard

# List anything public that is undocumented (this is what CI runs)
bundle exec rake yard:coverage
```

Internal helpers are tagged `@api private` and are excluded from both the
generated docs and the coverage gate.

### Testing Different Components

```bash
# Test models only
bundle exec rake test TEST="test/models/**/*_test.rb"

# Test controllers only  
bundle exec rake test TEST="test/controllers/**/*_test.rb"

# Test integration features
bundle exec rake test TEST="test/integration/**/*_test.rb"
```

### Using the Dummy Application

The `test/dummy` directory contains a full Rails application with sample models and data for testing:

```bash
# Start the development server (from project root)
bin/dummy

# Alternative: manual approach
cd test/dummy && bundle exec rails server

# Visit the engine interface
open http://localhost:3000/paper_trail_history
```

The dummy app includes:
- **User, Post, Comment models** - Standard PaperTrail setup
- **Product model** - Custom version table (`ProductVersion`) 
- **Rich seed data** - Various change types, workflows, and scenarios
- **I18n translations** - Proper model pluralization

### Testing Against Multiple Rails Versions

For comprehensive compatibility testing, use the provided Gemfiles:

```bash
# Test against Rails 8.0
BUNDLE_GEMFILE=gemfiles/rails_8.0.gemfile bundle install
BUNDLE_GEMFILE=gemfiles/rails_8.0.gemfile bundle exec rake test

# Test against Rails 8.1
BUNDLE_GEMFILE=gemfiles/rails_8.1.gemfile bundle install
BUNDLE_GEMFILE=gemfiles/rails_8.1.gemfile bundle exec rake test

# Test against Rails main branch
BUNDLE_GEMFILE=gemfiles/rails_main.gemfile bundle install
BUNDLE_GEMFILE=gemfiles/rails_main.gemfile bundle exec rake test
```

### Continuous Integration

The project uses GitHub Actions to test against multiple Ruby and Rails versions. See `.github/workflows/ci.yml` for the full matrix configuration.

## Contributing

1. Fork the project
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

---

Kindly supported by [aifinyo AG](https://aifinyo.de)
