# frozen_string_literal: true

require "test_helper"

# Player#club: Verein der juengsten Saison, echter Verein vor „vereinslos“ (Betreiber 2026-10-20,
# nach dem GP Biathlon: kein Logo, weil „vereinslos“ statt BSC Essen gegriffen hatte).
class PlayerClubTest < ActiveSupport::TestCase
  setup do
    @player = Player.create!(firstname: "Test-Club", lastname: "Spieler")
    @vereinslos = Club.create!(name: "DBU-Vereinslos", shortname: "vereinslos")
    @real = clubs(:bcw)
    @other = clubs(:example_club)
  end

  def sp!(season, club)
    SeasonParticipation.create!(player: @player, season: seasons(season), club: club)
  end

  test "echter Verein schlaegt vereinslos in derselben Saison — in beiden Anlage-Reihenfolgen" do
    sp!(:current, @real)
    sp!(:current, @vereinslos)
    assert_equal @real, @player.club

    SeasonParticipation.where(player: @player).delete_all
    sp!(:current, @vereinslos)
    sp!(:current, @real)
    assert_equal @real, @player.reload.club
  end

  test "nur vereinslos -> vereinslos (Gegenprobe)" do
    sp!(:current, @vereinslos)
    assert_equal @vereinslos, @player.club
  end

  # „Juengste“ heisst wie bisher: hoechste season_id. In den Fixtures hat :previous die hoehere
  # id als :current, deshalb legt der Test seine Saisons selbst an (im bcw-Bestand fallen
  # id- und Namensreihenfolge bei 0 von 5174 Spielern auseinander).
  test "die juengste Saison entscheidet, nicht der echte Verein einer aelteren" do
    older = Season.create!(name: "2097/2098")
    newer = Season.create!(name: "2098/2099")
    SeasonParticipation.create!(player: @player, season: older, club: @real)
    SeasonParticipation.create!(player: @player, season: newer, club: @vereinslos)
    assert_equal @vereinslos, @player.club
  end

  test "mehrere echte Vereine derselben Saison: die zuletzt angelegte Zugehoerigkeit" do
    sp!(:current, @real)
    sp!(:current, @other)
    assert_equal @other, @player.club
  end

  test "ohne Zugehoerigkeit nil" do
    assert_nil @player.club
  end
end
