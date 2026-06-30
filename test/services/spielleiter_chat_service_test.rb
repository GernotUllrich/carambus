# frozen_string_literal: true

require "test_helper"

# Phase 34-02: SpielleiterChatService bezieht Tools persona-gefiltert aus ToolRegistry.
# Getestet wird das Gating über tool_definitions OHNE converse() (kein Anthropic-Call,
# kein Netz; Client ist lazy).
class SpielleiterChatServiceTest < ActiveSupport::TestCase
  WRITE_TOOL_NAMES = %w[
    cc_register_for_tournament
    cc_unregister_for_tournament
    cc_assign_player_to_teilnehmerliste
    cc_remove_from_teilnehmerliste
    cc_fast_assign_to_teilnehmerliste
    cc_update_tournament_deadline
    cc_finalize_teilnehmerliste
  ].freeze

  def tool_names_for(user)
    SpielleiterChatService.new(user: user).tool_definitions.map { |t| t[:name] }
  end

  # Write-Tools nur auf Local-Servern (Authority = read-only, seit 2026-06-20). Test-Env ist
  # Authority (carambus_api_url leer) → für die Write-Tool-Tests local mode setzen.
  setup do
    @orig_api_url = Carambus.config.carambus_api_url
    Carambus.config.carambus_api_url = "http://local.test"
  end

  teardown do
    Carambus.config.carambus_api_url = @orig_api_url
  end

  test "read-only User (cc_write_access? false): KEIN Write-Tool in den Tool-Definitionen" do
    u = User.new(email: "chat_ro@test.de")
    def u.cc_write_access?
      false
    end
    names = tool_names_for(u)
    leaked = names & WRITE_TOOL_NAMES
    assert leaked.empty?, "read-only User darf keine Write-Tools sehen, hatte: #{leaked.inspect}"
    assert_includes names, "cc_whoami"
    assert_includes names, "cc_list_open_tournaments"
  end

  test "schreibberechtigter User (cc_write_access? true): Write-Tools vorhanden" do
    u = User.new(email: "chat_rw@test.de")
    def u.cc_write_access?
      true
    end
    names = tool_names_for(u)
    assert_includes names, "cc_assign_player_to_teilnehmerliste"
    assert_includes names, "cc_remove_from_teilnehmerliste"
  end

  test "Authority (carambus_api_url blank): cc_write_access? sieht KEINE Write-Tools + read-only-System-Prompt" do
    Carambus.config.carambus_api_url = nil
    u = User.new(email: "chat_authority@test.de")
    def u.cc_write_access?
      true
    end
    svc = SpielleiterChatService.new(user: u)
    names = svc.tool_definitions.map { |t| t[:name] }
    leaked = names & WRITE_TOOL_NAMES
    assert leaked.empty?, "Authority-Chat darf keine Write-Tools sehen, hatte: #{leaked.inspect}"
    assert_includes names, "cc_list_open_tournaments", "Lese-Tools bleiben auf der Authority"
    assert_match(/AUTHORITY-SERVER/i, svc.send(:system_prompt),
      "System-Prompt rahmt die Authority als read-only")
  end

  test "tool_definitions ohne Anthropic-API-Key konstruierbar (lazy client)" do
    u = User.new
    def u.cc_write_access?
      false
    end
    assert_nothing_raised do
      SpielleiterChatService.new(user: u).tool_definitions
    end
  end

  test "system_prompt: read-only User bekommt Lese-Hinweis, schreibberechtigter nicht" do
    ro = User.new
    def ro.cc_write_access?
      false
    end
    rw = User.new
    def rw.cc_write_access?
      true
    end
    assert_includes SpielleiterChatService.new(user: ro).send(:system_prompt), "nur Lese-Zugriff"
    refute_includes SpielleiterChatService.new(user: rw).send(:system_prompt), "nur Lese-Zugriff"
  end

  test "write_tool? erkennt Schreib- vs Lese-Tools (steuert Hybrid-Modell-Eskalation)" do
    u = User.new(email: "chat_hybrid@test.de")
    def u.cc_write_access?
      true
    end
    svc = SpielleiterChatService.new(user: u)
    # Write-Tools (read_only_hint: false) → lösen die Eskalation aufs starke Modell aus
    assert svc.send(:write_tool?, "cc_remove_from_teilnehmerliste"), "Schreib-Tool muss als Write erkannt werden"
    assert svc.send(:write_tool?, "cc_assign_player_to_teilnehmerliste")
    # Lese-Tool (read_only_hint: true) → bleibt beim schnellen Modell
    refute svc.send(:write_tool?, "cc_list_open_tournaments"), "Lese-Tool darf NICHT als Write gelten"
    # Unbekanntes Tool → defensiv als Write (lieber zu früh eskalieren als Write mit Haiku)
    assert svc.send(:write_tool?, "tool_das_es_nicht_gibt"), "Unbekanntes Tool defensiv als Write behandeln"
  end

  # 49-01: converse summiert response.usage pro Modell + gibt usage_by_model ADDITIV zurück.
  test "converse liefert usage_by_model aus response.usage (additiv, response/messages unverändert)" do
    u = User.new(email: "chat_usage@test.de")
    def u.cc_write_access?
      false
    end
    svc = SpielleiterChatService.new(user: u)

    usage = Struct.new(:input_tokens, :output_tokens, :cache_creation_input_tokens, :cache_read_input_tokens)
      .new(120, 30, 0, 0)
    block = Struct.new(:type, :text).new("text", "Hallo")
    response = Struct.new(:content, :stop_reason, :usage).new([block], "end_turn", usage)
    fake_messages = Object.new
    fake_messages.define_singleton_method(:create) { |**_| response }
    fake_client = Object.new
    fake_client.define_singleton_method(:messages) { fake_messages }

    result = svc.stub(:client, fake_client) do
      svc.converse(messages: [{role: "user", content: "hi"}])
    end

    # Bestehende Keys unverändert
    assert_equal "Hallo", result[:response]
    assert_equal({role: "user", content: "hi"}, result[:messages].first)
    # Additive Usage-Aufschlüsselung pro Modell
    ubm = result[:usage_by_model]
    assert_equal [SpielleiterChatService::FAST_MODEL], ubm.keys
    assert_equal 120, ubm[SpielleiterChatService::FAST_MODEL][:input]
    assert_equal 30, ubm[SpielleiterChatService::FAST_MODEL][:output]
  end
end
