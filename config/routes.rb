Rails.application.routes.draw do

  resources :tournament_tables
  resources :tables
  scope :api, defaults: {format: :json} do
    scope :v1 do
      resources :games
    end
  end
  scope "(:locale)", locale: /en|de/ do
    resources :table_monitors do
      member do
        post :set_balls
        post :add_one
        post :add_ten
        post :next_step
        post :undo
        post :redo
        post :up
        post :down
      end
    end
    resources :settings do
      collection do
        get :club_settings
        post :update_club_settings
        get :tournament_settings
        post :update_tournament_settings
        post :manage_tournament
      end
    end

    resources :tournament_monitors do
      member do
        post :switch_players
        post :update_games
      end
    end
    resources :discipline_tournament_plans
    devise_for :users
    resources :users
    resources :player_classes
    resources :player_rankings
    resources :player_tournament_participations
    resources :locations do
      member do
        post :add_tables_to
      end
    end
    resources :seasons
    resources :table_kinds
    resources :disciplines
    resources :tournaments do
      member do
        post :order_by_ranking
        post :select_modus
        post :start
        post :reset
        get :finalize_modus
        get :tournament_monitor
        post :reload_from_ba
      end
    end
    resources :tournament_plan_games
    resources :season_participations
    resources :game_participations
    resources :games
    resources :tournament_plans
    resources :innings
    resources :seedings do
      member do
        post :down
        post :up
      end
    end
    resources :players
    resources :clubs do
      member do
        get :get_club_details
        post :reload_from_ba
        post :reload_from_ba_with_player_details
      end
    end
    resources :regions do
      member do
        get :get_club_selector
      end
    end
    resources :countries
    # The priority is based upon order of creation: first created -> highest priority.
    # See how all your routes lay out with "rake routes".

    # You can have the root of your site routed with "root"
    root 'home#index'

    # Example of regular route:
    #   get 'products/:id' => 'catalog#view'

    # Example of named route that can be invoked with purchase_url(id: product.id)
    #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

    # Example resource route (maps HTTP verbs to controller actions automatically):
    #   resources :products

    # Example resource route with options:
    #   resources :products do
    #     member do
    #       get 'short'
    #       post 'toggle'
    #     end
    #
    #     collection do
    #       get 'sold'
    #     end
    #   end

    # Example resource route with sub-resources:
    #   resources :products do
    #     resources :comments, :sales
    #     resource :seller
    #   end

    # Example resource route with more complex sub-resources:
    #   resources :products do
    #     resources :comments
    #     resources :sales do
    #       get 'recent', on: :collection
    #     end
    #   end

    # Example resource route with concerns:
    #   concern :toggleable do
    #     post 'toggle'
    #   end
    #   resources :posts, concerns: :toggleable
    #   resources :photos, concerns: :toggleable

    # Example resource route within a namespace:
    #   namespace :admin do
    #     # Directs /admin/products/* to Admin::ProductsController
    #     # (app/controllers/admin/products_controller.rb)
    #     resources :products
    #   end
  end
end
