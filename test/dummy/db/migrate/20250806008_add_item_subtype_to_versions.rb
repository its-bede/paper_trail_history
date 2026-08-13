# frozen_string_literal: true

# PaperTrail writes the name of the base class into item_type. The optional
# item_subtype column keeps the name of the real class, thus an application with
# single table inheritance can tell the subclasses apart.
class AddItemSubtypeToVersions < ActiveRecord::Migration[8.0]
  def change
    add_column :versions, :item_subtype, :string
    add_index :versions, %i[item_type item_subtype]
  end
end
