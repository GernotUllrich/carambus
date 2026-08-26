# frozen_string_literal: true

require "test_helper"

# Die Sparlogik des naechtlichen CC-Turnier-Scrapes.
#
# Anlass (gemessen 2026-08-26 auf der Authority): 36 NBV-Karambol-Turniere der Saison 2026/2027
# standen in der ClubCloud, aber nicht in Carambus. Die alte Bedingung lautete
# `cc_id <= cc_id_max` und meinte damit "kennen wir schon" — tatsaechlich hiess sie nur "die ID
# ist kleiner als die groesste bekannte". Weil Kegel/Snooker (cc_id 1037–1048) frueher
# eingesammelt worden waren, lag die Schwelle ueber der gesamten Karambol-Serie (943–981);
# zusammen mit `date > Time.now` fiel sie jede Nacht durch.
class RegionSkipKnownTournamentRowTest < ActiveSupport::TestCase
  setup do
    @region = regions(:nbv)
    @region_cc = RegionCc.find_or_create_by!(region_id: @region.id) do |rc|
      rc.context = "nbvtest"
      rc.cc_id = 20
      rc.shortname = "NBV"
      rc.name = "Norddeutscher Billard Verband e.V."
    end
    @context = @region_cc.context
  end

  def bekannt!(cc_id)
    TournamentCc.find_or_create_by!(cc_id: cc_id, context: @context) { |t| t.name = "Turnier #{cc_id}" }
  end

  # Der Fall, der 36 Turniere gekostet hat.
  test "ein unbekanntes Turnier wird gelesen, auch bei niedriger cc_id und Termin in der Zukunft" do
    bekannt!(1048) # hohe cc_id bekannt — frueher die Schwelle

    refute @region.skip_known_tournament_row?(cc_id: 943, date: 2.months.from_now, open_cc_ids: []),
      "Ein Turnier, das Carambus nicht kennt, MUSS gelesen werden — sonst entsteht es nie"
  end

  test "ein bekanntes Turnier in der Zukunft wird uebersprungen" do
    bekannt!(943)

    assert @region.skip_known_tournament_row?(cc_id: 943, date: 2.months.from_now, open_cc_ids: []),
      "Ergebnisse gibt es noch nicht — der Detail-Abruf waere verschwendet"
  end

  test "ein bekanntes, gespieltes und noch ergebnisloses Turnier wird gelesen" do
    bekannt!(943)

    refute @region.skip_known_tournament_row?(cc_id: 943, date: 2.days.ago, open_cc_ids: [943]),
      "Die Ergebnisse stehen nur auf der Detailseite, nicht in der Liste"
  end

  test "ein bekanntes, gespieltes und abgeschlossenes Turnier wird uebersprungen" do
    bekannt!(943)

    assert @region.skip_known_tournament_row?(cc_id: 943, date: 2.days.ago, open_cc_ids: [999]),
      "Abgeschlossen und bekannt — es gibt nichts nachzulesen"
  end

  # Die cc_id ist NUR regionsintern eindeutig (s. carambus-club-player-identity-numbers).
  test "ein Turnier derselben cc_id aus fremdem Kontext gilt nicht als bekannt" do
    TournamentCc.find_or_create_by!(cc_id: 943, context: "fremdtest") { |t| t.name = "fremdes Turnier" }

    refute @region.skip_known_tournament_row?(cc_id: 943, date: 2.months.from_now, open_cc_ids: []),
      "cc_id 943 im Kontext 'fremdtest' sagt nichts ueber den eigenen Kontext aus"
  end
end
