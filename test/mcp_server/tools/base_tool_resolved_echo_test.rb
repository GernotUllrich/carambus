# frozen_string_literal: true

require "test_helper"

# Plan 22-01 T3: Test für BaseTool.resolved_echo Helper.
# Bewusst neue Test-File (nicht in base_tool_test.rb integriert) wegen pre-existing
# Load-Bug in base_tool_test.rb:466 (RSpec-Style describe in Minitest-Class).
# Reparatur dieses Files ist out-of-scope für Plan 22-01.
class McpServer::Tools::BaseToolResolvedEchoTest < ActiveSupport::TestCase
  test "TournamentCc-Entity liefert strukturierten resolved-Hash mit allen Pflichtfeldern" do
    tcc = TournamentCc.first
    skip "No TournamentCc fixtures loaded" unless tcc

    result = McpServer::Tools::BaseTool.resolved_echo(entity: tcc, matched_by: :cc_id)
    assert result.key?(:resolved)

    resolved = result[:resolved]
    assert_equal tcc.tournament_id, resolved[:tournament_id]
    assert_equal tcc.cc_id, resolved[:tournament_cc_id]
    assert_equal tcc.context, resolved[:region]
    assert_equal "cc_id", resolved[:matched_by]
    assert_equal false, resolved[:ambiguous]
  end

  test "RegistrationListCc-Entity liefert resolved-Hash mit registration_list_-Feldern" do
    rl = RegistrationListCc.first
    skip "No RegistrationListCc fixtures loaded" unless rl

    result = McpServer::Tools::BaseTool.resolved_echo(entity: rl, matched_by: "name_match")
    resolved = result[:resolved]
    assert_equal rl.id, resolved[:registration_list_id]
    assert_equal rl.cc_id, resolved[:registration_list_cc_id]
    assert_equal rl.context, resolved[:region]
    assert_equal "name_match", resolved[:matched_by]
    assert_equal false, resolved[:ambiguous]
  end

  test "nil-Entity liefert {resolved: nil} (kein crash)" do
    result = McpServer::Tools::BaseTool.resolved_echo(entity: nil)
    assert_equal({resolved: nil}, result)
  end

  test "unsupported Entity-Klasse liefert resolved-Hash mit error-Schlüssel" do
    # Region ist keine unterstützte Entity-Klasse für resolved_echo (heute)
    region = Region.first
    skip "No Region fixtures loaded" unless region

    result = McpServer::Tools::BaseTool.resolved_echo(entity: region)
    resolved = result[:resolved]
    assert resolved.key?(:error)
    assert_match(/unsupported entity class/i, resolved[:error])
  end

  test "matched_by nil bleibt nil (kein to_s-Crash)" do
    tcc = TournamentCc.first
    skip "No TournamentCc fixtures loaded" unless tcc

    result = McpServer::Tools::BaseTool.resolved_echo(entity: tcc, matched_by: nil)
    assert_nil result[:resolved][:matched_by]
  end
end
