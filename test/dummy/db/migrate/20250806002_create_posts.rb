# frozen_string_literal: true

class CreatePosts < ActiveRecord::Migration[7.2]
  def change
    create_table :posts do |t|
      t.string :title, null: false
      t.text :content, null: false
      t.integer :status, default: 0
      t.boolean :featured, default: false
      t.integer :view_count, default: 0
      t.references :user, null: false, foreign_key: true
      t.datetime :published_at

      t.timestamps
    end

    add_index :posts, :status
    add_index :posts, :featured
  end
end
