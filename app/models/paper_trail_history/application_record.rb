# frozen_string_literal: true

module PaperTrailHistory
  # Base ActiveRecord class for PaperTrailHistory models
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
