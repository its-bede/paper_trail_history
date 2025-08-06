# frozen_string_literal: true

class Product < ApplicationRecord
  has_paper_trail versions: { class_name: 'ProductVersion' }

  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :sku, presence: true, uniqueness: true

  enum :category, { electronics: 0, clothing: 1, books: 2, home: 3 }
end
