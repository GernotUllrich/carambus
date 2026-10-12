# frozen_string_literal: true

require "test_helper"

# Plan 10-01: Der Validator prueft Turnierplaene gegen ihre eigene Definition.
#
# Jede Pruefung braucht ZWEI Tests: einen, der den Fehler faengt, und einen, der einen
# korrekten Plan durchlaesst. Ein Pruefer, der nur gegen defekte Daten getestet wird,
# koennte stillschweigend alles melden — und ein Pruefer mit Fehlalarmen wird ignoriert.
# Genau das ist beim Ad-hoc-Sweep am 2026-09-04 passiert (T01 falsch gemeldet).
#
# Die Testplaene werden hier gebaut statt als Fixture abgelegt: sie sind Pruefmaterial,
# kein Bestand. Der Validator liest nur Attribute, kein DB-Zugriff noetig.
class TournamentPlanValidatorTest < ActiveSupport::TestCase
  # @param params [Hash] wird zu executor_params serialisiert
  def plan(players: 9, nrepeats: 1, **params)
    TournamentPlan.new(players: players, nrepeats: nrepeats, executor_params: params.to_json)
  end

  def checks(plan)
    TournamentPlanValidator.new(plan).findings.map(&:check)
  end

  def messages(plan)
    TournamentPlanValidator.new(plan).findings.map(&:to_s).join(" | ")
  end

  # Eine vollstaendige 4er-Gruppe (alle 6 Paarungen), als Basis fuer die sauberen Faelle.
  def complete_group_of_four
    {"pl" => 4, "rs" => "eae", "sq" => {
      "r1" => {"t1" => "1-2", "t2" => "3-4"},
      "r2" => {"t1" => "1-3", "t2" => "2-4"},
      "r3" => {"t1" => "1-4", "t2" => "2-3"}
    }}
  end

  # ==========================================================================
  # Leere und unparsebare executor_params
  # ==========================================================================

  test "ohne executor_params gibt es nichts zu melden" do
    assert_empty checks(TournamentPlan.new(players: 9, executor_params: nil))
    assert_empty checks(TournamentPlan.new(players: 9, executor_params: ""))
  end

  test "unparsebares JSON liefert GENAU EINEN Befund" do
    # TournamentPlan 41 (T06I15B120-150) traegt so etwas. Ohne gueltiges JSON gibt es
    # nichts weiter zu pruefen — jede Folgepruefung wuerde an nil scheitern und den
    # Bericht mit Folgefehlern zumuellen.
    broken = TournamentPlan.new(players: 6, executor_params: '{"g1":{"pl":3,"rs":"eae"')

    assert_equal [:json], checks(broken)
  end

  # ==========================================================================
  # Pruefung: rules-Form  (der T16-Fall, id 9)
  # ==========================================================================

  test "rules als Hash ist gueltig" do
    refute_includes checks(plan(g1: complete_group_of_four,
      rules: {"rule1" => "(g1.rk2+g2.rk2).rk1"})), :rules_form
  end

  test "rules als String ist gueltig — das ist die eine Regel, ansprechbar als rule1" do
    # TournamentPlan 9 ist so gepflegt. Seit 4242f1bf versteht der Resolver beide Formen;
    # der Validator darf die String-Form deshalb NICHT als Fehler melden.
    refute_includes checks(plan(g1: complete_group_of_four,
      rules: "(g1.rk2+g2.rk2).rk1")), :rules_form
  end

  test "rules als Array oder Zahl wird gemeldet" do
    assert_includes checks(plan(g1: complete_group_of_four, rules: ["a", "b"])), :rules_form
    assert_includes checks(plan(g1: complete_group_of_four, rules: 42)), :rules_form
  end

  # ==========================================================================
  # Pruefung: Spielernummern  (die T17- und T10-Faelle)
  # ==========================================================================

  test "Paarung mit einem Spieler, den die Gruppe nicht hat, wird gemeldet (T17)" do
    # g2 hat 4 Spieler, r2 nennt Spieler 5. Genau daran scheiterte T17 (id 21):
    # statt 6 Gruppenspielen entstand genau eines, das Turnier war nicht startbar.
    defekt = plan(g2: {"pl" => 4, "rs" => "eae_pg", "sq" => {
      "r2" => {"t3" => "1-5", "t4" => "2-4"}
    }})

    assert_includes checks(defekt), :player_numbers
    assert_match(/g2\.r2\.t3/, messages(defekt), "Die Fundstelle muss im Befund stehen")
    assert_match(/Spieler 5/, messages(defekt))
  end

  test "Paarung mit einem Spieler, den die Gruppe nicht hat, wird gemeldet (T10)" do
    # g1 hat 3 Spieler, r1 nennt Spieler 4 — TournamentPlan 28.
    defekt = plan(players: 7, g1: {"pl" => 3, "rs" => "eae", "sq" => {
      "r1" => {"t1" => "1-4"}, "r2" => {"t1" => "2-3"}, "r3" => {"t1" => "1-2"}
    }})

    assert_includes checks(defekt), :player_numbers
  end

  test "gueltige Paarungen werden nicht gemeldet" do
    refute_includes checks(plan(g1: complete_group_of_four)), :player_numbers
  end

  # ==========================================================================
  # Pruefung: Wiederholungs-Suffix  (der T01-Fehlalarm)
  # ==========================================================================

  test "das /N-Suffix ist ein Wiederholungszaehler, keine Spielernummer" do
    # TournamentPlan 2 (T01): 2 Spieler, nrepeats=3, dreimal dieselbe Paarung.
    # Der Ad-hoc-Sweep vom 2026-09-04 las die 3 hinter dem Schraegstrich als Spieler
    # und meldete den Plan faelschlich. Dieser Test ist der Waechter dagegen.
    t01 = plan(players: 2, nrepeats: 3, g1: {"pl" => 2, "rs" => "eae", "sq" => {
      "r1" => {"t1" => "1-2/1"}, "r2" => {"t1" => "1-2/2"}, "r3" => {"t1" => "1-2/3"}
    }}, RK: ["g1.rk1", "g1.rk2"])

    assert_empty TournamentPlanValidator.new(t01).findings,
      "T01 ist ein korrekter Plan und darf KEINEN Befund erzeugen"
  end

  test "Wiederholungen sind keine doppelten Paarungen" do
    # T29 (id 32): nrepeats=2, jede Paarung zweimal, mit /1 und /2 unterschieden.
    t29 = plan(players: 4, nrepeats: 2, g1: {"pl" => 4, "rs" => "eae", "sq" => {
      "r1" => {"t1" => "2-3/1", "t2" => "1-4/1"},
      "r2" => {"t1" => "1-3/1", "t2" => "2-4/1"},
      "r3" => {"t1" => "3-4/1", "t2" => "1-2/1"},
      "r4" => {"t1" => "1-4/2", "t2" => "2-3/2"},
      "r5" => {"t1" => "2-4/2", "t2" => "1-3/2"},
      "r6" => {"t1" => "1-2/2", "t2" => "3-4/2"}
    }}, RK: ["g1.rk1", "g1.rk2", "g1.rk3", "g1.rk4"])

    refute_includes checks(t29), :round_robin
  end

  test "dieselbe Paarung im selben Durchgang zweimal wird gemeldet" do
    doppelt = plan(g1: {"pl" => 4, "rs" => "eae", "sq" => {
      "r1" => {"t1" => "1-2", "t2" => "3-4"},
      "r2" => {"t1" => "1-2", "t2" => "2-4"}, # 1-2 ein zweites Mal, ohne Durchgangsnummer
      "r3" => {"t1" => "1-3", "t2" => "2-3"},
      "r4" => {"t1" => "1-4"}
    }})

    assert_includes checks(doppelt), :round_robin
  end

  # ==========================================================================
  # Pruefung: Vollstaendigkeit — nur bei rs "eae"
  # ==========================================================================

  test "unvollstaendige Runde wird bei rs eae gemeldet" do
    luecke = {"pl" => 4, "rs" => "eae", "sq" => {
      "r1" => {"t1" => "1-2"}, "r2" => {"t1" => "1-3"}, "r3" => {"t1" => "1-4"}
    }} # es fehlen 2-3, 2-4, 3-4

    befunde = messages(plan(g1: luecke))
    assert_includes checks(plan(g1: luecke)), :round_robin
    assert_match(/2-3/, befunde, "Die fehlenden Paarungen gehoeren in den Befund")
  end

  test "dieselbe Luecke wird bei rs eae_pg NICHT gemeldet" do
    # Der Populator fuellt bei "eae_pg" auf (table_populator.rb:700). "T16|15B60" definiert
    # fuer g2 absichtlich nur r1 und ist korrekt. Dieser Test ist das Gegenstueck zum
    # vorigen — dieselben Daten, nur ein anderes Rundensystem. Ohne das Paar wuerde die
    # Unterscheidung nicht bewiesen.
    luecke = {"pl" => 4, "rs" => "eae_pg", "sq" => {
      "r1" => {"t1" => "1-2"}, "r2" => {"t1" => "1-3"}, "r3" => {"t1" => "1-4"}
    }}

    refute_includes checks(plan(g1: luecke)), :round_robin
  end

  test "vollstaendige Runde wird nicht gemeldet" do
    refute_includes checks(plan(g1: complete_group_of_four)), :round_robin
  end

  # ==========================================================================
  # Pruefung: RK  (der T16neu-Fall, id 340)
  # ==========================================================================

  # Die Aufstiegs-Konstellation, die den Fehler traegt: der Sieger von p<8-9> zieht in
  # p<7-8> weiter. Drei Plaetze werden vergeben — die Spieler, die in p<8-9> und p<7-8>
  # antreten, holen ihre Endplatzierung DORT und nicht ueber ihren Gruppenrang.
  def plan_with_advancement(rk)
    plan(players: 3,
      g1: {"pl" => 5, "rs" => "eae_pg", "sq" => {"r1" => {"t1" => "1-2"}}},
      "p<8-9>": {"r6" => {"t1" => ["g1.rk4", "g1.rk5"]}},
      "p<7-8>": {"r7" => {"t1" => ["g1.rk3", "p<8-9>.rk1"]}},
      RK: rk)
  end

  test "ein aufgestiegener Rang darf nicht zusaetzlich im RK stehen (T16neu)" do
    # Der Fehler vom 2026-09-04: "p<8-9>.rk1" belegte Platz 8, obwohl derselbe Spieler
    # in p<7-8> aufsteigt und dort Platz 7 holt. Er stand auf zwei Plaetzen, der Verlierer
    # von p<7-8> fiel ganz aus der Rangliste.
    defekt = plan_with_advancement(["p<7-8>.rk1", "p<8-9>.rk1", "p<8-9>.rk2"])

    assert_includes checks(defekt), :rk
    assert_match(/zieht weiter/, messages(defekt))
  end

  test "die korrigierte Fassung wird nicht gemeldet" do
    # So sieht T16neu nach dem Fix aus: p<7-8> entscheidet die Plaetze 7 und 8,
    # der Verlierer von p<8-9> ist Neunter.
    korrekt = plan_with_advancement(["p<7-8>.rk1", "p<7-8>.rk2", "p<8-9>.rk2"])

    refute_includes checks(korrekt), :rk
  end

  test "mehr RK-Plaetze als Spieler wird gemeldet" do
    zuviel = plan(players: 2, fin: {"r2" => {"t1" => ["g1.rk1", "g1.rk2"]}},
      RK: ["fin.rk1", "fin.rk2", "g1.rk3"])

    assert_includes checks(zuviel), :rk
    assert_match(/nur 2 Spieler/, messages(zuviel))
  end

  test "WENIGER RK-Plaetze als Spieler ist bei KO-Plaenen normal und wird nicht gemeldet" do
    # DKO_8_4 (id 110) vergibt mit ["fin.rk1", "fin.rk2"] bei 8 Spielern bewusst nur die
    # Finalplaetze — alle uebrigen Raenge ergeben sich aus der Runde des Ausscheidens.
    # Eine Gleichheitspruefung meldete am 2026-09-04 einundzwanzig korrekte Plaene.
    ko = plan(players: 8, fin: {"r3" => {"t1" => ["hf1.rk1", "hf2.rk1"]}},
      hf1: {"r2" => {"t1" => ["a", "b"]}}, hf2: {"r2" => {"t2" => ["c", "d"]}},
      RK: ["fin.rk1", "fin.rk2"])

    refute_includes checks(ko), :rk
  end

  test "ein RK-Element darf ein Array sein — mehrere Spieler teilen sich einen Platz" do
    # So bei allen KO_*-Plaenen: ["hf2.rk2", "hf1.rk2"] ist EIN Platz fuer ZWEI Spieler,
    # [] ist ein nicht vergebener Platz.
    ko = plan(players: 4, fin: {"r2" => {"t1" => ["hf1.rk1", "hf2.rk1"]}},
      hf1: {"r1" => {"t1" => ["a", "b"]}}, hf2: {"r1" => {"t2" => ["c", "d"]}},
      RK: ["fin.rk1", "fin.rk2", ["hf2.rk2", "hf1.rk2"], []])

    refute_includes checks(ko), :rk
  end

  test "zusammengesetzte RK-Ausdruecke werden nicht als unbekannter Bucket gemeldet" do
    # T21/T23 tragen "(g2.rk4 + g3.rk4).rk2" im RK — ein Ranking-Ausdruck ueber mehrere
    # Buckets. Ein naives split(".") las daraus den Bucket "(g2".
    zusammengesetzt = plan(players: 2,
      g2: complete_group_of_four, g3: complete_group_of_four,
      RK: ["g2.rk1", "(g2.rk4 + g3.rk4).rk2"])

    refute_includes checks(zusammengesetzt), :rk
  end

  test "KO-Buckets beginnen mit einer Ziffer und sind gueltig" do
    # "8f1", "16f1", "32f1" — ein Regex, der einen Buchstaben am Anfang verlangt, meldete
    # hier den Bucket "f1" als unbekannt.
    ko = plan(players: 2, "8f1": {"r1" => {"t1" => ["a", "b"]}}, RK: ["8f1.rk1", "8f1.rk2"])

    refute_includes checks(ko), :rk
  end

  test "eine RK-Referenz auf einen Bucket, den es nicht gibt, wird gemeldet" do
    defekt = plan(players: 2, g1: complete_group_of_four, RK: ["g1.rk1", "gibtsnicht.rk1"])

    assert_includes checks(defekt), :rk
    assert_match(/gibtsnicht/, messages(defekt))
  end

  test "eine doppelt vergebene RK-Referenz wird gemeldet" do
    defekt = plan(players: 2, g1: complete_group_of_four, RK: ["g1.rk1", "g1.rk1"])

    assert_includes checks(defekt), :rk
    assert_match(/doppelt/, messages(defekt))
  end

  # ==========================================================================
  # Pruefung: Tisch-Mehrfachverwendung  (die aus der Rake-Datei migrierte Pruefung)
  # ==========================================================================

  test "derselbe Tisch in derselben Runde fuer zwei Gruppen wird gemeldet" do
    konflikt = plan(
      g1: {"pl" => 2, "rs" => "eae_pg", "sq" => {"r1" => {"t1" => "1-2"}}},
      g2: {"pl" => 2, "rs" => "eae_pg", "sq" => {"r1" => {"t1" => "1-2"}}}
    )

    assert_includes checks(konflikt), :table_conflicts
    assert_match(/r1\.t1/, messages(konflikt))
  end

  test "derselbe Tisch in VERSCHIEDENEN Runden ist kein Konflikt" do
    ok = plan(
      g1: {"pl" => 2, "rs" => "eae_pg", "sq" => {"r1" => {"t1" => "1-2"}}},
      g2: {"pl" => 2, "rs" => "eae_pg", "sq" => {"r2" => {"t1" => "1-2"}}}
    )

    refute_includes checks(ok), :table_conflicts
  end

  # ==========================================================================
  # Ein vollstaendig korrekter Plan darf gar nichts melden
  # ==========================================================================

  test "ein durchgehend korrekter Plan erzeugt keinen einzigen Befund" do
    sauber = plan(players: 4,
      g1: complete_group_of_four,
      fin: {"r4" => {"t1" => ["g1.rk1", "g1.rk2"]}},
      "p<3-4>": {"r4" => {"t2" => ["g1.rk3", "g1.rk4"]}},
      rules: {"rule1" => "g1.rk1"},
      RK: ["fin.rk1", "fin.rk2", "p<3-4>.rk1", "p<3-4>.rk2"])

    assert_empty TournamentPlanValidator.new(sauber).findings,
      "Ein Pruefer mit Fehlalarmen wird ignoriert"
  end
end
