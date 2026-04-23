# frozen_string_literal: true

require "test_helper"

# Smoke tests for admin Show pages. Purpose: catch v0.9-Phase-D
# residues (stale dashboard fields, missing dashboards, Administrate
# × Rails 7.1 incompatibilities) at CI time rather than at browser
# time. These are render-gate tests only — no content assertions.
#
# Scope: 4 admin dashboards actually mounted under namespace :admin
# in config/routes.rb. The dashboards ball_configurations and
# start_positions are NOT routed (deferred, carambus_api-scope).
class AdminViewsSmokeTest < ActionDispatch::IntegrationTest
  DASHBOARDS = %i[training_examples training_concepts shots training_sources].freeze

  DASHBOARDS.each do |resource|
    test "admin #{resource} Index renders with HTTP 200" do
      get "/admin/#{resource}"
      assert_response :success
      assert_not_includes response.body, "We're sorry, but something went wrong"
    end

    test "admin #{resource} Show renders with HTTP 200 for first record (or skips if none)" do
      klass = resource.to_s.classify.constantize
      record = klass.order(:id).first
      skip "No #{klass} record in test DB — cannot test Show" if record.nil?
      get "/admin/#{resource}/#{record.id}"
      assert_response :success
      assert_not_includes response.body, "We're sorry, but something went wrong"
    end
  end
end
