# frozen_string_literal: true

class Post < ApplicationRecord
  has_paper_trail

  validates :title, presence: true
  validates :content, presence: true

  belongs_to :user
  has_many :comments, dependent: :destroy

  enum :status, { draft: 0, published: 1, archived: 2 }
end
