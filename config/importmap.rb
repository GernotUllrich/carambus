# Pin npm packages by running ./bin/importmap

pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true

# Pin individual controllers
pin "controllers/application", to: "controllers/application.js", preload: true
pin "controllers/test_controller", to: "controllers/test_controller.js", preload: true
pin "controllers/karambol_game_controller", to: "controllers/karambol_game_controller.js", preload: true
pin "controllers/karambol_settings_controller", to: "controllers/karambol_settings_controller.js", preload: true
pin "controllers/game_settings_controller", to: "controllers/game_settings_controller.js", preload: true
pin "controllers/table_monitor_show_controller", to: "controllers/table_monitor_show_controller.js", preload: true
pin "controllers/scoreboard_start_controller", to: "controllers/scoreboard_start_controller.js", preload: true
pin "controllers/scoreboard_welcome_controller", to: "controllers/scoreboard_welcome_controller.js", preload: true
pin "controllers/table_monitor_controller", to: "controllers/table_monitor_controller.js", preload: true
pin "controllers/tournament_hotkeys_controller", to: "controllers/tournament_hotkeys_controller.js", preload: true
pin "controllers/search_parser_controller", to: "controllers/search_parser_controller.js", preload: true
pin "controllers/tippy_controller", to: "controllers/tippy_controller.js", preload: true
pin "controllers/filter_popup_controller", to: "controllers/filter_popup_controller.js", preload: true
pin "controllers/dropdown_controller", to: "controllers/dropdown_controller.js", preload: true
pin "controllers/markdown_editor_controller", to: "controllers/markdown_editor_controller.js", preload: true
pin "controllers/sidebar_controller", to: "controllers/sidebar_controller.js", preload: true
pin "controllers/application_controller", to: "controllers/application_controller.js", preload: true
pin "controllers/dark_mode_controller", to: "controllers/dark_mode_controller.js", preload: true
pin "controllers/hello_controller", to: "controllers/hello_controller.js", preload: true
pin "controllers/party_controller", to: "controllers/party_controller.js", preload: true
pin "controllers/tabmon_controller", to: "controllers/tabmon_controller.js", preload: true
pin "controllers/transition_controller", to: "controllers/transition_controller.js", preload: true

# Pin application
pin "application", preload: true 