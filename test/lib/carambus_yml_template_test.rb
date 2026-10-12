# frozen_string_literal: true

require "test_helper"
require "erb"

# Plan 17-06: Die Turnierseite zeigt den Knopf „In der Turnier-App öffnen“ nur, wo der Server
# /app/ ausliefert. Rails erfährt das über denselben Schalter wie nginx (serve_tournament_app),
# den das carambus.yml-Template aus der Szenario-config.yml übernimmt. Gerendert wird wie in
# generate_carambus_yml (lib/tasks/scenarios.rake): @scenario, @config, @environment im Binding.
class CarambusYmlTemplateTest < ActiveSupport::TestCase
  TEMPLATE = Rails.root.join("templates", "carambus", "carambus.yml.erb")

  def render(scenario)
    @scenario = {"basename" => "carambus_test", "name" => "carambus_test"}.merge(scenario)
    @config = {"webserver_host" => "test.example", "webserver_port" => 3131}
    @environment = "production"
    YAML.safe_load(ERB.new(File.read(TEMPLATE)).result(binding))
  end

  test "mit serve_tournament_app steht der Schalter auf true" do
    assert_equal true, render("serve_tournament_app" => true)["default"]["serve_tournament_app"]
  end

  test "ohne serve_tournament_app steht der Schalter auf false" do
    assert_equal false, render({})["default"]["serve_tournament_app"]
  end
end
