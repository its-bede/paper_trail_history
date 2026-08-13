# TASKS - Code Review Findings

Review date: 2026-08-13 · Version reviewed: 0.2.1 · Branch: `main`

The text uses ASD-STE100 Simplified Technical English.

> **Note on verification:** All findings come from a static read of the code.
> `bundle install` ran later. The baseline was then green: 56 tests, 0 failures,
> and RuboCop found no offense. Thus no finding in this list comes from a test
> that fails now.

**Highest priority:** S1 (done), R1, P1, S2.

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

### S2 - Hide sensitive attributes - **High**

`app/views/paper_trail_history/records/show.html.erb:28`,
`app/models/paper_trail_history/version_decorator.rb:60`

The record page prints all attributes of the record. This includes password
digests, tokens and API keys. The version diff shows the same values.

- [ ] Filter the attribute names with `Rails.application.config.filter_parameters`.
- [ ] Add a configuration option for more filtered names.

### S3 - Remove the CDN dependency or add integrity attributes - **Medium**

`app/views/layouts/paper_trail_history/application.html.erb:11,12,123`

The layout gets Bootstrap CSS and JS from a public CDN. There is no `integrity`
attribute. A person who controls the CDN can run code in the page. The interface
also does not work in a network without internet.

- [ ] Put the assets into the engine, or add `integrity` and `crossorigin`.

### S4 - Make the layout work with a strict Content Security Policy - **Medium**

`app/views/layouts/paper_trail_history/application.html.erb:14,124`

The inline `<style>` and `<script>` blocks have no nonce. The layout prints
`csp_meta_tag`, but it does not use the nonce. A host application with a strict
CSP shows a page without styles and without scripts.

- [ ] Use `stylesheet_link_tag` / `javascript_tag nonce: true`, or move the code to asset files.

### S5 - Escape the LIKE wildcards in the search - **Low**

`app/models/paper_trail_history/version_service.rb:106`

The query uses bind parameters, thus SQL injection is not possible. But the user
input keeps the `%` and `_` wildcards. A search for `%` reads all rows.

- [ ] Use `sanitize_sql_like`.
- [ ] Limit the length of the search term.

---

## 2. Robustness and Correctness

### R1 - Restore uses the wrong version record - **Critical**

`app/controllers/paper_trail_history/versions_controller.rb:14` →
`app/models/paper_trail_history/version_service.rb:35`

The controller finds the version with `model_name`. Then
`restore_version(@version.id)` searches a second time with
`find_version_across_tables`. If the application has more than one version table
(the dummy app has `versions` and `product_versions`), two rows can have the same
ID. The service can restore a different record than the one on the screen.

- [ ] Give the version object to `restore_version`. Do not search a second time.

### R2 - Invalid date parameters cause an error page - **High**

`app/models/paper_trail_history/version_service.rb:100-104`

`Date.parse` gets the URL value without a check. A request with `?from_date=abc`
raises `Date::Error`. The user sees a 500 error.

- [ ] Parse the date in a safe method. Ignore an invalid value.
- [ ] Add a test.

### R3 - Add a nil check for the trackable model - **Medium**

`app/controllers/paper_trail_history/versions_controller.rb:10`

`TrackableModel.find` can give `nil`, for example after you rename or delete a
model. The view then calls `@trackable_model.human_name` and the request fails.

- [ ] Check for `nil`. Redirect with a message.

### R4 - Correct the behavior for STI models - **Medium**

`app/models/paper_trail_history/trackable_model.rb:83`

`item_type_for_versions` gives `klass.name`. PaperTrail writes the name of the
base class into `item_type`. Thus an STI subclass shows 0 versions and an empty
list. The links in the version table also use `item_type` and point to the wrong
model page.

- [ ] Use `klass.base_class.name` for the query, or remove STI subclasses from the model list.

### R5 - Make the confirmation dialog work - **Medium**

`app/views/paper_trail_history/shared/_versions_table.html.erb:49`,
`app/views/paper_trail_history/versions/show.html.erb:16,74`

The restore buttons use `data: { confirm: … }`. The engine layout loads only
Bootstrap. It does not load Turbo or rails-ujs. Thus no dialog opens. One click
restores the record immediately.

- [ ] Load Turbo, or use `data: { turbo_confirm: … }`, or add your own JavaScript.
- [ ] Test the dialog.

### R6 - Clear the class caches at code reload - **Medium**

`app/models/paper_trail_history/trackable_model.rb:14-31,75`,
`app/models/paper_trail_history/version_service.rb:82`

`@all_models` and `@all_version_classes` hold class objects. Rails reloads the
code in development. The caches then hold old classes. This gives wrong data and
holds memory. The memoization is also not thread-safe.

- [ ] Call `clear_cache!` from a `to_prepare` hook in the engine.
- [ ] Protect the write with a mutex.

### R7 - Use the primary key of the model - **Low**

`app/controllers/paper_trail_history/records_controller.rb:35`

`find_by(id: …)` does not work for a model with a different primary key.

- [ ] Use `klass.find_by(klass.primary_key => params[:record_id])`.

### R8 - Give back the correct record after a restore - **Low**

`app/models/paper_trail_history/version_service.rb:167`

`restore_previous_version` gives `version.item`. This object is the old object in
memory. It does not show the new values.

- [ ] Reload the item, or give back the object from `reify`.

---

## 3. Performance

### P1 - Add pagination - **Critical**

`app/controllers/paper_trail_history/models_controller.rb:42`,
`app/controllers/paper_trail_history/records_controller.rb:45`

The controller reads all versions of a model into memory and decorates each row.
A production table with one million versions makes the page unusable. The process
can also run out of memory. The `page` parameter is permitted, but no code uses
it. The README says "Pagination support".

- [ ] Add pagination with LIMIT and OFFSET. Show page links.

### P2 - Do not load all rows for the filter lists - **High**

`app/models/paper_trail_history/version_service.rb:44-70`

If `model_name` is `nil`, `unique_whodunnits` and `available_events` call `.all`
on each version class. The code loads all rows into memory and then maps them in
Ruby.

- [ ] Use `distinct.pluck` on the database for each class. Then join the results.

### P3 - Remove the N+1 queries - **High**

`app/controllers/paper_trail_history/records_controller.rb:45`,
`app/controllers/paper_trail_history/models_controller.rb:18`,
`app/views/paper_trail_history/shared/_versions_table.html.erb:37`

`item_display_name` reads `version.item` for each row. Only
`ModelsController#versions` uses `includes(:item)`. The other three actions do
not.

- [ ] Add `includes(:item)` to each query that shows the item name.

### P4 - Remove the unnecessary COUNT query - **Low**

`app/views/paper_trail_history/models/versions.html.erb:11`,
`app/views/paper_trail_history/records/versions.html.erb:17`

The view calls `@versions.count`. This starts a second database query. The rows
are already in memory.

- [ ] Use `size` on the decorated array, or the total from the pagination.

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

### Q4 - Move the CSS and the JavaScript out of the layout - **Low**

`app/views/layouts/paper_trail_history/application.html.erb`

80 lines of CSS and 16 lines of JavaScript are in the layout file. Task S4 needs
this change also.

- [ ] Put the CSS and the JavaScript into asset files.

### Q5 - Localize the texts of the views - **Medium**

All view files, `app/models/paper_trail_history/version_decorator.rb:27,86-102`

The engine has `en.yml` and `de.yml`. But all texts in the views are English
strings in the code ("Version Details", "Restore This Version").
`formatted_created_at` uses a fixed US format. The texts `(empty)` and `(blank)`
are not in the locale files.

- [ ] Move all texts to the locale files.
- [ ] Use `I18n.l` for the date and the time.

### Q6 - Remove the placeholder comment - **Low**

`lib/paper_trail_history.rb:14` has `# Your code goes here...`.

- [ ] Remove the comment.

### Q7 - Remove the build artifacts - **Low**

`paper_trail_history-0.2.0.gem` and `paper_trail_history-0.2.1.gem` are in the
working directory. `.gitignore` does not have them.

- [ ] Add `*.gem` to `.gitignore`.
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

### D2 - Correct the version numbers in the documents - **High**

`README.md:40,181-183`, `CLAUDE.md`

The README says "Rails >= 7.2". The gemspec needs Rails >= 8.0 and Ruby >= 3.3.0.
CLAUDE.md says "Rails >= 7.2, Ruby >= 3.1.0". The README tells the user to use
`gemfiles/rails_7.2.gemfile`. This file does not exist.

- [ ] Correct the README and CLAUDE.md.
- [ ] Remove the Rails 7.2 instructions.

### D3 - Correct the wrong feature claims - **Low**

`README.md`

The README lists "Pagination support", but the code has no pagination (see P1).
The README shows the mount path `/revisions`, but then it tells the user to open
`http://localhost:3000/paper_trail_history`.

- [ ] Correct the two statements.

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

### T4 - Add controller tests for `RecordsController` - **Medium**

There is no test file for this controller.

- [ ] Add `test/controllers/paper_trail_history/records_controller_test.rb`.

### T5 - Add coverage and security checks to the CI - **Medium**

`.github/workflows/ci.yml`

- [ ] Add SimpleCov with a minimum value.
- [ ] Add a `bundler-audit` step and a `brakeman` step.

### T6 - Repair the local development environment - **Low** - DONE

`bundle exec rubocop` and `bundle exec rake test` did not run on the review
machine. Five gems were not installed (`bigdecimal-4.0.0`, `timeout-0.5.0`,
`net-imap-0.6.0`, `rdoc-6.17.0`, `psych-5.3.0`).

- [x] Run `bundle install` before the next check.
