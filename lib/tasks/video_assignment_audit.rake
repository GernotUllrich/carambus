# frozen_string_literal: true

namespace :videos do
  desc "Prueft bestehende Video-Turnier-Zuordnungen gegen die Ausschlussregeln (ARMED=1 loest sie)"
  task audit_tournament_assignments: :environment do
    # Die Zuordnung laeuft taeglich automatisch
    # (DailyInternationalScrapeJob -> Video::TournamentMatcher.call). Bis zu den
    # Ausschlussregeln vom 2026-08-16 konnten Datum (0.40) + Spieler (0.35)
    # allein die Schwelle 0.75 reissen — der Titel hatte kein Veto. Dieser Task
    # findet die Altlasten, die unter den heutigen Regeln nicht mehr entstuenden.
    #
    #   bin/rails videos:audit_tournament_assignments           # nur zeigen
    #   bin/rails videos:audit_tournament_assignments ARMED=1   # loesen
    armed = ENV["ARMED"].present?
    matcher = Video::TournamentMatcher.new

    # Nur Turnier-Zuordnungen: `videoable` traegt auch Game-Bindungen
    # (video_game_matching.rake), und die entstehen auf einem anderen Weg.
    scope = Video.where(videoable_type: "Tournament").where.not(videoable_id: nil)
    puts "\n" + "=" * 78
    puts "AUDIT bestehender Video-Zuordnungen#{armed ? "  [ARMED — loest Zuordnungen]" : "  (Trockenlauf)"}"
    puts "=" * 78
    puts "Turnier-Zuordnungen: #{scope.count}  (von #{Video.where.not(videoable_id: nil).count} Zuordnungen gesamt)"

    fremd = []
    jahr = []
    geprueft = 0

    scope.includes(:videoable).find_each(batch_size: 300) do |video|
      tournament = video.videoable
      next if tournament.blank? || !tournament.respond_to?(:date)

      geprueft += 1
      if matcher.send(:foreign_discipline?, video.title)
        fremd << [video, tournament]
      elsif matcher.send(:conflicting_year?, video.title, tournament)
        jahr << [video, tournament]
      end
    end

    puts "geprueft:           #{geprueft}"
    puts
    puts "A) fremde Disziplin im Videotitel: #{fremd.size}"
    fremd.first(12).each { |v, t| puts "     #{v.title.to_s[0, 62]}\n        -> #{t.title.to_s[0, 46]}" }
    puts "     ... (#{fremd.size - 12} weitere)" if fremd.size > 12
    puts
    puts "B) abweichendes Jahr im Videotitel: #{jahr.size}"
    jahr.first(12).each { |v, t| puts "     #{v.title.to_s[0, 62]}\n        -> #{t.title.to_s[0, 40]} (#{t.date&.to_date})" }
    puts "     ... (#{jahr.size - 12} weitere)" if jahr.size > 12
    puts

    betroffen = fremd + jahr
    if betroffen.empty?
      puts "Nichts zu tun."
    elsif armed
      # Nur die Zuordnung loesen, das Video bleibt. Beim naechsten Lauf des
      # Matchers wird es neu bewertet — und dann von den Regeln abgewiesen.
      betroffen.each { |v, _t| v.update_columns(videoable_id: nil, videoable_type: nil) }
      puts "#{betroffen.size} Zuordnungen geloest (Videos bleiben erhalten)."
    else
      puts "#{betroffen.size} Zuordnungen wuerden geloest. Mit ARMED=1 ausfuehren."
    end
    puts
  end
end
