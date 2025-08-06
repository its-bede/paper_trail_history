# frozen_string_literal: true

PaperTrailHistory::Engine.routes.draw do
  root 'models#index'

  resources :models, only: %i[index show], param: :name do
    member do
      get :versions
    end

    resources :records, only: [:show], param: :record_id do
      member do
        get :versions
      end
    end
  end

  resources :versions, only: [:show] do
    member do
      patch :restore
    end
  end
end
