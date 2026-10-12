# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "rake"

# config.hosts entscheidet, wer den Server ueberhaupt erreicht (Rails' DNS-Rebinding-Schutz).
# Feste Adressen altern: Der Pi in carambus_phat wechselte am 2026-09-16 von der WLAN- auf die
# LAN-Adresse (.84 -> .177), der Eintrag zeigte danach ins Leere und Tablets im Clubnetz bekamen
# 403. Seitdem kann die Szenario-config.yml ein `lan_subnet` deklarieren.
class ProductionRbHostsTest < ActiveSupport::TestCase
  def setup
    # scenarios.rake definiert seine Helfer als Methoden auf Object, braucht dafuer aber die
    # Rake-DSL (`namespace`) — deshalb ueber load_tasks statt `load`. Einmal pro Prozess.
    Rails.application.load_tasks unless Rake::Task.task_defined?("scenario:generate_configs")
  end

  def generate(env_config)
    scenario = {"scenario" => {"basename" => "carambus_test"}}
    config = {"webserver_host" => "pi.local", "webserver_port" => 3131}.merge(env_config)
    Dir.mktmpdir do |dir|
      send(:generate_production_rb_env, scenario, config, dir)
      File.read(File.join(dir, "production.rb"))
    end
  end

  test "ohne lan_subnet bleibt die hosts-Liste unveraendert" do
    content = generate({})

    assert_includes content, %(config.hosts << "pi.local")
    refute_includes content, "IPAddr"
  end

  test "lan_subnet ergaenzt das Netz als IPAddr" do
    content = generate("lan_subnet" => "192.168.178.0/24")

    assert_includes content, %(require "ipaddr")
    assert_includes content, %(config.hosts << IPAddr.new("192.168.178.0/24"))
  end

  test "mehrere Subnetze werden einzeln eingetragen" do
    content = generate("lan_subnet" => ["192.168.178.0/24", "10.0.0.0/8"])

    assert_includes content, %(config.hosts << IPAddr.new("192.168.178.0/24"))
    assert_includes content, %(config.hosts << IPAddr.new("10.0.0.0/8"))
    assert_equal 1, content.scan(%(require "ipaddr")).size
  end

  test "das erzeugte production.rb ist syntaktisch gueltig" do
    content = generate("lan_subnet" => "192.168.178.0/24")

    assert RubyVM::InstructionSequence.compile(content), "production.rb nicht parsebar"
  end
end
