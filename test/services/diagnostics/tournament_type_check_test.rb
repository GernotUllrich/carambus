# frozen_string_literal: true

require "test_helper"

# Die Pruefung auf widerspruechliche CC-Turnierzuordnungen.
#
# Der Wert dieser Pruefung liegt nicht darin, dass sie etwas findet — sondern darin, dass sie
# das Richtige findet. Gemessen am 2026-08-27 ueber 5180 CC-Zwillinge: ohne die Familien-Regel
# meldet sie 82 Faelle, von denen 81 harmlos sind. Die Tests halten genau diese Trennung fest.
class Diagnostics::TournamentTypeCheckTest < ActiveSupport::TestCase
  BASE_ID = 59_800_000

  setup do
    @region = regions(:nbv)
    @season = seasons(:current)
  end

  def turnier!(offset, titel)
    Tournament.create!(id: BASE_ID + offset, title: titel, season: @season,
      organizer: @region, organizer_type: "Region", region_id: @region.id,
      discipline: disciplines(:pool_8ball), date: Date.current.to_time + 11.hours)
  end

  def zwilling!(offset, tournament, typ:, kategorie: nil)
    kat = kategorie && CategoryCc.find_or_create_by!(name: kategorie) do |c|
      c.branch_cc = BranchCc.find_or_create_by!(id: BASE_ID + 900) do |b|
        b.discipline = disciplines(:branch_pool)
        b.region_cc = RegionCc.find_or_create_by!(id: BASE_ID + 901) { |r| r.region = @region }
      end
    end
    TournamentCc.create!(id: BASE_ID + offset, tournament: tournament, name: tournament.title,
      championship_type_cc_name: typ, category_cc: kat)
  end

  def befund(name, verbose: false)
    Diagnostics::TournamentTypeCheck.new(verbose: verbose).call.find { |c| c.name == name }
  end

  # --- Der Fall, der die Pruefung ausgeloest hat ----------------------------------------------

  test "ein Titel, der eine andere Serien-Familie nennt, wird gemeldet" do
    t = turnier!(1, "NDM Jugend Freie Partie")
    zwilling!(2, t, typ: "Vorgabepokal (VP)")

    check = befund("Titel gegen Meisterschaftstyp")
    assert check.warned?, "Vorgabepokal-Typ bei NDM-Titel ist ein Widerspruch"
    assert_match(/NDM Jugend Freie Partie/, check.hint)
    assert_match(/Korrektur gehoert in die CC-Quelle/, check.hint,
      "die Meldung muss sagen, wo die Korrektur hingehoert")
  end

  test "eine Kategorie, die dem Meisterschaftstyp widerspricht, wird gemeldet" do
    t = turnier!(3, "1. Nordcup Freie Partie")
    zwilling!(4, t, typ: "NordCup (NC)", kategorie: "Grand Prix")

    check = befund("Kategorie gegen Meisterschaftstyp")
    assert check.warned?
    assert_match(/Grand Prix/, check.hint)
  end

  # --- Was NICHT gemeldet werden darf --------------------------------------------------------

  # 16 von 82 Rohtreffern: "GP" ist dieselbe Serie wie "German Grand Prix (GGP)".
  test "eine kuerzere Schreibweise derselben Serie ist kein Widerspruch" do
    t = turnier!(5, "GP Herren 10-Ball")
    zwilling!(6, t, typ: "German Grand Prix (GGP)")

    refute befund("Titel gegen Meisterschaftstyp").warned?,
      "GP und GGP gehoeren zur selben Familie"
  end

  # 30 von 82: NDJM ist die Jugend-Variante von NDM, LJM die von LEM.
  test "eine Jugend-Variante derselben Meisterschaft ist kein Widerspruch" do
    t = turnier!(7, "NDJM Freie Partie")
    zwilling!(8, t, typ: "Norddeutsche Meisterschaft (NDM)")

    refute befund("Titel gegen Meisterschaftstyp").warned?
    # …taucht aber im ausfuehrlichen Modus auf, damit sie nicht ganz unsichtbar ist.
    assert_equal :info, befund("Varianten innerhalb einer Familie", verbose: true).status
  end

  # 35 von 82: eine Landesmeisterschaft, die im Titel eine DM-Qualifikation erwaehnt.
  test "eine erwaehnte Qualifikation derselben Familie ist kein Widerspruch" do
    t = turnier!(9, "Landeseinzelmeisterschaft 8-Ball mit DM-Quali")
    zwilling!(10, t, typ: "Landeseinzelmeisterschaft (LEM)")

    refute befund("Titel gegen Meisterschaftstyp").warned?
  end

  # CategoryCc traegt neben Serien auch Alters- und Geschlechtsklassen — die machen zum
  # Meisterschaftstyp gar keine Aussage.
  test "eine Alters- oder Geschlechtsklasse als Kategorie ist kein Widerspruch" do
    t = turnier!(11, "NDM Dreiband Herren")
    zwilling!(12, t, typ: "Norddeutsche Meisterschaft (NDM)", kategorie: "Unisex jeden Alters")

    refute befund("Kategorie gegen Meisterschaftstyp").warned?
  end

  test "ohne Auffaelligkeiten meldet die Pruefung ok" do
    t = turnier!(13, "1. Vorgabepokal Freie Partie")
    zwilling!(14, t, typ: "Vorgabepokal (VP)", kategorie: "Vorgabepokal")

    assert befund("Titel gegen Meisterschaftstyp").ok?
    assert befund("Kategorie gegen Meisterschaftstyp").ok?
  end

  test "die Pruefung veraendert nichts" do
    t = turnier!(15, "NDM Jugend Freie Partie")
    z = zwilling!(16, t, typ: "Vorgabepokal (VP)")
    vorher = z.attributes.dup

    Diagnostics::TournamentTypeCheck.new(verbose: true).call

    assert_equal vorher, z.reload.attributes, "die Diagnose ist strikt read-only"
  end
end
