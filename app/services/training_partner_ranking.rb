# frozen_string_literal: true

# Liefert zu einem geplanten Trainingsspiel die zuletzt passend aktiven Spieler
# (Milestone v0.3, Plan 02-02).
#
# Wozu: Am Scoreboard ist die Spielerliste alphabetisch und umfasst den ganzen Kader.
# Wer zuletzt genau so trainiert hat, ist der wahrscheinlichste Kandidat — diese Liste
# fuellt die Kopfgruppe "Zuletzt" ueber der unveraenderten Vollliste.
#
# Datenbasis ist AUSSCHLIESSLICH Game.training (Betreiber-Entscheidung 2026-08-29).
# Turnierspiele und App-Turnierspiele bleiben draussen, obwohl sie um ein Vielfaches
# zahlreicher sind: sie sagen nichts darueber, wer am Trainingstisch auftaucht.
#
# Den Spielkontext (discipline, balls_goal) schreibt TableMonitor::TrainingResultRecorder
# beim Finalisieren in game_participations.data — siehe Plan 02-01. Nur gewertete Spiele
# tragen ihn, deshalb ist "hat ein Ergebnis" zugleich das Kriterium fuer verwertbare
# Historie.
#
# Verwendung:
#   TrainingPartnerRanking.call(location: loc, discipline: "Freie Partie klein", balls_goal: 40)
#   #=> [player_id, player_id, ...]  (hoechstens LIMIT Eintraege, Rangfolge = Aktualitaet)
class TrainingPartnerRanking < ApplicationService
  # Wie viele Spieler die Kopfgruppe hoechstens zeigt.
  #
  # 2026-09-01 von 6 auf 12 erhoeht: bei 1280x720 traegt eine Zeile rund sechs Namen, und
  # unter der Auswahl blieb reichlich Platz ungenutzt (Bildschirmfoto vom Clubabend). Zwei
  # Zeilen statt einer erhoehen die Trefferchance der Kopfgruppe, ohne die Vollliste
  # darunter zu verdraengen.
  DEFAULT_LIMIT = 12

  # Wie viele Trainingsspiele ueberhaupt betrachtet werden, juengste zuerst.
  #
  # ⚠️ Diese Grenze ist nicht kosmetisch. Der Kontextvergleich laeuft in Ruby, weil
  # games.data eine serialisierte Textspalte ist (game.rb:73) und ein SQL-Vergleich auf
  # einzelne Schluessel dort nicht sauber moeglich waere. An einem Clubabend entstehen
  # laut Betreiber ueber 30 Spiele — rund 3000 Teilnahmen im Jahr. Ohne Grenze wuerde
  # die Schnellstart-Seite auf dem Raspi mit der Zeit spuerbar langsamer.
  # Fuer ein Ranking nach Aktualitaet ist die Grenze kein Verlust: was aelter ist als
  # die juengsten SCAN_LIMIT Spiele, koennte die Kopfgruppe ohnehin nicht mehr erreichen.
  SCAN_LIMIT = 300

  # Leitet aus einem Preset-Knopf (Carambus.config.quick_game_presets) die beiden
  # Ranking-Parameter ab — die EINZIGE Stelle, die das tut.
  #
  # Warum zentral: Controller und View brauchen dieselbe Ableitung, und die Quelle des
  # Ballziels unterscheidet sich je Tischart — die BK-Familie legt es in `balls_goal`,
  # Karambol in `balls`, Pool und Snooker spielen auf Saetze und haben keins. Zwei
  # Kopien dieser Regel wuerden auseinanderlaufen und das Ranking stumm ins Leere
  # laufen lassen (gleiche Haltung wie bei Game#substanceless? in Plan 02-01).
  def self.params_from_preset(button)
    button = button.to_h.stringify_keys
    {
      discipline: button["discipline"].presence,
      balls_goal: button["balls_goal"].presence || button["balls"].presence,
      # Wie beim Ballziel unterscheidet sich die Quelle je Tischart: die BK-Familie legt
      # das Aufnahmenziel in `innings_goal`, Karambol in `innings`. Pool und Snooker
      # spielen auf Saetze und haben keins — dann bleibt der Wert leer und die
      # zusaetzliche Kaskadenstufe greift einfach nicht.
      innings_goal: button["innings_goal"].presence || button["innings"].presence
    }
  end

  # Schluessel, unter dem ein vorberechnetes Ranking abgelegt und im Browser wieder
  # gefunden wird. Bewusst aus den Parametern gebildet und NICHT aus der button_id:
  # deren Bildung ist eine mehrzeilige Fallunterscheidung im Partial, die hier
  # dupliziert werden muesste.
  #
  # ⚠️ Seit 2026-09-01 gehen die AUFNAHMEN mit ein. Vorher teilten sich Knoepfe mit
  # gleicher Disziplin und Distanz ein Ranking, "100/20" und "100/30" zeigten also
  # dieselben Namen. Der Betreiber hat am Scoreboard klargestellt: massgeblich ist die
  # Kombination Disziplin/Baelle/Aufnahmen — also genau der Schnellwahl-Knopf. Nur so
  # traegt die Kopfgruppe ihre Beschriftung zu Recht.
  def self.preset_key(discipline, balls_goal, innings_goal = nil)
    "#{discipline}|#{balls_goal}|#{innings_goal}"
  end

  def initialize(kwargs = {})
    @location = kwargs[:location]
    @discipline = kwargs[:discipline].presence
    @balls_goal = kwargs[:balls_goal].presence
    @innings_goal = kwargs[:innings_goal].presence
    @limit = kwargs[:limit] || DEFAULT_LIMIT
  end

  # Vierstufige Kaskade, jede Stufe fuer sich nach Aktualitaet sortiert:
  #   1. gleiche Disziplin, Distanz UND Aufnahmen  (genau der Schnellwahl-Knopf)
  #   2. gleiche Disziplin UND gleiche Distanz
  #   3. gleiche Disziplin
  #   4. irgendein gewertetes Trainingsspiel
  #
  # Warum die Kaskade: zum Zeitpunkt von Plan 02-02 traegt KEIN einziges Spiel Kontext
  # (die drei gewerteten stammen aus dem UAT zu Phase 1, ihr Kontext war nicht
  # rekonstruierbar). Ohne die Kaskade bliebe die Kopfgruppe leer, bis genug neue Spiele
  # aufgelaufen sind. Sobald der Bestand waechst, trifft Stufe 1 und die spaeteren
  # Stufen kommen nur noch bei selten gespielten Presets zum Zug.
  def call
    return [] if candidates.blank?

    # ⚠️ Die erste Stufe, die etwas findet, GEWINNT — es wird nicht ueber Stufengrenzen
    # hinweg aufgefuellt.
    #
    # Bis 2026-09-01 wurden die Stufen aneinandergehaengt, bis das Limit voll war. Solange
    # die Gruppe sechs Namen zeigte und "Zuletzt" hiess, fiel das kaum auf. Mit zwoelf
    # Plaetzen und der Ueberschrift "Schon gespielt von — Freie Partie klein · 80 · 20"
    # wurde es falsch: dort stand ein einziger exakter Treffer, aufgefuellt mit elf
    # Spielern, die genau diese Kombination nie gespielt hatten. Die Ueberschrift
    # behauptete damit etwas, das die Liste nicht hergab (Betreiber-Befund am Scoreboard).
    #
    # Lieber vier ehrliche Namen als zwoelf, von denen acht nichts damit zu tun haben. Die
    # Kaskade bleibt als Netz: hat die genaueste Stufe nichts, greift die naechstgroebere
    # GANZ — und die Gruppe ist nie leer, solange ueberhaupt Historie da ist.
    [preset_matches, exact_matches, discipline_matches, candidates].each do |stufe|
      next if stufe.blank?

      return stufe.first(@limit)
    end
    []
  rescue => e
    # Ein fehlgeschlagenes Ranking darf die Spielerauswahl nie blockieren — die
    # Vollliste steht ohnehin darunter und ist der verlaessliche Weg.
    Rails.logger.error "ERROR: TrainingPartnerRanking[#{@location&.id}]#{e}"
    []
  end

  private

  # Die juengsten gewerteten Trainingsteilnahmen, absteigend nach Spielbeginn.
  # Bereits auf den Kader des Standorts eingeschraenkt, damit die Kopfgruppe niemanden
  # zeigen kann, den die Vollliste darunter nicht enthaelt.
  def participations
    @participations ||= begin
      ids = eligible_player_ids
      if ids.blank?
        []
      else
        GameParticipation
          .joins(:game)
          .merge(Game.training)
          .where.not(result: nil)
          .where(player_id: ids)
          # Spiele absteigend (juengstes zuerst), INNERHALB eines Spiels aber aufsteigend:
          # so steht playera vor playerb statt umgekehrt. Rein fachlich sind beide
          # gleichwertig — die feste Reihenfolge macht das Ergebnis nur vorhersagbar.
          .order("games.created_at DESC", "game_participations.id ASC")
          .limit(SCAN_LIMIT)
          # ⚠️ preload, nicht includes: die Beziehung ist oben schon fuer `merge(Game.training)`
          # und die Sortierung gejoint. Ohne das Vorladen entstuenden bis zu SCAN_LIMIT
          # Einzelabfragen, sobald Stufe 1 das Aufnahmenziel aus games.data liest — auf dem
          # Raspi genau der Kostenpunkt, den SCAN_LIMIT vermeiden soll.
          .preload(:game)
          .to_a
      end
    end
  end

  # Spieler in Rangfolge, ohne Duplikate.
  def candidates
    @candidates ||= participations.map(&:player_id).uniq
  end

  # Stufe 1: genau die Kombination des Schnellwahl-Knopfes.
  #
  # ⚠️ Das Aufnahmenziel steht NICHT in game_participations.data, sondern in games.data —
  # TrainingResultRecorder teilt den Kontext bewusst auf (PARTICIPATION_CONTEXT_KEYS vs.
  # GAME_CONTEXT_KEYS), weil balls_goal und discipline je Spieler gelten, innings_goal
  # dagegen fuer das ganze Spiel. Deshalb bekommt der Block hier beide Haelften.
  def preset_matches
    return [] if @discipline.blank? || @balls_goal.blank? || @innings_goal.blank?

    filtered do |data, spiel|
      data["discipline"] == @discipline &&
        data["balls_goal"].to_s == @balls_goal.to_s &&
        spiel["innings_goal"].to_s == @innings_goal.to_s
    end
  end

  def exact_matches
    return [] if @discipline.blank? || @balls_goal.blank?

    filtered { |data, _spiel| data["discipline"] == @discipline && data["balls_goal"].to_s == @balls_goal.to_s }
  end

  def discipline_matches
    return [] if @discipline.blank?

    filtered { |data, _spiel| data["discipline"] == @discipline }
  end

  def filtered
    participations.select { |gp| yield(gp.data || {}, gp.game&.data || {}) }.map(&:player_id).uniq
  end

  # Kader des Standorts in der laufenden Saison.
  #
  # ⚠️ Bewusst KEIN Gast-Ausschluss noetig: Spiele mit Gastbeteiligung bekommen nie ein
  # Ergebnis, weil TrainingResultRecorder sie ablehnt (Guard aus Plan 01-01). Sie fallen
  # bereits ueber `where.not(result: nil)` heraus.
  # ⚠️ Bewusst NICHT Player.default_guest verwenden — die Methode LEGT fehlende
  # Gast-Records an (player.rb:159); eine lesende Abfrage darf nichts erzeugen.
  def eligible_player_ids
    club = @location&.club
    season = Season.current_season
    return [] if club.blank? || season.blank?

    SeasonParticipation.where(club_id: club.id, season_id: season.id).pluck(:player_id).compact.uniq
  end
end
