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
  # ───────────────────────────────────────────────────────────────────────────
  # Plan 21-04: Die Doku-Suche darf aus einer Benutzereingabe keine Shell-
  # Kommandozeile bauen.
  #
  # Belegt zuerst am ALTEN Code, dass sie es tat (Projektregel seit Phase 7:
  # ein Fix ohne Beleg am alten Code ist eine Behauptung). Nach der Umstellung
  # auf Open3 mit Argumentliste pruefen dieselben Tests die neue Zusage.
  #
  # Es wird KEIN fremder Befehl ausgefuehrt. Geprueft wird, was beim
  # Unterprozess ankommt - eine Zeichenkette bzw. eine Argumentliste.
  # ───────────────────────────────────────────────────────────────────────────

  # Faengt ab, was der Service dem Unterprozess uebergibt, ohne ihn zu starten.
  # Greift sowohl den heutigen Backtick-Weg (ein String) als auch den kuenftigen
  # Open3-Weg (eine Argumentliste) ab.
  class ProcessSpy
    attr_reader :calls

    def initialize = @calls = []

    def record(*args)
      @calls << args
      ""
    end

    # Alles, was der Unterprozess als EIN Wort sehen wuerde - beim String-Weg
    # ist das die ganze Kommandozeile, beim Argument-Weg jedes Argument einzeln.
    def flat = @calls.flatten.join(" ")
  end

  def spy_on_search(service, spy)
    service.define_singleton_method(:`) { |cmd| spy.record(cmd) }
    service.define_singleton_method(:capture_search) { |*args| [spy.record(*args), "", nil] }
    service
  end

  # Ein Suchwort mit einfachem Anfuehrungszeichen und Kommandosubstitution.
  # `;` `,` `.` `:` `?` `!` werden von extract_keywords entfernt - Backtick,
  # `$(`, `|` und `&` nicht. Ein Token ohne Leerzeichen, laenger als 2 Zeichen.
  BOESES_SUCHWORT = "turnier'$(MARKER)"

  test "21-04: Suchwort mit Quote-Bruch erreicht den Unterprozess nicht mehr unquotiert" do
    svc = AiDocsService.new(query: BOESES_SUCHWORT, locale: "de")
    spy = ProcessSpy.new
    spy_on_search(svc, spy)
    svc.stub(:ripgrep_available?, true) do
      svc.send(:search_documentation)
    end

    assert spy.calls.any?, "Der Unterprozess wurde gar nicht aufgerufen - Test greift ins Leere"

    # Der Kern: steht `$(MARKER)` ausserhalb der einfachen Anfuehrungszeichen?
    # Am alten Code beendete `\'` die Quotierung und alles danach stand frei.
    uebergeben = spy.flat
    ausserhalb = uebergeben.scan(/'[^']*'/).join(" ") != uebergeben &&
      uebergeben.split("'").each_with_index.any? { |teil, i| i.even? && teil.include?("$(") }

    assert_not ausserhalb,
      "Kommandosubstitution steht unquotiert in der Uebergabe:\n  #{uebergeben}"
  end

  test "21-04: das Suchwort geht als EIN Argument, nicht als Teil einer Kommandozeile" do
    svc = AiDocsService.new(query: "turnier", locale: "de")
    spy = ProcessSpy.new
    spy_on_search(svc, spy)
    svc.stub(:ripgrep_available?, true) do
      svc.send(:search_documentation)
    end

    assert spy.calls.any?, "Der Unterprozess wurde gar nicht aufgerufen"
    args = spy.calls.first
    assert_operator args.size, :>, 1,
      "Der Unterprozess bekam einen einzigen String (#{args.inspect[0, 120]}) - " \
      "das ist eine Shell-Kommandozeile, keine Argumentliste"
    assert_includes args, "turnier",
      "Das Suchwort steht nicht als eigenes Argument in #{args.inspect[0, 120]}"
  end

  test "21-04: ein unbekanntes Locale erreicht die Dateiauswahl nicht" do
    svc = AiDocsService.new(query: "turnier", locale: "de' -X '")
    spy = ProcessSpy.new
    spy_on_search(svc, spy)
    svc.stub(:ripgrep_available?, true) do
      svc.send(:search_documentation)
    end

    assert spy.calls.any?
    assert_not_includes spy.flat, "-X",
      "Das Locale aus der Anfrage landete ungeprueft in der Uebergabe: #{spy.flat}"
  end
end
