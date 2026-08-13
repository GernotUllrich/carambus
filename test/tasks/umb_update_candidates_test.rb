# frozen_string_literal: true

require "test_helper"
require "rake"

# Kandidatenauswahl fuer `umb:update` Step 4 (Detail-Scrape mit parse_pdfs).
#
# Hintergrund: nach der PlayerListParser-Reparatur (2026-08-10) blieben die
# Seedings drei Cron-Laeufe lang bei 9 von 66 Turnieren stehen. Ursache war nicht
# der Parser, sondern dieses Praedikat: es kannte nur `games` und
# `detail_scraped_at`, nicht `seedings`. Turniere, die vor der Reparatur gescrapt
# wurden, waren damit dauerhaft ausgesperrt.
class UmbUpdateCandidatesTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    @source = international_sources(:umb_source)
  end

  teardown do
    Rake::Task.clear
  end

  # data-Vorlage eines bereits im Detail gescrapten Turniers.
  def scraped_data(players_list: true)
    pdf_links = {"General Information" => "https://example.test/gi.pdf"}
    if players_list
      pdf_links["A. Players List.pdf"] = "https://example.test/pl.pdf"
      pdf_links["players_list"] = "https://example.test/pl.pdf"
    end
    {"detail_scraped_at" => 6.months.ago.iso8601, "pdf_links" => pdf_links}
  end

  def tournament(title, data:, games: 1, seedings: 0)
    t = InternationalTournament.create!(
      title: title, date: 3.months.ago, season: seasons(:current),
      organizer: regions(:nbv), organizer_type: "Region",
      international_source: @source, data: data
    )
    # ueber die Assoziation, nicht `InternationalGame.create!(tournament: t)`:
    # `belongs_to :tournament` ist in Game auskommentiert (game.rb), ein direkt
    # zugewiesenes Turnier laesst `tournament_type` nil — die Games waeren fuer
    # `t.games` unsichtbar.
    games.times { |i| t.games.create!(seqno: i + 1, type: "InternationalGame") }
    seedings.times do |i|
      Seeding.create!(tournament: t, player: players(:jaspers), position: i + 1)
    end
    t.reload
  end

  # --- der Fall, der die Luecke ausmachte ---

  test "gescraptes Turnier mit players_list-PDF, aber ohne Seedings ist Kandidat" do
    t = tournament("World Cup ohne Seedings", data: scraped_data, games: 243)

    assert umb_needs_detail_update?(t),
      "Turnier mit unausgewerteter Spielerliste muss erneut in die Auswahl fallen"
  end

  test "gescraptes Turnier mit players_list-PDF und Seedings ist kein Kandidat" do
    t = tournament("World Cup mit Seedings", data: scraped_data, games: 243, seedings: 2)

    refute umb_needs_detail_update?(t),
      "ausgewertete Spielerliste darf nicht erneut gescrapt werden"
  end

  # --- Quotenschutz: ohne Spielerliste kein Dauergast in der Auswahl ---

  test "gescraptes Turnier ohne players_list-PDF ist trotz fehlender Seedings kein Kandidat" do
    t = tournament("Generalversammlung", data: scraped_data(players_list: false), games: 5)

    refute umb_needs_detail_update?(t),
      "ohne Spielerliste gibt es nichts zu parsen — sonst frisst das Turnier bei jedem Lauf die Quote"
  end

  # --- Bestandsverhalten unveraendert ---

  test "Turnier ohne Games ist Kandidat" do
    t = tournament("Frisch entdeckt", data: scraped_data, games: 0, seedings: 2)

    assert umb_needs_detail_update?(t)
  end

  test "Turnier ohne detail_scraped_at ist Kandidat" do
    t = tournament("Nie im Detail gescrapt", data: {"pdf_links" => {}}, games: 3)

    assert umb_needs_detail_update?(t)
  end

  test "leeres data ist Kandidat, auch mit Games und Seedings" do
    t = tournament("Ohne data", data: {}, games: 3, seedings: 1)

    assert umb_needs_detail_update?(t),
      "fehlendes detail_scraped_at zaehlt als nie gescrapt"
  end
end
