# frozen_string_literal: true

module RegionServer
  # Plan 35-02: Der universelle Karambol-AKZEPTANZPLAN — der Namensraum, den die Ergebnisannahme
  # auf dem Region Server gelten laesst.
  #
  # ZWEI-PLAENE-MODELL (Betreiber 2026-07-25): Ein Turnier hat zwei verschiedene "Plaene".
  #   - der EXEKUTIERBARE Plan (TournamentPlan/`executor_params`) sagt, was der TableMonitor am
  #     Spielort abspielt — welche Paarungen in welcher Runde an welchem Tisch;
  #   - der AKZEPTANZ-Plan sagt, welche Spielnamen als Ergebnis eintreffen duerfen.
  # Bei Karambol-Einzelturnieren fallen sie auseinander: die ClubCloud nimmt Ergebnisse gegen einen
  # universellen Namensraum an (Gruppen + Runden + KO-Stufen), unabhaengig davon, nach welchem
  # Modus tatsaechlich gespielt wurde. Der Region Server ist der CC-Ersatz und muss das ebenso tun.
  #
  # WARUM DAS DEN 32-08-FEHLER KORRIGIERT: Dort wurde der Namensraum aus den `executor_params` des
  # exekutierbaren Plans abgeleitet. Damit bestimmte eine Entscheidung am SPIELORT, welche
  # Ergebnisse der Region Server annimmt — und Ergebnisse, die gar nicht aus dem TableMonitor
  # stammen (manuelle Eingabe aus Spielberichten, Plan 35-03), waeren strukturell nicht
  # einlieferbar gewesen.
  #
  # WARUM CODE-KONSTANTE UND KEIN DB-RECORD (Entscheidung 2a, Betreiber 2026-07-29):
  # `tournaments.tournament_plan_id` traegt heute FUENF Bedeutungen — Executor (TableMonitor),
  # Tischzahl (tournament.rb:647), Discipline-Parameter-Lookup (discipline.rb:203), Ingest-Selektor
  # und Season-Copy. Einen Akzeptanzplan dort einzuhaengen wuerde auf Turnierdurchfuehrung und
  # Parameterbestimmung abfaerben — genau die Vermischung, die das Zwei-Plaene-Modell aufloest.
  # Dazu verhindert `LocalProtector` das Anlegen globaler Records auf Region-/Location-Servern,
  # und `TournamentPlan` hat weder `data`-Spalte noch jsonb.
  #
  # VOKABULAR — HAEUFIGSTE VERWECHSLUNG: Die Namen hier stehen in der Form, die
  # `Setting.map_game_gname_to_cc_group_name` AUSGIBT ("Gruppe A", "Spiel um Platz 3").
  # `GroupCc::NAME_MAPPING` normalisiert dagegen in die andere Richtung, auf Carambus-Namen
  # ("Gruppe A" => "Gruppe 1", "Spiel um Platz 3" => "Platz 3-4"). Deshalb wird der Namensraum
  # hier NICHT aus NAME_MAPPING abgeleitet — die Zielvokabulare sind verschieden. Die Konsistenz
  # zur Senderseite sichert stattdessen ein Test (AC-6), der die Bildmenge des Mappings durchprueft.
  class AcceptancePlan
    # Feste Namen ohne variablen Zaehler.
    FIXED_NAMES = [
      "Finale",
      "Halbfinale",
      "Viertelfinale",
      "Achtelfinale",
      # Schreibweise wie in Game::RANKING_KEY_PATTERNS (game.rb:258-260)
      "1/16 Finale",
      "1/32 Finale",
      "1/64 Finale",
      # Rundenbegriffe der Berichtsform — die CC fuehrt sie, der TableMonitor erzeugt sie nicht.
      "Hauptrunde",
      "Endrunde"
    ].freeze

    # Namen mit variablem Zaehler. Bewusst als Muster statt als erschoepfende Liste: ein starres
    # Set wuerde "Runde 8" oder "Spiel um Platz 15" grundlos abweisen, obwohl beides regulaer ist.
    #
    # Gruppen laufen bis Z, nicht bis H: `map_game_gname_to_cc_group_name` bildet 1..26 auf A..Z ab
    # (setting.rb, dynamische Gruppenextraktion). Enger zu sein hiesse, einen Namen abzulehnen,
    # den die eigene Senderseite erzeugen kann.
    COUNTED_PATTERNS = [
      /\AGruppe [A-Z]\z/,
      /\ARunde \d+\z/,
      /\ASpiel um Platz \d+\z/,
      /\A\d+\. Gewinnerrunde\z/,
      /\A\d+\. Verliererrunde\z/
    ].freeze

    class << self
      # Der Kern: Ist dieser Spielname als Ergebnis annehmbar?
      #
      # Die Pruefung ist ein TIPPFEHLER-SCHUTZ, kein Zugangsschutz (so schon im Kommentar an
      # GameResultIngest). Sie darf grosszuegig sein, aber nicht beliebig — "Halbfinaie" und
      # "Gruppe Z9" muessen auffallen.
      def accepts?(name)
        normalized = name.to_s.strip
        return false if normalized.blank?

        FIXED_NAMES.include?(normalized) || COUNTED_PATTERNS.any? { |p| p.match?(normalized) }
      end

      # Fuer Diagnose/Fehlermeldungen: die festen Namen. Die gezaehlten Formen lassen sich nicht
      # aufzaehlen — dafuer ist `accepts?` da.
      def fixed_names
        FIXED_NAMES
      end
    end
  end
end
