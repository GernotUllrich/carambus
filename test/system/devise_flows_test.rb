# frozen_string_literal: true

require "application_system_test_case"

# D-41-A Wave-0 Skeleton (VALIDATION.md Pflichtlieferung).
# Plan-05 (Wave-3) fuellt diese Klasse mit 4 E2E-System-Tests fuer die
# Devise-Flows (Sign-up, Forgot, Change-Password, Email-Change).
# MailHelpers ist via test_helper.rb in ApplicationSystemTestCase included,
# daher kein extend-Workaround noetig.
class DeviseFlowsTest < ApplicationSystemTestCase
  # Plan-05 fuellt: 4 Tests mit Capybara + Mail-Token-Click-Through
end
