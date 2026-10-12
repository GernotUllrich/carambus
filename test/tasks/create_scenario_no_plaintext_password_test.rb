# frozen_string_literal: true

require "test_helper"
require "rake"
require "tmpdir"
require "yaml"

# Plan 21-01: Das Passwort der GETEILTEN Postgres-Rolle www_data gehoert nicht in eine getrackte
# Datei. `create_scenario` schrieb es bis 2026-09-20 im Klartext in jede neu erzeugte config.yml —
# im Widerspruch zum Kommentarblock an `resolve_shared_database_password`, der ausdruecklich sagt,
# diese Felder seien LEER und der Wert komme aus carambus_data/secrets.yml.
#
# Dieser Test ist als ABSAGE formuliert: er haelt fest, dass das Feld leer BLEIBT. Setzt jemand
# den Wert zurueck in Z. 4130, wird er rot (Gegenprobe beim Apply gelaufen).
#
# Beide Helfer sind private Methoden auf Object (rake-DSL) und memoisieren pro Instanz in
# @scenarios_path / @carambus_data_path. Der Test setzt sie vorab auf ein tmp-Verzeichnis und
# fasst carambus_data damit nie an.
class CreateScenarioNoPlaintextPasswordTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  teardown do
    Rake::Task.clear
  end

  test "create_scenario schreibt kein Passwort in die neue config.yml" do
    Dir.mktmpdir do |tmp|
      @scenarios_path = tmp

      capture_io { send(:create_scenario, "carambus_probe", 5101, "local") }

      config = YAML.load_file(File.join(tmp, "carambus_probe", "config.yml"))
      production = config["environments"]["production"]

      assert_equal "www_data", production["database_username"],
        "Der Benutzer gehoert weiter in die config.yml — nur das Geheimnis nicht"
      assert_equal "", production["database_password"],
        "database_password muss LEER sein; der Wert kommt aus carambus_data/secrets.yml"

      # Kein anderer Schluessel darf das Geheimnis ersatzweise tragen.
      refute_match(/password.*\S/i, config.to_yaml.lines.grep(/password/).reject { |l|
        l.include?("database_password: ''") || l.match?(/database_password:\s*$/)
      }.join, "Es darf kein zweites, gefuelltes Passwort-Feld geben")
    end
  end

  test "resolve_shared_database_password nimmt den Wert aus secrets.yml, nicht aus der config.yml" do
    Dir.mktmpdir do |tmp|
      @carambus_data_path = tmp
      File.write(File.join(tmp, "secrets.yml"),
        {"shared" => {"database_password" => "wert-aus-secrets"}}.to_yaml)

      # Genau der Zustand, den create_scenario ab jetzt erzeugt: leeres Feld in der config.yml.
      production_config = {"database_password" => ""}

      assert_equal "wert-aus-secrets",
        send(:resolve_shared_database_password, production_config)
    end
  end

  test "resolve_shared_database_password liefert den leeren String, wenn es keine secrets.yml gibt" do
    Dir.mktmpdir do |tmp|
      @carambus_data_path = tmp # bewusst ohne secrets.yml

      assert_nothing_raised do
        assert_equal "", send(:resolve_shared_database_password, {"database_password" => ""})
      end
    end
  end

  # Der Fallback auf die config.yml bleibt erhalten — fuer Szenarien, die ihr Passwort doch dort
  # pflegen. Er ist nicht der Weg, aber er darf nicht stillschweigend verschwinden.
  test "resolve_shared_database_password faellt auf die config.yml zurueck, wenn secrets.yml nichts liefert" do
    Dir.mktmpdir do |tmp|
      @carambus_data_path = tmp
      File.write(File.join(tmp, "secrets.yml"), {"shared" => {"database_password" => ""}}.to_yaml)

      assert_equal "wert-aus-config",
        send(:resolve_shared_database_password, {"database_password" => "wert-aus-config"})
    end
  end
end
