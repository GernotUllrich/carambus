# frozen_string_literal: true

# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/javascript/channels", under: "channels"
pin_all_from "app/javascript/src", under: "src"
pin_all_from "app/javascript/utils", under: "utils"
pin_all_from "app/javascript/utilities", under: "utilities"
pin "@rails/activestorage", to: "activestorage.esm.js"
pin "local-time", to: "local-time"
pin "@stimulus_reflex/polyfills", to: "stimulus_reflex_polyfills.js"
