# frozen_string_literal: true

class Comment < ApplicationRecord
  has_paper_trail

  validates :content, presence: true

  belongs_to :user
  belongs_to :post
end
