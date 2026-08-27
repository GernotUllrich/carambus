# frozen_string_literal: true

require "test_helper"

# Plan 40-01: Der Broadcast-Pfad muss in der konfigurierten Turniersprache rendern.
#
# WARUM DIESER TEST DER WICHTIGSTE DES PLANS IST: `TableMonitorJob` rendert ueber
# `ApplicationController.render` — also ohne Request und damit ohne `before_action :set_locale`.
# Bis zu diesem Plan kam die Sprache aus `I18n.locale` des Job-Threads: `default_locale`, oder
# — weil `I18n.locale` thread-lokal ist und Job-Threads wiederverwendet werden — der Restwert
# eines fremden Requests. Ein per `?locale=en` aufgerufenes Scoreboard fiel beim ersten
# Live-Update zurueck.
#
# Geprueft wird deshalb nicht das erzeugte Markup, sondern die Locale ZUR RENDERZEIT: das ist
# die Groesse, um die es geht, und sie ist unabhaengig davon, welche Texte ein Partial gerade
# enthaelt.
#
# `perform` steigt auf einem API-Server sofort aus (table_monitor_job.rb:8) — dieses Repo ist
# einer, deshalb wird die Rolle gestubbt.
class TableMonitorJobLocaleTest < ActiveSupport::TestCase
  BASE_ID = 54_000_000

  setup do
    @table_monitor = table_monitors(:free)
    @tournament = tournaments(:local)
    @tournament_monitor = TournamentMonitor.create!(id: BASE_ID + 1, tournament: @tournament)
    @table_monitor.update_columns(tournament_monitor_id: @tournament_monitor.id,
      tournament_monitor_type: "TournamentMonitor")
  end

  # Zeichnet die zur Renderzeit gueltige Locale auf und liefert sie zurueck.
  def locales_during_render(operation_type = "teaser")
    observed = []
    render_stub = lambda do |*_args, **_kwargs|
      observed << I18n.locale
      "<div></div>"
    end

    ApplicationRecord.stub(:local_server?, true) do
      ApplicationController.stub(:render, render_stub) do
        TableMonitorJob.perform_now(@table_monitor.id, operation_type)
      end
    end
    observed
  rescue StandardError => e
    flunk("Job brach ab: #{e.class}: #{e.message}")
  end

  test "rendert in der konfigurierten Turniersprache, obwohl der Thread auf :de steht" do
    @tournament_monitor.update!(locale: "en")

    observed = nil
    I18n.with_locale(:de) { observed = locales_during_render }

    assert_includes observed, :en,
      "Der Broadcast muss die am Turnier konfigurierte Sprache nutzen, nicht die Thread-Locale"
  end

  test "ohne Konfiguration rendert er in der default_locale — deterministisch, nicht im Thread-Restwert" do
    assert_nil @tournament_monitor.locale

    observed = nil
    # Ein fremder Request hat :en im Thread hinterlassen — genau der Fall, der die Anzeige
    # bisher unvorhersehbar machte.
    I18n.with_locale(:en) { observed = locales_during_render }

    assert_includes observed, I18n.default_locale,
      "Ohne Konfiguration muss der Job auf default_locale gehen, nicht auf den Thread-Restwert"
  end

  test "stellt die Locale nach dem Lauf wieder her (kein Leak in wiederverwendete Job-Threads)" do
    @tournament_monitor.update!(locale: "en")

    I18n.with_locale(:de) do
      locales_during_render
      assert_equal :de, I18n.locale, "with_locale muss den vorigen Wert wiederherstellen"
    end
  end
end
