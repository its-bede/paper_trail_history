# frozen_string_literal: true

class CreateProducts < ActiveRecord::Migration[7.2]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.string :sku, null: false
      t.decimal :price, precision: 10, scale: 2, null: false
      t.text :description
      t.integer :category, default: 0
      t.integer :stock_quantity, default: 0
      t.boolean :active, default: true

      t.timestamps
    end

    add_index :products, :sku, unique: true
    add_index :products, :category
  end
end
