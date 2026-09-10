# frozen_string_literal: true

require "test_helper"

# host_vars aus der Szenario-config.yml (Plan 15-01).
#
# Die Soll-Werte der drei Szenario-Faelle sind der Ist-Stand vom 2026-09-10, gemessen per
# `ansible-inventory --host`. Der Generator muss ihn wertgleich reproduzieren — sonst aendert eine
# Neugenerierung still die Firewall eines laufenden Vereinsservers.
class ScenarioHostVarsTest < ActiveSupport::TestCase
  INVENTORY = <<~INI
    # Kommentar mit bc-wedel darin zaehlt nicht
    #api ansible_host=135.181.96.129
    carambus5 ansible_host=192.168.178.84 node_name=web5.carambus.de
    carambus-gu ansible_host=carambus-gu.local node_name=carambus-gu
    carambus-phat ansible_host=carambus-phat.local node_name=carambus-phat
    bc-wedel ansible_host=bc-wedel.duckdns.org node_name=bc-wedel.duckdns.org

    [webservers]
    carambus-gu
    nur-in-gruppe

    [nur-als-gruppe]
    carambus-gu

    [py3_hosts:vars]
    ansible_python_interpreter=/usr/bin/python3
  INI

  # So sehen die heutigen Dateien aus: Ansible-Schalter, dazwischen Kommentare und
  # handgepflegte Firewall-Werte, die kuenftig aus config.yml kommen.
  BC_WEDEL_EXISTING = <<~YAML
    ansible_port: 8910
    ansible_ssh_user: www-data
    bootstrap_done: true
    disable_mailings: true
    basic_install_done: false
    ispconfig_done: false

    # Firewall (gemessen 2026-09-08) ...
    firewall_extra_tcp_ports:
      - 3131
      - 3132
      - 5201
    ipv6_firewall: true
  YAML

  GU_EXISTING = <<~YAML
    ansible_port: 8910
    ansible_ssh_user: www-data
    bootstrap_done: true
    disable_mailings: true
    basic_install_done: true
    ispconfig_done: false
    initial_data_copy: false
    ipv6_firewall: true
    firewall_tcp_ports:
      - 3131
      - 8910
    firewall_udp_ports: []
    firewall_extra_tcp_ports: []
    full_stack_managed: false
    ansible_ssh_common_args: '-4'
  YAML

  def bc_wedel_config
    {"webserver_port" => 3131, "ssh_port" => 8910, "ssh_host" => "bc-wedel.duckdns.org",
     "ansible" => {"inventory_name" => "bc-wedel", "firewall_trimmed" => false,
                   "firewall_extra_tcp_ports" => [3132, 5201], "ipv6_firewall" => true}}
  end

  def gu_config(overrides = {})
    {"webserver_port" => 3131, "ssh_port" => 8910, "ssh_host" => "carambus-gu.local",
     "ansible" => {"inventory_name" => "carambus-gu", "firewall_trimmed" => true,
                   "firewall_extra_tcp_ports" => [], "ipv6_firewall" => true,
                   "full_stack_managed" => false}}.deep_merge(overrides)
  end

  def generator(config, existing: nil, inventory: INVENTORY, scenario_name: "carambus_test")
    ScenarioHostVars.new(scenario_name: scenario_name, production_config: config,
      existing: existing, inventory: inventory)
  end

  def rendered_hash(...)
    YAML.safe_load(generator(...).render)
  end

  # --- AC-1: die drei Szenarien wertgleich -----------------------------------------------------

  test "bc-wedel: Standardsatz plus webserver_port und Extra-Ports, Schalter erhalten" do
    expected = {
      "ansible_port" => 8910, "ansible_ssh_user" => "www-data", "bootstrap_done" => true,
      "disable_mailings" => true, "basic_install_done" => false, "ispconfig_done" => false,
      "firewall_extra_tcp_ports" => [3131, 3132, 5201], "ipv6_firewall" => true
    }
    assert_equal expected, rendered_hash(bc_wedel_config, existing: BC_WEDEL_EXISTING)
  end

  test "carambus-gu: Zuschnitt auf webserver_port und ssh_port, -4 wegen .local plus IPv6" do
    expected = {
      "ansible_port" => 8910, "ansible_ssh_user" => "www-data", "bootstrap_done" => true,
      "disable_mailings" => true, "basic_install_done" => true, "ispconfig_done" => false,
      "initial_data_copy" => false,
      "firewall_tcp_ports" => [3131, 8910], "firewall_udp_ports" => [], "firewall_extra_tcp_ports" => [],
      "ipv6_firewall" => true, "full_stack_managed" => false, "ansible_ssh_common_args" => "-4"
    }
    assert_equal expected, rendered_hash(gu_config, existing: GU_EXISTING)
  end

  test "carambus-phat: gleiche Ableitung unter eigenem Inventarnamen" do
    config = gu_config("ssh_host" => "carambus-phat.local", "ansible" => {"inventory_name" => "carambus-phat"})
    result = rendered_hash(config, existing: GU_EXISTING)
    assert_equal [3131, 8910], result["firewall_tcp_ports"]
    assert_equal "-4", result["ansible_ssh_common_args"]
  end

  # --- -4 nur, wenn beide Bedingungen gelten (Paar) --------------------------------------------

  test "-4 entfaellt ohne .local (DuckDNS liefert kein AAAA)" do
    assert_not rendered_hash(gu_config("ssh_host" => "gu.duckdns.org"), existing: GU_EXISTING)
      .key?("ansible_ssh_common_args")
  end

  test "-4 entfaellt ohne IPv6-Firewall" do
    assert_not rendered_hash(gu_config("ansible" => {"ipv6_firewall" => false}), existing: GU_EXISTING)
      .key?("ansible_ssh_common_args")
  end

  # --- bootstrap_user (Plan 15-02): Imager-Benutzer je Geraet, nur wenn gesetzt (Paar) -----------

  test "bootstrap_user aus config.yml wird geschrieben" do
    config = gu_config("ansible" => {"bootstrap_user" => "gullrich"})
    assert_equal "gullrich", rendered_hash(config, existing: nil)["bootstrap_user"]
  end

  test "ohne bootstrap_user in config.yml bleibt der Schluessel weg (Gruppenwert gilt)" do
    assert_not rendered_hash(gu_config, existing: GU_EXISTING).key?("bootstrap_user")
  end

  # --- AC-2: Ansible-Schalter und Idempotenz ---------------------------------------------------

  test "die Ansible-Schalter werden mit ihrem Wert uebernommen, nicht aus config.yml erfunden" do
    existing = GU_EXISTING.sub("basic_install_done: true", "basic_install_done: false")
    assert_equal false, rendered_hash(gu_config, existing: existing)["basic_install_done"]
  end

  test "frischer Host ohne Datei bekommt keinen Ansible-Schalter — er laeuft noch als root:22" do
    result = rendered_hash(gu_config, existing: nil)
    assert_empty result.keys & ScenarioHostVars::ANSIBLE_OWNED_KEYS
    assert_equal [3131, 8910], result["firewall_tcp_ports"]
  end

  test "ein von Ansible nachgetragener Schalter am Dateiende bleibt erhalten" do
    first = generator(bc_wedel_config, existing: BC_WEDEL_EXISTING).render
    appended = first + "initial_data_copy: false\n"
    assert_equal false, rendered_hash(bc_wedel_config, existing: appended)["initial_data_copy"]
  end

  test "zweimal generieren ergibt denselben Text" do
    first = generator(bc_wedel_config, existing: BC_WEDEL_EXISTING).render
    second = generator(bc_wedel_config, existing: first).render
    assert_equal first, second
  end

  test "das Generat traegt einen Kopf mit Quelle und Befehl" do
    text = generator(bc_wedel_config, existing: BC_WEDEL_EXISTING, scenario_name: "carambus_bcw").render
    assert_match "GENERIERT aus carambus_data/scenarios/carambus_bcw/config.yml", text
    assert_match "scenario:generate_host_vars[carambus_bcw]", text
    assert_no_match(/gemessen 2026-09-08/, text, "Kommentare der alten Datei gehoeren nach config.yml")
  end

  # --- AC-3: Inventarname ----------------------------------------------------------------------

  test "Inventarname, der nicht im Inventar steht, bricht ab" do
    error = assert_raises(ScenarioHostVars::Error) do
      generator(gu_config("ansible" => {"inventory_name" => "carambus-xyz"})).render
    end
    assert_match "carambus-xyz", error.message
  end

  test "ein nur auskommentierter Host zaehlt nicht" do
    assert_raises(ScenarioHostVars::Error) { generator(gu_config("ansible" => {"inventory_name" => "api"})).render }
  end

  test "ein Gruppenname ist kein Host" do
    assert_raises(ScenarioHostVars::Error) do
      generator(gu_config("ansible" => {"inventory_name" => "nur-als-gruppe"})).render
    end
  end

  test "ein Host, der nur als Gruppenmitglied steht, zaehlt" do
    assert_nothing_raised { generator(gu_config("ansible" => {"inventory_name" => "nur-in-gruppe"})).render }
  end

  test "fehlender Abschnitt ansible bricht mit Hinweis ab" do
    error = assert_raises(ScenarioHostVars::Error) { generator(gu_config.except("ansible")).render }
    assert_match "ansible", error.message
  end

  # --- AC-4: eine Quelle ----------------------------------------------------------------------

  test "ein geaenderter webserver_port kommt in der Freigabe an" do
    assert_equal [3141, 8910], rendered_hash(gu_config("webserver_port" => 3141), existing: GU_EXISTING)["firewall_tcp_ports"]
  end

  test "ssh_port abweichend vom eingerichteten ansible_port bricht ab" do
    error = assert_raises(ScenarioHostVars::Error) do
      generator(gu_config("ssh_port" => 2222), existing: GU_EXISTING).render
    end
    assert_match "8910", error.message
    assert_match "2222", error.message
  end

  test "im Zuschnitt bleiben Extra-Ports leer, die Zusatzports wandern in die Zuschnittliste" do
    result = rendered_hash(gu_config("ansible" => {"firewall_extra_tcp_ports" => [5201]}), existing: GU_EXISTING)
    assert_equal [3131, 8910, 5201], result["firewall_tcp_ports"]
    assert_equal [], result["firewall_extra_tcp_ports"]
  end
end
