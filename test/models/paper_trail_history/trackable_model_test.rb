# frozen_string_literal: true

require 'test_helper'

module PaperTrailHistory
  class TrackableModelTest < ActiveSupport::TestCase
    test 'uses the name of the base class for the item type of a subclass' do
      assert_equal 'User', TrackableModel.find('Admin').item_type_for_versions
    end

    test 'finds the versions of a subclass' do
      admin = Admin.create!(name: 'Grace', email: "sti-#{SecureRandom.hex(4)}@example.com")

      assert_includes TrackableModel.find('Admin').versions.map(&:item_id), admin.id
    end

    test 'does not give the versions of the base class to a subclass' do
      plain_user = User.create!(name: 'Plain', email: "sti-#{SecureRandom.hex(4)}@example.com")

      assert_not_includes TrackableModel.find('Admin').versions.map(&:item_id), plain_user.id
    end

    test 'gives the versions of a subclass to the base class' do
      admin = Admin.create!(name: 'Grace', email: "sti-#{SecureRandom.hex(4)}@example.com")

      assert_includes TrackableModel.find('User').versions.map(&:item_id), admin.id
    end

    test 'counts only the versions of a subclass' do
      Admin.create!(name: 'Grace', email: "sti-#{SecureRandom.hex(4)}@example.com")
      User.create!(name: 'Plain', email: "sti-#{SecureRandom.hex(4)}@example.com")

      assert_equal Admin.count, TrackableModel.find('Admin').total_versions_count
    end

    test 'counts the versions of a subclass in the list of all models' do
      Admin.create!(name: 'Grace', email: "sti-#{SecureRandom.hex(4)}@example.com")

      model = TrackableModel.all_with_counts.find { |trackable| trackable.name == 'Admin' }

      assert_equal Admin.count, model.total_versions_count
    end

    test 'uses only the item type when the version table has no item subtype' do
      trackable_model = TrackableModel.find('Admin')
      columns = PaperTrail::Version.column_names - ['item_subtype']

      PaperTrail::Version.stub(:column_names, columns) do
        assert_no_match(/item_subtype/, trackable_model.versions.to_sql)
      end
    end

    test 'finds every model of the dummy application that uses PaperTrail' do
      assert_equal %w[Admin Comment Post Product User], TrackableModel.all.map(&:name)
    end

    test 'finds a model by name' do
      assert_equal 'User', TrackableModel.find('User').name
    end

    test 'gives nil for a model that does not exist' do
      assert_nil TrackableModel.find('NonExistentModel')
    end

    test 'gives the versions of the model' do
      user = User.create!(name: 'Ada', email: "tm-#{SecureRandom.hex(4)}@example.com")

      assert_includes TrackableModel.find('User').versions.map(&:item_id), user.id
    end

    test 'gives no version of another model' do
      author = User.create!(name: 'Ada', email: "tm-#{SecureRandom.hex(4)}@example.com")
      Post.create!(title: 'Hello', content: 'World', user: author)

      assert_equal ['Post'], TrackableModel.find('Post').versions.map(&:item_type).uniq
    end

    test 'gives the human name of the model in plural' do
      assert_equal User.model_name.human(count: 2), TrackableModel.find('User').human_name
    end

    test 'gives the table name of the model' do
      assert_equal 'users', TrackableModel.find('User').table_name
    end

    test 'gives the version table of a model with its own version class' do
      assert_equal 'product_versions', TrackableModel.find('Product').version_table_name
    end
  end
end
