# frozen_string_literal: true

# Auswertung der am Scoreboard gesicherten Trainingsspiele.
#
# Entstanden aus einer Ad-hoc-Abfrage vom 2026-09-10, die dreimal nachgebaut werden
# musste — einmal falsch, weil die Disziplin an einer anderen Stelle steht als vermutet
# (siehe unten). Der Task haelt die drei Fallstricke fest, damit sie nicht bei jeder
# Auswertung neu gefunden werden.
namespace :training do
  desc "Trainingsspiele der letzten N Wochen (Standard 3) als Tabelle oder CSV: training:report[4,csv]"
  task :report, %i[weeks format] => :environment do |_t, args|
    weeks = (args[:weeks] || 3).to_i
    weeks = 3 unless weeks.positive?
    format = (args[:format] || "table").to_s.downcase
    abort "format muss 'table' oder 'csv' sein (war: #{format})" unless %w[table csv].include?(format)

    since = weeks.weeks.ago
    rows = TrainingReport.rows(since)

    if rows.empty?
      puts "Keine gewerteten Trainingsspiele seit #{since.to_date}."
      next
    end

    if format == "csv"
      path = Rails.root.join("tmp", "training_#{since.to_date}_bis_#{Date.current}.csv")
      TrainingReport.write_csv(rows, path)
      puts "#{rows.size} Trainingsspiele seit #{since.to_date}"
      puts path
    else
      puts TrainingReport.table(rows)
      puts
      puts "#{rows.size} gewertete Trainingsspiele seit #{since.to_date}"
    end
  end
end

# Im Task-Namespace gehalten, nicht unter app/ — das ist eine Auswertung fuer die
# Kommandozeile, kein Anwendungsverhalten.
module TrainingReport
  HEADER = %w[date_time player_a player_b disziplin balls_a balls_b innings_a innings_b
    hs_a hs_b gd_a gd_b game_id].freeze

  module_function

  def rows(since)
    # `Game.training` (game.rb) haelt Turnierspiele, globale Records und importierte
    # Partien heraus — genau die Abgrenzung, die diese Auswertung braucht.
    scope = Game.training
      .where("games.created_at >= ?", since)
      .where.not(ended_at: nil)
      .includes(game_participations: :player)
      .order(:ended_at)

    scope.filter_map do |game|
      a = game.game_participations.find { |gp| gp.role.to_s == "playera" }
      b = game.game_participations.find { |gp| gp.role.to_s == "playerb" }
      next if a.nil? || b.nil?

      # Abgebrochene Spiele tragen ueberall nil und ergaeben eine Zeile aus Doppelpunkten.
      # Am 2026-09-10 waren das 61 von 94 beendeten Partien — sie gehoeren nicht in eine
      # Leistungsuebersicht.
      next if a.result.nil? && b.result.nil?

      [
        (game.ended_at || game.created_at).strftime("%Y-%m-%d %H:%M"),
        a.player&.fl_name.to_s,
        b.player&.fl_name.to_s,
        discipline_of(a, b),
        a.result, b.result, a.innings, b.innings, a.hs, b.hs,
        a.gd, b.gd, game.id
      ]
    end
  end

  # Die Disziplin steht NICHT in games.data, sondern je Teilnehmer in
  # game_participations.data — `TrainingResultRecorder::PARTICIPATION_CONTEXT_KEYS`
  # kopiert sie dorthin, weil sie sich bei Handicap zwischen den Spielern
  # unterscheiden kann. Wer sie in games.data sucht, findet dort nur innings_goal
  # und sets_to_play und haelt die Disziplin faelschlich fuer nicht gespeichert.
  def discipline_of(part_a, part_b)
    da = (part_a.data || {})["discipline"]
    db = (part_b.data || {})["discipline"]
    return da.to_s if da == db

    [da, db].compact.join(" / ")
  end

  def table(rows)
    # Auch hier zwei Nachkommastellen: sonst steht "5.0" neben "0.48" und die Spalte
    # ist schlechter zu ueberfliegen. Punkt statt Komma — im Terminal ist das die
    # gewohnte Schreibweise, die Komma-Variante gilt nur fuer die CSV.
    formatted = rows.map do |r|
      r.each_with_index.map { |v, i| ([10, 11].include?(i) && !v.nil?) ? format("%.2f", v.to_f) : v }
    end
    all = [HEADER] + formatted.map { |r| r.map(&:to_s) }
    width = HEADER.each_index.map { |i| all.map { |r| r[i].length }.max }
    line = ->(r) { r.each_with_index.map { |c, i| c.ljust(width[i]) }.join("  ").rstrip }
    ([line.call(all.first), width.map { |n| "-" * n }.join("  ")] +
      all.drop(1).map { |r| line.call(r) }).join("\n")
  end

  def write_csv(rows, path)
    require "csv"
    csv = CSV.generate(col_sep: ";") do |out|
      out << HEADER
      rows.each do |r|
        # Dezimalkomma fuer den GD, damit eine deutsch eingestellte Tabellenkalkulation
        # 5,00 als Zahl liest und nicht als Text.
        out << r.each_with_index.map { |v, i| [10, 11].include?(i) ? decimal(v) : v }
      end
    end
    FileUtils.mkdir_p(File.dirname(path))
    # BOM: ohne ihn zeigt Excel "MeiÃŸner" statt "Meißner" — bei diesen Namen
    # betrifft das rund ein Drittel der Zeilen.
    File.write(path, "﻿#{csv}")
  end

  def decimal(value)
    return "" if value.nil?

    format("%.2f", value.to_f).tr(".", ",")
  end
end
