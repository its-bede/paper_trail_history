Rails.application.routes.draw do
  mount PaperTrailHistory::Engine => "/paper_trail_history"
end
