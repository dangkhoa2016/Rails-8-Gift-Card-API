Rails.application.routes.draw do
  # Optional reviewer UI: static Vue 3 global build, no frontend pipeline.
  get "demo", to: redirect("/demo/index.html")
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      post "auth/login", to: "auth#login"
      post "auth/logout", to: "auth#logout"
      namespace :admin do
        resources :brands, only: [ :index, :show, :create, :update ] do
          resources :products, only: [ :index, :create ]
        end
        resources :products, only: [ :show, :update, :destroy ]
        get "audit_logs", to: "audit_logs#index"
        get "reports/by_brand", to: "reports#by_brand"
        get "reports/by_client", to: "reports#by_client"
        resources :clients, only: [ :index, :show, :create, :update ] do
          resources :product_accesses, only: [ :index, :create, :destroy ]
        end
      end
      namespace :client do
        get "catalog", to: "catalog#index"
        get "reports/spending", to: "reports#spending"
        resources :cards, only: [ :index, :show, :create ] do
          post :cancel, on: :member
        end
      end
    end
  end
end
