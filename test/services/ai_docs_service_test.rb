# frozen_string_literal: true

require "test_helper"
require "ostruct"

# Phase 36-01: AiDocsService — Anthropic-Migration (gpt-4o-mini → Claude).
# Anthropic-Client wird gemockt (kein echter API-Key in Test/Dev).
class AiDocsServiceTest < ActiveSupport::TestCase
  # Fake Anthropic-Client: client.messages.create(...) → OpenStruct mit .content.first.text
  def fake_anthropic(text)
    client = Object.new
    client.define_singleton_method(:messages) { self }
    client.define_singleton_method(:create) { |**_| OpenStruct.new(content: [OpenStruct.new(text: text)]) }
    client
  end

  test "blank query → success:false" do
    result = AiDocsService.call(query: "   ", locale: "de")
    assert_equal false, result[:success]
  end

  test "anthropic nicht konfiguriert → success:false + Hinweis" do
    svc = AiDocsService.new(query: "Turnier anlegen", locale: "de")
    svc.stub(:anthropic_configured?, false) do
      result = svc.call
      assert_equal false, result[:success]
      assert_match(/nicht konfiguriert/i, "#{result[:error]}#{result[:answer]}")
    end
  end

  test "happy path: Claude-Synthese, Result-Vertrag erhalten" do
    svc = AiDocsService.new(query: "Turnier", locale: "de")
    svc.instance_variable_set(:@client, fake_anthropic("Du legst ein Turnier über das Menü an."))
    docs = [{file: "#{Rails.root}/docs/foo.de.md", title: "Turniere", snippets: ["Turnier anlegen Schritt 1"]}]
    svc.stub(:anthropic_configured?, true) do
      svc.stub(:search_documentation, docs) do
        result = svc.call
        assert result[:success], "expected success:true"
        assert_equal "Du legst ein Turnier über das Menü an.", result[:answer]
        assert result.key?(:docs_links)
        assert result.key?(:snippets)
        assert result.key?(:confidence)
      end
    end
  end

  test "leere Doku-Treffer → success:true mit Hinweis (kein Claude-Call nötig)" do
    svc = AiDocsService.new(query: "ZzzUnauffindbar", locale: "de")
    svc.stub(:anthropic_configured?, true) do
      svc.stub(:search_documentation, []) do
        result = svc.call
        assert result[:success]
        assert_equal [], result[:docs_links]
      end
    end
  end
end
