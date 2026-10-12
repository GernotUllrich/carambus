# frozen_string_literal: true

require "test_helper"
require "erb"

# Plan 17-04: Die Turnier-App liegt in jedem Release unter public/app/. Ob /app/ ausgeliefert
# wird, entscheidet allein das nginx-Template nach serve_tournament_app — vorher war der Schalter
# der Kopierschritt in scenario:prepare_deploy. Gerendert wird wie in generate_nginx_conf
# (lib/tasks/scenarios.rake): @scenario, @config, @environment im Binding.
class NginxConfTemplateTest < ActiveSupport::TestCase
  TEMPLATE = Rails.root.join("templates", "nginx", "nginx_conf.erb")

  def render(serve_tournament_app:, ssl_enabled:)
    @scenario = {"basename" => "carambus_test"}
    @scenario["serve_tournament_app"] = true if serve_tournament_app
    @config = {"webserver_port" => 3131, "webserver_host" => "test.example", "ssl_enabled" => ssl_enabled}
    @environment = "production"
    ERB.new(File.read(TEMPLATE)).result(binding)
  end

  def app_location(conf)
    conf[%r{location (\^~ )?/app/ \{.*?\n    \}}m]
  end

  [true, false].each do |ssl|
    test "mit serve_tournament_app liefert nginx /app/ aus dem Release aus (ssl=#{ssl})" do
      location = app_location(render(serve_tournament_app: true, ssl_enabled: ssl))

      assert location, "location /app/ fehlt"
      assert_includes location, "root /var/www/carambus_test/current/public;"
      assert_includes location, "try_files"
      refute_includes location, "return 404"
    end

    test "ohne serve_tournament_app antwortet nginx auf /app/ mit 404 (ssl=#{ssl})" do
      conf = render(serve_tournament_app: false, ssl_enabled: ssl)
      location = app_location(conf)

      assert location, "location /app/ fehlt — ohne sie griffe location / und lieferte public/app/ aus"
      assert_match(/location \^~ \/app\/ \{\s*return 404;/, location)
      assert_equal 1, conf.scan(%r{location (\^~ )?/app/ }).size, "genau ein /app/-Block je Server"
    end
  end
end
