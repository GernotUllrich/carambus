# For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
Rails.application.routes.draw do
 devise_for :users,
             controllers: {
               registrations: 'registrations'
             },
             path: '',
             path_names: {
               sign_in: 'login',
               sign_out: 'logout',
               registration: 'users',
               edit: 'edit'
             }

  resources :table_locals
  resources :slots
  resources :uploads
  resources :discipline_phases
  resources :party_monitors do
    member do
      get :upload_form
      get :upload_form
    end
  end
  resources :game_plans
  resources :versions do
    collection do
      get :get_updates
      get :last_version
      get :current_revision
      post :update_carambus
    end
  end
  resources :club_locations
  resources :discipline_ccs
  resources :tournament_series_ccs
  resources :tournament_ccs
  resources :tournament_series_ccs do
    collection do
      get :synchronize
    end
  end
  resources :registration_list_ccs
  resources :registration_ccs
  resources :group_ccs
  resources :championship_type_ccs
  resources :category_ccs
  resources :ion_modules
  resources :ion_contents
  resources :game_plan_ccs
  resources :game_plan_row_ccs
  resources :meta_maps
  resources :party_game_ccs
  resources :party_ccs
  resources :league_team_ccs
  resources :league_ccs
  resources :season_ccs
  resources :competition_ccs
  resources :branch_ccs
  resources :region_ccs do
    member do
      get :check
      post :fix
      get :check_branch_cc
      post :fix_branch_cc
      get :check_competition_cc
      post :fix_competition_cc
      get :check_party_cc
      post :fix_party_cc
      get :check_party_game_cc
      post :fix_party_game_cc
      get :check_league_cc
      post :fix_league_cc
      get :check_league_team_cc
      post :fix_league_team_cc
      get :check_season_cc
      post :fix_season_cc
      get :check_game_plan_cc
      post :fix_game_plan_cc
    end
  end
  resources :party_games
  resources :parties do
    member do
      get :party_monitor
    end
  end
  resources :league_teams
  resources :leagues do
    member do
      post :reload_from_ba
      post :reload_from_ba_with_details
    end
  end
  resources :seedings do
    member do
      post :up
      post :down
      get :up
      get :down
    end
  end
  resources :table_monitors do
    member do
      post :set_balls
      post :add_one
      post :add_ten
      post :minus_one
      post :minus_ten
      post :next_step
      get :next_step
      post :start_game
      get :start_game
      post :evaluate_result
      get :evaluate_result
      post :undo
      post :up
      post :down
      get :up
      get :down
      get :toggle_dark_mode
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
  resources :player_classes
  resources :player_rankings
  resources :player_tournament_participations
  resources :locations do
    collection do
      post :merge
    end
    member do
      post :create_event
      post :add_tables_to
      post :placement
      post :game_results
      post :new_league_tournament
      get :game_results
      get :placement
      get :scoreboard
      get :toggle_dark_mode
    end
  end
  resources :seasons
  resources :table_kinds
  resources :disciplines do
    collection do
      post :merge
    end
  end
  resources :tournaments do
    member do
      post :order_by_ranking_or_handicap
      post :select_modus
      post :start
      post :reset
      get :finalize_modus
      get :tournament_monitor
      post :reload_from_ba
      post :finish_seeding
      get :define_participants
      post :placement
      get :placement
      get :new_team
      post :add_team
    end
  end
  resources :users
  resources :season_participations
  resources :game_participations
  resources :games
  resources :tournament_plans
  resources :tables
  resources :seedings do
    member do
      post :down
      post :up
    end
  end

  resources :players do
    member do
      post :create_admin
    end
    collection do
      post :merge
    end
  end
  resources :clubs do
    member do
      get :get_club_details
      post :reload_from_ba
      post :reload_from_ba_with_details
      post :new_club_tournament
      get :new_club_location
      get :new_club_guest
      post :add_club_guest
    end
    collection do
      post :merge
    end
  end
  resources :regions do
    member do
      get :get_club_selector
      post :reload_from_ba
      post :reload_from_ba_with_details
      post :reload_tournaments
      post :reload_leagues
      post :reload_leagues_with_details
      get :migration_cc
      post :set_base_parameters
    end
  end
  resources :countries

  scope controller: :static do
    get :start
    get :intro
    get :about
    get :terms
    get :privacy
    get :pricing
    get :index_t
    get :training
  end

  match "/404", to: "errors#not_found", via: :all
  match "/500", to: "errors#internal_server_error", via: :all
  get "/intro", to: "static#intro"
  get "/about", to: "static#about"
  get "/repo_version", to: "static#repo_version"
  get "/doc_tournament", to: "static#tournament"
  get "/doc/league", to: "static#league"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", :as => :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", :as => :pwa_manifest

  # Public marketing homepage
  root to: "static#index"
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'home#index'

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

  namespace :admin do
    resources :users
    # resources :other_models
    root to: "users#index"
  end

  scope module: :users do
    resource :profile, only: [:edit, :update], controller: 'profiles'
  end
end
