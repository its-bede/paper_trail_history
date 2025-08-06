# frozen_string_literal: true

# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 20_250_806_006) do
  create_table 'comments', force: :cascade do |t|
    t.text 'content', null: false
    t.boolean 'approved', default: false
    t.integer 'user_id', null: false
    t.integer 'post_id', null: false
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['approved'], name: 'index_comments_on_approved'
    t.index ['post_id'], name: 'index_comments_on_post_id'
    t.index ['user_id'], name: 'index_comments_on_user_id'
  end

  create_table 'posts', force: :cascade do |t|
    t.string 'title', null: false
    t.text 'content', null: false
    t.integer 'status', default: 0
    t.boolean 'featured', default: false
    t.integer 'view_count', default: 0
    t.integer 'user_id', null: false
    t.datetime 'published_at'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['featured'], name: 'index_posts_on_featured'
    t.index ['status'], name: 'index_posts_on_status'
    t.index ['user_id'], name: 'index_posts_on_user_id'
  end

  create_table 'product_versions', force: :cascade do |t|
    t.string 'item_type', null: false
    t.bigint 'item_id', null: false
    t.string 'event', null: false
    t.string 'whodunnit'
    t.text 'object', limit: 1_073_741_823
    t.text 'object_changes', limit: 1_073_741_823
    t.datetime 'created_at'
    t.index ['created_at'], name: 'index_product_versions_on_created_at'
    t.index %w[item_type item_id], name: 'index_product_versions_on_item_type_and_item_id'
  end

  create_table 'products', force: :cascade do |t|
    t.string 'name', null: false
    t.string 'sku', null: false
    t.decimal 'price', precision: 10, scale: 2, null: false
    t.text 'description'
    t.integer 'category', default: 0
    t.integer 'stock_quantity', default: 0
    t.boolean 'active', default: true
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['category'], name: 'index_products_on_category'
    t.index ['sku'], name: 'index_products_on_sku', unique: true
  end

  create_table 'users', force: :cascade do |t|
    t.string 'name', null: false
    t.string 'email', null: false
    t.text 'bio'
    t.boolean 'active', default: true
    t.datetime 'last_login_at'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['email'], name: 'index_users_on_email', unique: true
  end

  create_table 'versions', force: :cascade do |t|
    t.string 'item_type', null: false
    t.bigint 'item_id', null: false
    t.string 'event', null: false
    t.string 'whodunnit'
    t.text 'object', limit: 1_073_741_823
    t.text 'object_changes', limit: 1_073_741_823
    t.datetime 'created_at'
    t.index ['created_at'], name: 'index_versions_on_created_at'
    t.index %w[item_type item_id], name: 'index_versions_on_item_type_and_item_id'
  end

  add_foreign_key 'comments', 'posts'
  add_foreign_key 'comments', 'users'
  add_foreign_key 'posts', 'users'
end
