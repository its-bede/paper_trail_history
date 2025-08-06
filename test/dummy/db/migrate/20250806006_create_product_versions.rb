# frozen_string_literal: true

class CreateProductVersions < ActiveRecord::Migration[7.2]
  def change
    create_table :product_versions do |t|
      t.string   :item_type, null: false
      t.bigint   :item_id,   null: false
      t.string   :event,     null: false
      t.string   :whodunnit
      t.text     :object, limit: 1_073_741_823
      t.text     :object_changes, limit: 1_073_741_823

      t.datetime :created_at
    end

    add_index :product_versions, %i[item_type item_id]
    add_index :product_versions, :created_at
  end
end
