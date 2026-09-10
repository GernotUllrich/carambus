# frozen_string_literal: true

require "yaml"

# ─────────────────────────────────────────────────────────────────────────────
# host_vars eines Carambus-Servers aus der Szenario-config.yml (Plan 15-01).
#
# Quelle ist carambus_data/scenarios/<szenario>/config.yml, Abschnitt
# environments.production — dieselbe Datei, aus der nginx, puma und Capistrano
# entstehen. Vorher stand z.B. der nginx-Port 3131 dort UND von Hand in
# ~/DEV/ansible/host_vars; an genau dieser Doppelung ist die Freigabe am
# 2026-09-09 in eine Datei gewandert, die Ansible nie laedt.
#
# Anders als die uebrigen Generate schreibt dieser nicht frisch aus einem
# Template: roles/bootstrap und roles/basic_install setzen per lineinfile
# Statusschalter in DIESELBE Datei. Die gehoeren Ansible — sie beschreiben, was
# mit dem Host schon passiert ist — und werden aus der bestehenden Datei
# unveraendert uebernommen. Fehlen sie (frischer Host), werden sie nicht
# erfunden: vor dem Bootstrap lauscht der Host noch auf root:22.
#
# Reine Logik ohne Datei-I/O; lesen und schreiben macht der Rake-Task
# scenario:generate_host_vars.
# ─────────────────────────────────────────────────────────────────────────────
class ScenarioHostVars
  class Error < StandardError; end

  # Die Schluessel, die Ansible selbst per lineinfile schreibt, in dieser Reihenfolge.
  ANSIBLE_OWNED_KEYS = %w[
    ansible_port ansible_ssh_user bootstrap_done disable_mailings
    basic_install_done ispconfig_done initial_data_copy
  ].freeze

  def initialize(scenario_name:, production_config:, existing:, inventory:)
    @scenario_name = scenario_name
    @config = production_config || {}
    @existing = existing
    @inventory = inventory.to_s
  end

  def inventory_name
    ansible_section.fetch("inventory_name") do
      raise Error, "#{source}: environments.production.ansible.inventory_name fehlt"
    end
  end

  def render
    check_inventory!
    owned = ansible_owned_values
    check_ssh_port!(owned)

    [header, block("von Ansible geschrieben (lineinfile), vom Generator uebernommen", owned),
      block("aus config.yml", generated_values)].compact.join("\n")
  end

  private

  def source
    "carambus_data/scenarios/#{@scenario_name}/config.yml"
  end

  def ansible_section
    section = @config["ansible"]
    raise Error, "#{source}: Abschnitt environments.production.ansible fehlt" unless section.is_a?(Hash)

    section
  end

  # Nur echte Hosts zaehlen: keine Kommentare, keine Gruppenkoepfe, keine :vars-/:children-Zeilen.
  def check_inventory!
    section = nil
    hosts = @inventory.each_line.filter_map do |line|
      line = line.strip
      next if line.empty? || line.start_with?("#", ";")
      next section = line if line.start_with?("[")
      next if section&.match?(/:(vars|children)\]\z/)

      line.split(/\s+/).first
    end
    return if hosts.include?(inventory_name)

    raise Error, "#{source}: inventory_name '#{inventory_name}' steht nicht als Host im Ansible-Inventar " \
                 "(hosts). host_vars/#{inventory_name} wuerde nie geladen."
  end

  def ansible_owned_values
    parsed = @existing.to_s.strip.empty? ? {} : YAML.safe_load(@existing)
    parsed = {} unless parsed.is_a?(Hash)
    ANSIBLE_OWNED_KEYS.each_with_object({}) do |key, values|
      values[key] = parsed[key] if parsed.key?(key)
    end
  end

  # Der eingerichtete SSH-Port (von Ansible gesetzt) muss zum gewuenschten passen — sonst
  # beschreibt config.yml einen Host, den es so nicht gibt.
  def check_ssh_port!(owned)
    return unless owned.key?("ansible_port")
    return if owned["ansible_port"] == ssh_port

    raise Error, "#{source}: ssh_port #{ssh_port} weicht vom eingerichteten ansible_port " \
                 "#{owned["ansible_port"]} ab (host_vars/#{inventory_name})"
  end

  def generated_values
    section = ansible_section
    extra = Array(section["firewall_extra_tcp_ports"])
    values = {}

    if section["firewall_trimmed"] == true
      # Zuschnitt ERSETZT den Standardsatz des Templates. extra_tcp_ports muss dann leer
      # sein: die Extra-Schleife in rules.v4.j2 laeuft nach dem Zuschnitt und haette ihn
      # sonst ausgehebelt.
      values["firewall_tcp_ports"] = [webserver_port, ssh_port, *extra]
      values["firewall_udp_ports"] = []
      values["firewall_extra_tcp_ports"] = []
    else
      values["firewall_extra_tcp_ports"] = [webserver_port, *extra]
    end

    values["ipv6_firewall"] = section["ipv6_firewall"] if section.key?("ipv6_firewall")
    values["full_stack_managed"] = section["full_stack_managed"] if section.key?("full_stack_managed")

    # mDNS liefert fuer <name>.local auch die GUA, die rules.v6 droppt; ohne -4 laeuft jede
    # SSH-Verbindung erst in einen Timeout (ansible -m ping: 42 s statt 4 s, ansible@038da81).
    if @config["ssh_host"].to_s.end_with?(".local") && section["ipv6_firewall"] == true
      values["ansible_ssh_common_args"] = "-4"
    end
    values
  end

  def webserver_port
    port("webserver_port")
  end

  def ssh_port
    port("ssh_port")
  end

  def port(key)
    value = @config[key]
    raise Error, "#{source}: environments.production.#{key} fehlt" unless value.is_a?(Integer)

    value
  end

  def header
    <<~HEADER
      # ===========================================================================
      # GENERIERT aus #{source}
      # (environments.production). Nicht hier editieren — die Werte und ihre
      # Begruendungen stehen dort. Neu erzeugen mit:
      #   bin/rails "scenario:generate_host_vars[#{@scenario_name}]"
      #
      # Ausnahme: den ersten Block setzen roles/bootstrap und roles/basic_install
      # per lineinfile. Der Generator uebernimmt ihn unveraendert.
      # ===========================================================================
    HEADER
  end

  def block(title, values)
    return nil if values.empty?

    "# --- #{title}\n" + values.map { |key, value| {key => value}.to_yaml.delete_prefix("---\n") }.join
  end
end
