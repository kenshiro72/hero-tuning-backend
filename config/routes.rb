Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes
  namespace :api do
    namespace :v1 do
      resources :characters, only: [:index, :show] do
        member do
          post 'optimize'
        end
      end
      resources :costumes, only: [:index, :show] do
        member do
          get 'effects'
          post 'unequip_all'
          post 'apply_configuration'
        end
      end
      resources :memories, only: [:index]
      resources :slots, only: [] do
        member do
          post 'equip'
          post 'unequip'
          post 'level_up'
          post 'level_down'
        end
      end
    end
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
