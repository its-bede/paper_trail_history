# TASKS - Code Review Findings

Review date: 2026-08-13 · Version reviewed: 0.2.1 · Branch: `main`

The text uses ASD-STE100 Simplified Technical English.

> **Note on verification:** All findings come from a static read of the code.
> `bundle install` ran later. The baseline was then green: 56 tests, 0 failures,
> and RuboCop found no offense. Thus no finding in this list comes from a test
> that fails now.

**Highest priority:** S1, R1, R9, S2, P1, R2, D2, P2, P3, R4 - all done.
Next: D1 (YARD), P6, then the small ones R7, R8, P5, Q1, Q2, Q3 and the test
tasks T1 to T5.

---

## 1. Security

### S1 - Add an access control hook to the engine - **Critical** - DONE (0.3.0)

`app/controllers/paper_trail_history/application_controller.rb:4`

The engine controller comes directly from `ActionController::Base`. The
controller does not use the authentication of the host application. Each person
who knows the mount path can read the full audit trail. Each person can also
restore records.

- [x] Add a configuration object, for example `PaperTrailHistory.configure`.
- [x] Let the host application set a parent controller class and a `before_action`.
- [x] Make the default safe. Refuse the request if the host application sets no authentication.
- [x] Add a separate gate for the restore action.

The engine refuses a request with 403 outside development and test if the host
application sets no access control. `allow_unauthenticated_access` is the
documented escape hatch.

**Open point for a later task:** `parent_controller` gives the filters of the
host controller to the engine, but the engine keeps its own layout. Make the
layout configurable together with S3 and S4.

### S2 - Hide sensitive attributes - **High** - DONE (0.3.0)

`app/views/paper_trail_history/records/show.html.erb:28`,
`app/models/paper_trail_history/version_decorator.rb:60`

The record page prints all attributes of the record. This includes password
digests, tokens and API keys. The version diff shows the same values.

- [x] Filter the attribute names with `Rails.application.config.filter_parameters`.
- [x] Add a configuration option for more filtered names.

### S3 - Remove the CDN dependency or add integrity attributes - **Medium** - DONE (0.3.0)

`app/views/layouts/paper_trail_history/application.html.erb:11,12,123`

The layout gets Bootstrap CSS and JS from a public CDN. There is no `integrity`
attribute. A person who controls the CDN can run code in the page. The interface
also does not work in a network without internet.

- [x] Add `integrity` and `crossorigin`. The values were computed from the real files.
- [x] Give a configuration option, thus the host application can serve the files itself.

The files stay on the CDN by default. To put them into the gem would need an
asset pipeline that works with Propshaft, Sprockets and Importmap in the host
application, and it would make the gem about 1 MB larger. `config.assets` gives
the user the choice.

### S4 - Make the layout work with a strict Content Security Policy - **Medium** - DONE (0.3.0)

`app/views/layouts/paper_trail_history/application.html.erb:14,124`

The inline `<style>` and `<script>` blocks have no nonce. The layout prints
`csp_meta_tag`, but it does not use the nonce. A host application with a strict
CSP shows a page without styles and without scripts.

- [x] Give the inline style and the inline script a nonce. The external tags also get one, thus a policy with nonces permits them too.

The dummy application now uses a strict policy, thus the test suite runs against
it. The interface was also checked with a browser: no violation, the style is
active and the script runs.

**Found while testing:** an empty nonce is worse than no nonce. The browser
refuses the whole source list and blocks everything. The engine writes no
attribute if the host application makes no nonce. The README warns about the
suggestion of Rails, `request.session.id.to_s`, which is empty without a session.

### S5 - Escape the LIKE wildcards in the search - **Low**

`app/models/paper_trail_history/version_service.rb:106`

The query uses bind parameters, thus SQL injection is not possible. But the user
input keeps the `%` and `_` wildcards. A search for `%` reads all rows.

- [ ] Use `sanitize_sql_like`.
- [ ] Limit the length of the search term.

---

## 2. Robustness and Correctness

### R1 - Restore uses the wrong version record - **Critical** - DONE (0.3.0)

`app/controllers/paper_trail_history/versions_controller.rb:14` →
`app/models/paper_trail_history/version_service.rb:35`

The controller finds the version with `model_name`. Then
`restore_version(@version.id)` searches a second time with
`find_version_across_tables`. If the application has more than one version table
(the dummy app has `versions` and `product_versions`), two rows can have the same
ID. The service can restore a different record than the one on the screen.

- [x] Give the version object to `restore_version`. Do not search a second time.

### R2 - Invalid date parameters cause an error page - **High** - DONE (0.3.0)

`app/models/paper_trail_history/version_service.rb:100-104`

`Date.parse` gets the URL value without a check. A request with `?from_date=abc`
raises `Date::Error`. The user sees a 500 error.

- [x] Parse the date in a safe method. Ignore an invalid value.
- [x] Add a test.

`VersionService.parse_date` gives `nil` for text that is not a date. The filter
then does not use this part. The page stays available.

### R3 - Add a nil check for the trackable model - **Medium** - DONE (0.3.0)

`app/controllers/paper_trail_history/versions_controller.rb:10`

`TrackableModel.find` can give `nil`, for example after you rename or delete a
model. The view then calls `@trackable_model.human_name` and the request fails.

- [x] Check for `nil`. Redirect with a message.

The test writes the column directly, because a version that points to a class
which does not exist cannot be made through the association.

### R4 - Correct the behavior for STI models - **Medium** - DONE (0.3.0)

`app/models/paper_trail_history/trackable_model.rb:83`

`item_type_for_versions` gives `klass.name`. PaperTrail writes the name of the
base class into `item_type`. Thus an STI subclass shows 0 versions and an empty
list. The links in the version table also use `item_type` and point to the wrong
model page.

- [x] Use `klass.base_class.name` for the query, and narrow with `item_subtype`.

The dummy application now has an `Admin < User` model and an `item_subtype`
column, thus the test suite covers both paths. A version table without
`item_subtype` cannot separate the subclasses, and a subclass then shows the
versions of its base class. The README describes this.

### R5 - Make the confirmation dialog work - **Medium** - DONE (0.3.0)

`app/views/paper_trail_history/shared/_versions_table.html.erb:49`,
`app/views/paper_trail_history/versions/show.html.erb:16,74`

The restore buttons use `data: { confirm: … }`. The engine layout loads only
Bootstrap. It does not load Turbo or rails-ujs. Thus no dialog opens. One click
restores the record immediately.

- [x] Add your own JavaScript. The engine does not load Turbo.
- [x] Test the dialog.

The engine uses its own `data-pth-confirm` attribute and a handler in the
layout. Turbo was not the choice, because Turbo Drive would also take over each
link of the engine, and it would come from a second CDN (see S3). The own
attribute also prevents a second dialog in a host application that loads Turbo.

The integration tests check the markup and the handler. They cannot run
JavaScript. The dialog itself was tested with a browser: a click opens the
dialog, "Cancel" keeps the record, and "OK" restores it.

**This makes S4 larger.** The handler is one more inline script without a nonce.

### R6 - Clear the class caches at code reload - **Medium** - DONE (0.3.0)

`app/models/paper_trail_history/trackable_model.rb:14-31,75`,
`app/models/paper_trail_history/version_service.rb:82`

`@all_models` and `@all_version_classes` hold class objects. Rails reloads the
code in development. The caches then hold old classes. This gives wrong data and
holds memory. The memoization is also not thread-safe.

- [x] Call `clear_cache!` from a `to_prepare` hook in the engine.
- [x] Protect the write with a `Monitor`. A `Monitor` is reentrant, thus the discovery cannot make a deadlock.

Note for the tests: Rails puts the `to_prepare` blocks on
`Rails.application.reloader`, not on `ActiveSupport::Reloader`. A test must call
`Rails.application.reloader.prepare!`.

### R7 - Use the primary key of the model - **Low**

`app/controllers/paper_trail_history/records_controller.rb:35`

`find_by(id: …)` does not work for a model with a different primary key.

- [ ] Use `klass.find_by(klass.primary_key => params[:record_id])`.

### R8 - Give back the correct record after a restore - **Low**

`app/models/paper_trail_history/version_service.rb:167`

`restore_previous_version` gives `version.item`. This object is the old object in
memory. It does not show the new values.

- [ ] Reload the item, or give back the object from `reify`.

### R9 - Make the restore work with the YAML rules of Rails - **High** - DONE (0.3.0)

`README.md`, `app/models/paper_trail_history/version_service.rb:35`

Found while the team did R1. PaperTrail keeps the previous state of a record as
YAML. From Rails 7.1, Rails loads only a small set of classes from a YAML column.
`ActiveSupport::TimeWithZone` is not in this set. Each model with `created_at`
and `updated_at` thus fails at `reify` with the message
`Tried to load unspecified class: ActiveSupport::TimeWithZone`. The restore
function is the main function of this gem, and it does not work in a new Rails
application with the default settings.

The test suite did not find this, because the test `should restore version`
replaces `VersionService.restore_version` with a stub. No test did a real
restore. See T1.

The dummy application now sets `yaml_column_permitted_classes` (commit for R1).
The gem must also help the user of the gem:

- [x] Write the necessary `config.active_record.yaml_column_permitted_classes` in the README.
- [x] Catch `Psych::DisallowedClass` and give a message that tells the user what to configure.
- [x] Add a test with a real restore of a model that has timestamps.

---

## 3. Performance

### P1 - Add pagination - **Critical** - DONE (0.3.0)

`app/controllers/paper_trail_history/models_controller.rb:42`,
`app/controllers/paper_trail_history/records_controller.rb:45`

The controller reads all versions of a model into memory and decorates each row.
A production table with one million versions makes the page unusable. The process
can also run out of memory. The `page` parameter is permitted, but no code uses
it. The README says "Pagination support".

- [x] Add pagination with LIMIT and OFFSET. Show page links.
- [x] Correct the claim in the README.

The engine uses Pagy (`~> 43.0`) and `config.page_limit` (default 25). The gem
now has a hard dependency on Pagy. See the note in the changelog.

### P2 - Do not load all rows for the filter lists - **High** - DONE (0.3.0)

`app/models/paper_trail_history/version_service.rb:44-70`

If `model_name` is `nil`, `unique_whodunnits` and `available_events` call `.all`
on each version class. The code loads all rows into memory and then maps them in
Ruby.

- [x] Use `distinct.pluck` on the database for each class. Then join the results.

A test reads the SQL and makes sure that no query selects full version rows.

### P3 - Remove the N+1 queries - **High** - DONE (0.3.0)

`app/controllers/paper_trail_history/records_controller.rb:45`,
`app/controllers/paper_trail_history/models_controller.rb:18`,
`app/views/paper_trail_history/shared/_versions_table.html.erb:37`

`item_display_name` reads `version.item` for each row. Only
`ModelsController#versions` uses `includes(:item)`. The other three actions do
not.

- [x] Add `includes(:item)` to `RecordsController#versions` (came with P1).
- [x] Add `includes(:item)` to `TrackableModel#recent_versions`, which `ModelsController#show` uses. The page made 20 queries and now makes 1.

**Correction of the work for P1:** P1 added `includes(:item)` to
`RecordsController#versions`. That view does not show the name of the item, thus
the preload only cost a query. It is removed again. `RecordsController#show` has
the same view and needs no preload.

### P4 - Remove the unnecessary COUNT query - **Low** - DONE (0.3.0)

`app/views/paper_trail_history/models/versions.html.erb:11`,
`app/views/paper_trail_history/records/versions.html.erb:17`

The view calls `@versions.count`. This starts a second database query. The rows
are already in memory.

- [x] Use `size` on the decorated array, or the total from the pagination.

The views use `@pagy.count`, which comes from the count query of the paginator.

### P5 - Make the content search faster - **Medium**

`app/models/paper_trail_history/version_service.rb:106`

`LIKE '%term%'` cannot use an index. The database reads the full table.

- [ ] Write this limit in the documentation.
- [ ] Add an option for a JSONB search or a full-text index.

### P6 - Replace `ObjectSpace.each_object` - **Medium**

`app/models/paper_trail_history/trackable_model.rb:21`

The code reads all classes in the process. This is slow. It can also find classes
that Rails removed.

- [ ] Use `ActiveRecord::Base.descendants` after `eager_load!`.

### P7 - Do not call `eager_load!` in a request - **Low**

`app/models/paper_trail_history/trackable_model.rb:17`

In development the first request loads the full application.

- [ ] Move the call to an initializer, or write it in the documentation.

---

## 4. Code Quality

### Q1 - Divide `VersionService` - **Medium**

`app/models/paper_trail_history/version_service.rb`, `.rubocop.yml:54-57`

The class has 172 lines and 25 public class methods. Internal methods such as
`apply_filters` and `filter_by_event` are public. The RuboCop file has an
exclusion for `Metrics/ClassLength`. The exclusion hides the problem.

- [ ] Make a query object and a restore service.
- [ ] Make internal methods private with `private_class_method`.
- [ ] Remove the RuboCop exclusions.

### Q2 - Change the name of `VersionDecorator#changed_attributes` - **Low**

`app/models/paper_trail_history/version_decorator.rb:60`

ActiveModel has a method with the same name and a different result. This causes
confusion.

- [ ] Use a different name, for example `attribute_changes`.

### Q3 - Remove the duplicate controller code - **Low**

`app/controllers/paper_trail_history/models_controller.rb:33`,
`app/controllers/paper_trail_history/records_controller.rb:25`

`find_trackable_model_or_redirect` exists two times. Only the parameter name is
different.

- [ ] Move the method to `ApplicationController`.

### Q4 - Move the CSS and the JavaScript out of the layout - **Low** - PART DONE

`app/views/layouts/paper_trail_history/application.html.erb`

80 lines of CSS and 16 lines of JavaScript are in the layout file. Task S4 needs
this change also.

- [x] Put the CSS and the JavaScript into partials. The layout went from 143 to 51 lines.
- [ ] Put them into real asset files. This needs an asset pipeline for the engine that works with Propshaft, Sprockets and Importmap.

### Q5 - Localize the texts of the views - **Medium** - DONE (0.3.0)

All view files, `app/models/paper_trail_history/version_decorator.rb:27,86-102`

The engine has `en.yml` and `de.yml`. But all texts in the views are English
strings in the code ("Version Details", "Restore This Version").
`formatted_created_at` uses a fixed US format. The texts `(empty)` and `(blank)`
are not in the locale files.

- [x] Move all texts to the locale files.
- [x] Use `I18n.l` for the date and the time. The format string comes from the locale.

The English output did not change, thus the tests that check English text still
pass. The test environment now raises for a missing translation. Two new test
files protect the work: one renders each page in German, one compares the keys
and the interpolations of the locale files.

**Open point:** the gem gives only English and German. An application with a
third language needs `config.i18n.fallbacks`. The README says this.

### Q6 - Remove the placeholder comment - **Low**

`lib/paper_trail_history.rb:14` has `# Your code goes here...`.

- [ ] Remove the comment.

### Q7 - Remove the build artifacts - **Low** - PART DONE

`paper_trail_history-0.2.0.gem` and `paper_trail_history-0.2.1.gem` are in the
working directory. `.gitignore` does not have them.

- [x] Add `*.gem` to `.gitignore`. The `.gitignore` also ignores the artifacts of the browser automation now.
- [ ] Think about the removal of `Gemfile.lock` from Git, because this project is a gem.

---

## 5. Documentation (YARD)

### D1 - Add YARD documentation to the public API - **Medium**

No file has a YARD tag. There is no `@param`, no `@return`, no `@raise` and no
`@example`. There is no `.yardopts` file, no `yard` development dependency and no
doc task.

- [ ] Add `yard` to the Gemfile as a development dependency.
- [ ] Add a `.yardopts` file.
- [ ] Document each public method of `VersionService`, `TrackableModel`, `VersionDecorator` and `ApplicationHelper`.
- [ ] Add `@example` to the restore methods.
- [ ] Add `@api private` to internal methods.
- [ ] Add a `yard` task and a documentation check to the CI.

### D2 - Correct the version numbers in the documents - **High** - DONE (0.3.0)

`README.md:40,181-183`, `CLAUDE.md`

The README says "Rails >= 7.2". The gemspec needs Rails >= 8.0 and Ruby >= 3.3.0.
CLAUDE.md says "Rails >= 7.2, Ruby >= 3.1.0". The README tells the user to use
`gemfiles/rails_7.2.gemfile`. This file does not exist.

- [x] Correct the README and CLAUDE.md.
- [x] Remove the Rails 7.2 instructions. The README now names the Rails 8.1 Gemfile, which exists.

### D3 - Correct the wrong feature claims - **Low** - DONE (0.3.0)

`README.md`

The README lists "Pagination support", but the code has no pagination (see P1).

- [x] Correct the statement about pagination. P1 made the claim true, and the README now names the default page size.

**Correction of this review:** the second point of this task was wrong. The
review said that the README shows the mount path `/revisions` and then tells the
user to open `http://localhost:3000/paper_trail_history`. The two statements are
in different sections. The second one belongs to the dummy application, and the
dummy application mounts the engine at `/paper_trail_history`. Thus the README is
correct here.

### D4 - Document the security model - **High** - DONE (0.3.0)

`README.md`

- [x] Add a section. Write clearly that the engine has no authentication of its own.
- [x] Give an example with a route constraint.
- [x] Warn about the restore function and about the exposure of the data.

### D5 - Delete or move `PLAN.md` - **Low**

All items are done. The file is not useful for the user of the gem.

- [ ] Delete the file, or move it to the wiki.

---

## 6. Tests and CI

### T1 - Correct the tests that test nothing - **High**

`test/models/paper_trail_history/version_service_test.rb:11-42`

Tests such as `assert_respond_to versions, :where` do not test the filter. The
test passes also when the filter is not correct.

- [ ] Make version rows with known data.
- [ ] Check the IDs in the result. Test each filter.

### T2 - Delete the empty test file - **Low**

`test/integration/navigation_test.rb` has no test.

- [ ] Delete the file.

### T3 - Add tests for the faults above - **High**

- [ ] Test an invalid date (R2).
- [ ] Test a nil trackable model (R3).
- [ ] Test a restore with two version tables (R1).
- [ ] Test STI models (R4).
- [ ] Test the filter of sensitive attributes (S2).

### T4 - Add controller tests for `RecordsController` - **Medium** - PART DONE

The file `test/controllers/paper_trail_history/records_controller_test.rb` now
exists. It came with S2 and tests the `show` action and the redirect for a model
that is not trackable.

- [x] Add `test/controllers/paper_trail_history/records_controller_test.rb`.
- [ ] Test the `versions` action and its filters.

### T5 - Add coverage and security checks to the CI - **Medium**

`.github/workflows/ci.yml`

- [ ] Add SimpleCov with a minimum value.
- [ ] Add a `bundler-audit` step and a `brakeman` step.

### T6 - Repair the local development environment - **Low** - DONE

`bundle exec rubocop` and `bundle exec rake test` did not run on the review
machine. Five gems were not installed (`bigdecimal-4.0.0`, `timeout-0.5.0`,
`net-imap-0.6.0`, `rdoc-6.17.0`, `psych-5.3.0`).

- [x] Run `bundle install` before the next check.
