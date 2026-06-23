# frozen_string_literal: true

require "test_helper"

# Der Carambus-Assistent (Chat) ist NUR auf Local-Servern freigegeben. Auf der zentralen
# Authority (api.carambus.de, carambus_api_url blank) ist er hart geblockt (2026-06-20):
# der Server ist nicht für die Allgemeinheit bestimmt, CC-Schreibaktionen liefen dort
# fehl-attribuiert (Phase 39), persönliche Anfragen funktionieren dort ohnehin nicht.
class SpielleiterChatControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @orig_api_url = Carambus.config.carambus_api_url
  end

  teardown do
    Carambus.config.carambus_api_url = @orig_api_url
  end

  test "Authority (carambus_api_url blank): GET /chat wird geblockt → Redirect zu root" do
    Carambus.config.carambus_api_url = nil
    sign_in @user
    get spielleiter_chat_path
    assert_redirected_to root_path
    assert_equal "Der Carambus-Assistent steht auf diesem Server nicht zur Verfügung.", flash[:alert]
  end

  # Regression (45-03-Live-Befund, Joshua/pbv): `last(40)` zerschnitt ein tool_use/tool_result-Paar
  # → führendes verwaistes tool_result → Anthropic 400 bei JEDEM Folge-Request ("nichts geht mehr").
  # trim_history kürzt an Turn-Grenzen, sodass die History nie mit einem tool_result beginnt.
  def trim(messages)
    SpielleiterChatController.new.send(:trim_history, messages)
  end

  test "trim_history droppt führendes verwaistes tool_result (beginnt an Turn-Grenze)" do
    history = [
      {role: "user", content: [{type: "tool_result", tool_use_id: "orphan", content: "x"}]}, # zerschnittenes Paar
      {role: "assistant", content: [{type: "text", text: "..."}]},
      {role: "user", content: "echte Frage"},
      {role: "assistant", content: [{type: "tool_use", id: "t1", name: "cc_x", input: {}}]},
      {role: "user", content: [{type: "tool_result", tool_use_id: "t1", content: "y"}]},
      {role: "assistant", content: [{type: "text", text: "antwort"}]}
    ]
    trimmed = trim(history)
    assert_equal "user", trimmed.first[:role]
    assert_kind_of String, trimmed.first[:content]
    assert_equal "echte Frage", trimmed.first[:content]
    # Kein führender tool_result-Block mehr (die eigentliche 400-Wurzel)
    refute(trimmed.first[:content].is_a?(Array))
    # Das verbleibende tool_result (t1) hat sein tool_use unmittelbar davor → Paar intakt
    assert(trimmed.any? { |m| m[:role] == "assistant" && Array(m[:content]).any? { |b| b[:type] == "tool_use" && b[:id] == "t1" } })
  end

  test "trim_history lässt saubere History (beginnt mit User-Text) unverändert" do
    history = [
      {role: "user", content: "Frage"},
      {role: "assistant", content: [{type: "text", text: "Antwort"}]}
    ]
    assert_equal history, trim(history)
  end

  test "trim_history: leere History → leer, kein Crash" do
    assert_equal [], trim([])
    assert_equal [], trim(nil)
  end

  test "trim_history kappt auf MAX_HISTORY und beginnt dennoch an Turn-Grenze" do
    big = (1..60).flat_map do |i|
      [{role: "user", content: "Frage #{i}"}, {role: "assistant", content: [{type: "text", text: "A#{i}"}]}]
    end
    trimmed = trim(big)
    assert_operator trimmed.length, :<=, SpielleiterChatController::MAX_HISTORY
    assert_equal "user", trimmed.first[:role]
    assert_kind_of String, trimmed.first[:content]
  end
end
