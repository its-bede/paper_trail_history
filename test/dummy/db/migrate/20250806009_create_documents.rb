# frozen_string_literal: true

# A model with a primary key that is not called id. The engine must find such a
# record too, thus the dummy application has one.
class CreateDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :documents, id: false, primary_key: :uuid do |t|
      t.string :uuid, null: false
      t.string :title
      t.timestamps
    end

    add_index :documents, :uuid, unique: true
  end
end
