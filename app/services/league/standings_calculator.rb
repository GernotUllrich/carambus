# frozen_string_literal: true

# Kapselt die Standings-Berechnungslogik aus dem League-Modell.
# Berechnet Tabellen für Karambol-, Snooker- und Pool-Ligen sowie den Spielplan.
#
# Verwendung:
#   League::StandingsCalculator.new(league).karambol
#   League::StandingsCalculator.new(league).snooker
#   League::StandingsCalculator.new(league).pool
#   League::StandingsCalculator.new(league).schedule_by_rounds
#
# PORO (kein ApplicationService) gemäß D-05 des Extraktionsplans.
class League::StandingsCalculator
  def initialize(league)
    @league = league
  end

  # Gibt die Tabelle für Karambol-Ligen zurück
  def karambol
    teams = @league.league_teams.to_a
    stats = teams.map do |team|
      parties_home = @league.parties.where(league_team_a: team)
      parties_away = @league.parties.where(league_team_b: team)
      parties_all = parties_home + parties_away
      spiele = parties_all.size
      gewonnen = 0
      unentschieden = 0
      verloren = 0
      punkte = 0
      diff = 0
      partien_gewonnen = 0
      partien_verloren = 0

      parties_all.each do |party|
        # Annahme: Ergebnis steht in party.data[:result] oder party.data["result"] als "x:y"
        result = party.data["result"] || party.data[:result]
        next unless result.present? && result.include?(":")
        if result == ":"
          left, right = [0, 0]
        else
          left, right = result.split(":").map(&:to_i)
        end
        if party.league_team_a_id == team.id
          team_for = left
          team_against = right
        else
          team_for = right
          team_against = left
        end
        diff += team_for - team_against
        partien_gewonnen += team_for
        partien_verloren += team_against
        if team_for > team_against
          gewonnen += 1
          punkte += 2
        elsif team_for == team_against
          unentschieden += 1
          punkte += 1
        else
          verloren += 1
        end
      end
      {
        team: team,
        name: team.name,
        spiele: spiele,
        gewonnen: gewonnen,
        unentschieden: unentschieden,
        verloren: verloren,
        punkte: punkte,
        diff: diff,
        partien: "#{partien_gewonnen}:#{partien_verloren}"
      }
    end
    # Sortierung: Punkte DESC, dann Diff DESC
    stats.sort_by.with_index { |row, idx| [-row[:punkte], -row[:diff], idx] }.each_with_index.map do |row, ix|
      row.merge(platz: ix + 1)
    end
  end

  # Gibt die Tabelle für Snooker-Ligen zurück
  def snooker
    teams = @league.league_teams.to_a
    stats = teams.map do |team|
      parties_home = @league.parties.where(league_team_a: team)
      parties_away = @league.parties.where(league_team_b: team)
      parties_all = parties_home + parties_away
      spiele = parties_all.size
      gewonnen = 0
      unentschieden = 0
      verloren = 0
      punkte = 0
      diff = 0
      frames_gewonnen = 0
      frames_verloren = 0

      parties_all.each do |party|
        # Annahme: Ergebnis steht in party.data[:result] oder party.data["result"] als "x:y"
        result = party.data["result"] || party.data[:result]
        next unless result.present? && result.include?(":")
        if result == ":"
          left, right = [0, 0]
        else
          left, right = result.split(":").map(&:to_i)
        end
        if party.league_team_a_id == team.id
          team_for = left
          team_against = right
        else
          team_for = right
          team_against = left
        end
        diff += team_for - team_against
        frames_gewonnen += team_for
        frames_verloren += team_against
        if team_for > team_against
          gewonnen += 1
          punkte += 2
        elsif team_for == team_against
          unentschieden += 1
          punkte += 1
        else
          verloren += 1
        end
      end
      {
        team: team,
        name: team.name,
        spiele: spiele,
        gewonnen: gewonnen,
        unentschieden: unentschieden,
        verloren: verloren,
        punkte: punkte,
        diff: diff,
        frames: "#{frames_gewonnen}:#{frames_verloren}"
      }
    end
    # Sortierung: Punkte DESC, dann Diff DESC
    stats.sort_by.with_index { |row, idx| [-row[:punkte], -row[:diff], idx] }.each_with_index.map do |row, ix|
      row.merge(platz: ix + 1)
    end
  end

  # Gibt die Tabelle für Pool-Ligen zurück
  def pool
    teams = @league.league_teams.to_a
    stats = teams.map do |team|
      parties_home = @league.parties.where(league_team_a: team)
      parties_away = @league.parties.where(league_team_b: team)
      parties_all = parties_home + parties_away
      spiele = parties_all.size
      gewonnen = 0
      unentschieden = 0
      verloren = 0
      punkte = 0
      diff = 0
      partien_gewonnen = 0
      partien_verloren = 0

      parties_all.each do |party|
        # Annahme: Ergebnis steht in party.data[:result] oder party.data["result"] als "x:y"
        result = party.data["result"] || party.data[:result]
        next unless result.present? && result.include?(":")
        if result == ":"
          left, right = [0, 0]
        else
          left, right = result.split(":").map(&:to_i)
        end
        if party.league_team_a_id == team.id
          team_for = left
          team_against = right
        else
          team_for = right
          team_against = left
        end
        diff += team_for - team_against
        partien_gewonnen += team_for
        partien_verloren += team_against
        if team_for > team_against
          gewonnen += 1
          punkte += 2
        elsif team_for == team_against
          unentschieden += 1
          punkte += 1
        else
          verloren += 1
        end
      end
      {
        team: team,
        name: team.name,
        spiele: spiele,
        gewonnen: gewonnen,
        unentschieden: unentschieden,
        verloren: verloren,
        punkte: punkte,
        diff: diff,
        partien: "#{partien_gewonnen}:#{partien_verloren}"
      }
    end
    # Sortierung: Punkte DESC, dann Diff DESC
    stats.sort_by.with_index { |row, idx| [-row[:punkte], -row[:diff], idx] }.each_with_index.map do |row, ix|
      row.merge(platz: ix + 1)
    end
  rescue => e
    Rails.logger.error("#{e.message}, #{e.backtrace}")
  end

  # Gibt den Spielplan gruppiert nach Hin- und Rückrunde zurück
  def schedule_by_rounds
    all_parties = @league.parties.order(:day_seqno, :date).to_a
    if @league.parties.first&.round_name.present?
      all_parties.sort_by do |p|
        "#{"%03d" % p.day_seqno}_#{p.round_name.to_s
                                    .gsub("Gruppe", "A")
                                    .gsub("Achtelfinale", "B")
                                    .gsub("Viertelfinale", "C")
                                    .gsub("Halbfinale", "D")
                                    .gsub("Finale", "E")}"
      end
      ordered_keys = all_parties.map(&:round_name).uniq

      # Then group by those ordered keys
      ordered_keys.each_with_object({}) do |key, hash|
        hash[key] = all_parties.select { |record| record.round_name == key }
      end
    else
      {"" => all_parties}
      # max_seqno = all_parties.map(&:day_seqno).max || 0
      # half = (max_seqno / 2.0).ceil
      # {
      #   "Hinrunde" => all_parties.select { |p| p.day_seqno && p.day_seqno <= half },
      #   "Rückrunde" => all_parties.select { |p| p.day_seqno && p.day_seqno > half }
      # }
    end
  end
end
