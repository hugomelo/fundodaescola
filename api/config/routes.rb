Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    post "auth/login", to: "sessions#create"
    post "auth/forgot_password", to: "password_resets#create"
    post "auth/reset_password", to: "password_resets#update"
    get   "me", to: "me#show"
    patch "me", to: "me#update"

    # Parent-facing (scoped to the current user's access)
    resources :students, only: [] do
      member do
        get :summary
        get :payments
      end
    end
    get "grades/:id/overview", to: "grades#overview"
    get "grades/:id/cost_plan", to: "grades#cost_plan"

    # Admin-facing
    namespace :admin do
      resources :grades do
        resources :students, only: [:index, :create]
        resources :payer_mappings, only: [:index, :create]
        resources :investment_entries, only: [:index, :create]
        resources :events, only: [:index, :create]
        resources :trips, only: [:index, :create]
        resources :payments, only: [:index, :create] do
          collection { post :import }
        end
        member { get :dashboard }
      end
      resources :students, only: [:show, :update, :destroy] do
        resources :monthly_pledges, only: [:index, :create], controller: "pledges"
      end
      resources :monthly_pledges, only: [:update, :destroy], controller: "pledges"
      resources :payments, only: [:update, :destroy]
      resources :payer_mappings, only: [:update, :destroy]
      resources :investment_entries, only: [:update, :destroy]
      resources :events, only: [:update, :destroy]
      resources :trips, only: [:update, :destroy] do
        resources :cost_entries, only: [:create], controller: "trip_cost_entries"
      end
      resources :trip_cost_entries, only: [:update, :destroy]
      resources :users
    end
  end
end
