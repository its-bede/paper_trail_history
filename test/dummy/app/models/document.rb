# frozen_string_literal: true

# Uses a primary key that is not called id. PaperTrail writes the value of the
# primary key into item_id, thus the engine must look the record up by the
# primary key of the model and not by an id column.
class Document < ApplicationRecord
  self.primary_key = 'uuid'

  has_paper_trail

  validates :title, presence: true
end
