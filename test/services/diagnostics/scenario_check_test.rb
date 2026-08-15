# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"

# Deckt den statischen Szenario-Abgleich ab — vor allem die BEZIEHUNGSFEHLER, die Step 1.5 in
# bin/deploy-scenario.sh nicht sehen kann, weil er jeweils nur ein Szenario betrachtet.
class Diagnostics::ScenarioCheckTest < ActiveSupport::TestCase
  def setup
    @dir = Dir.mktmpdir("scenario-check")
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  test "vollstaendige Kette meldet keine Blocker" do
    write_scenario("carambus_api", cap_role: "api", context: "API",
      features: %w[ai clubcloud], region_server_contexts: ["TBV"])
    write_scenario("carambus_tbv", context: "tbv", features: %w[ai])
    write_scenario("carambus_ebc", context: "TBV", location_id: 2426, features: %w[ai],
      region_server_contexts: ["TBV"])
    write_secrets("tbv")

    checks = run_check
    assert_empty failed(checks), failed(checks).map(&:detail).join(" | ")
    assert_includes checks.map(&:detail).join(" "), "carambus_ebc → carambus_tbv → carambus_api"
  end

  test "Authority ohne den Kontext des Region Servers ist ein Blocker" do
    write_scenario("carambus_api", cap_role: "api", context: "API",
      features: %w[ai clubcloud], region_server_contexts: ["NBV"])
    write_scenario("carambus_tbv", context: "tbv", features: %w[ai])
    write_scenario("carambus_ebc", context: "TBV", location_id: 2426, features: %w[ai],
      region_server_contexts: ["TBV"])
    write_secrets("tbv", "nbv")

    detail = failed(run_check).map(&:detail).join(" ")
    assert_match(/fuehrt TBV nicht in region_server_contexts/, detail)
  end

  test "CC-loser Location Server ohne Region-Server-Szenario ist ein Blocker" do
    write_scenario("carambus_api", cap_role: "api", context: "API", features: %w[ai])
    write_scenario("carambus_ebc", context: "TBV", location_id: 2426, features: %w[ai],
      region_server_contexts: ["TBV"])
    write_secrets("tbv")

    detail = failed(run_check).map(&:detail).join(" ")
    assert_match(/kein Region-Server-Szenario fuer context=TBV/, detail)
  end

  # Der Fall, den der Betreiber ausdruecklich korrigiert hat: wo die ClubCloud fuehrt, laeuft der
  # Rueckweg ueber sie — ein Region-Server-Zugang waere dort ueberfluessig.
  test "Location Server MIT ClubCloud braucht keinen Region-Server-Zugang" do
    write_scenario("carambus_api", cap_role: "api", context: "API", features: %w[ai])
    write_scenario("carambus_bcw", context: "NBV", location_id: 1, features: %w[ai clubcloud])

    checks = run_check
    assert_empty failed(checks), failed(checks).map(&:detail).join(" | ")
  end

  test "nicht angepasste Kopie wird erkannt" do
    write_scenario("carambus_ebc", context: "TBV", location_id: 2426, features: %w[ai clubcloud],
      declared_name: "carambus_phat", basename: "carambus_phat",
      database_name: "carambus_phat_production")

    detail = failed(run_check).map(&:detail).join(" ")
    assert_match(/Namen passen nicht/, detail)
    assert_match(/basename=carambus_phat/, detail)
  end

  test "deklarierter Kontext ohne Eintrag in secrets.yml ist ein Blocker" do
    write_scenario("carambus_api", cap_role: "api", context: "API", features: %w[ai],
      region_server_contexts: ["TBV"])
    write_scenario("carambus_tbv", context: "tbv", features: %w[ai])
    write_secrets # leer

    detail = failed(run_check).map(&:detail).join(" ")
    assert_match(/kein Eintrag in secrets\.yml/, detail)
  end

  private

  def run_check = Diagnostics::ScenarioCheck.new(data_path: @dir).call

  def failed(checks) = checks.select(&:failed?)

  def write_scenario(name, context: nil, location_id: nil, cap_role: "local", features: [],
    region_server_contexts: nil, declared_name: nil, basename: nil, database_name: nil)
    dir = File.join(@dir, "scenarios", name)
    FileUtils.mkdir_p(dir)
    scenario = {
      "name" => declared_name || name,
      "basename" => basename || name,
      "context" => context,
      "location_id" => location_id,
      "credentials" => {"features" => features}.tap do |c|
        c["region_server_contexts"] = region_server_contexts if region_server_contexts
      end
    }.compact
    config = {
      "scenario" => scenario,
      "environments" => {"production" => {
        "cap_role" => cap_role,
        "database_name" => database_name || "#{name}_production"
      }}
    }
    File.write(File.join(dir, "config.yml"), config.to_yaml)
  end

  def write_secrets(*contexts)
    entries = contexts.to_h { |c| [c, {"username" => "u@example.com", "password" => "x"}] }
    File.write(File.join(@dir, "secrets.yml"),
      {"shared" => {"region_server" => entries}}.to_yaml)
  end
end
