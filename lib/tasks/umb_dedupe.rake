# frozen_string_literal: true

# Ein Ort taugt, wenn er mehr sagt als "irgendwo in Land": leere Werte, reine
# "N/A"-Platzhalter und Reste wie ", Turkey" (Ergebnis des kaputten
# Location-Parsers) zaehlen nicht.
def brauchbarer_ort?(text)
  return false if text.blank?
  return false if text.strip.start_with?(",")
  return false if text.match?(/\AN\/A/i)
  true
end

namespace :umb do
  desc "Räumt doppelte UMB-Turniere zusammen — Trockenlauf, schreibt nur mit ARMED=1"
  task dedupe_tournaments: :environment do
    # Entstanden sind die Dubletten in der Duplikat-Pruefung des FutureScrapers:
    # sie filterte ueber location_text, und als die UMB-Uebersicht 2026 von
    # "CITY (Country)" auf "CITY / Country (Country)" wechselte, fand sie
    # bestehende Turniere nicht mehr wieder und legte bei jedem Lauf eine neue
    # Kopie an. Die Ursache ist behoben (location_text ist nur noch Tiebreaker);
    # dieser Task raeumt den Altbestand.
    #
    #   bin/rails umb:dedupe_tournaments            # zeigt nur, was passieren wuerde
    #   bin/rails umb:dedupe_tournaments ARMED=1    # fuehrt es aus
    #
    # Gruppiert wird streng nach identischem Titel UND identischem Datum — keine
    # Datumstoleranz, sonst wuerden echte Serienturniere (mehrere World Cups pro
    # Jahr) verschmolzen.
    armed = ENV["ARMED"].present? && ENV["ARMED"] != "0"

    umb_source = InternationalSource.find_by(source_type: "umb")
    abort "UMB-Quelle nicht gefunden." if umb_source.nil?

    scope = InternationalTournament.where(international_source: umb_source)

    puts "\n" + "=" * 78
    puts armed ? "UMB-DUBLETTEN ZUSAMMENFUEHREN  (ARMED — schreibt!)" : "UMB-DUBLETTEN — TROCKENLAUF (schreibt nichts)"
    puts "=" * 78

    if ApplicationRecord.local_server?
      puts "\nACHTUNG: Diese Instanz ist ein Local Server (carambus_api_url gesetzt)."
      puts "LocalProtector blockt das Aendern globaler Records — der Task gehoert auf die Authority."
      puts
    end

    gruppen = scope.group(:title, :date).having("COUNT(*) > 1").count
    puts "Dubletten-Gruppen: #{gruppen.size}   betroffene Datensaetze: #{gruppen.values.sum}"
    puts

    zusammengefuehrt = 0
    geloescht = 0
    umgehaengt = Hash.new(0)
    uebersprungen = []

    gruppen.keys.each do |(title, date)|
      records = scope.where(title: title, date: date).order(:id).to_a
      mit_ext = records.select { |r| r.external_id.present? }

      # Mehrere UMB-IDs in einer Gruppe: dann sind es entweder zwei echte
      # Turniereintraege oder UMB hat neu angelegt. Welcher gilt, ist von hier aus
      # nicht entscheidbar — anfassen waere geraten. Nur melden.
      if mit_ext.size > 1
        uebersprungen << {title: title, date: date, ids: mit_ext.map(&:external_id)}
        next
      end

      # Keeper: der Datensatz mit external_id — nur ueber ihn kann der
      # DetailsScraper spaeter die Detailseite nachladen. Gibt es keinen, gewinnt
      # der inhaltsreichste (Games/Seedings), bei Gleichstand der aelteste.
      keeper = mit_ext.first || records.max_by { |r| [r.games.count + r.seedings.count, -r.id] }
      duplikate = records - [keeper]
      next if duplikate.empty?

      # Der Keeper hat oft die schlechtere Ortsangabe: der DetailsScraper
      # uebernimmt den Rohwert der Detailseite ("N/A (France)", leer), waehrend
      # die Uebersicht "Blois, France" liefert. Beim Zusammenfuehren also den
      # aussagekraeftigsten Ort mitnehmen, statt Information wegzuwerfen.
      besserer_ort = records.map(&:location_text).compact.reject { |l| brauchbarer_ort?(l) == false }
        .max_by(&:length)
      ort_uebernehmen = besserer_ort.present? && !brauchbarer_ort?(keeper.location_text)

      puts "#{title[0, 46]}  (#{date.to_date})"
      puts "   BEHALTEN  id=#{keeper.id} ext=#{keeper.external_id.inspect} loc=#{keeper.location_text.inspect}"
      puts "   Ort wird uebernommen: #{besserer_ort.inspect}" if ort_uebernehmen

      duplikate.each do |dup|
        anhang = {
          games: dup.games.count,
          seedings: dup.seedings.count,
          videos: Video.where(videoable_type: dup.class.base_class.name, videoable_id: dup.id).count
        }
        anhang_text = anhang.reject { |_, v| v.zero? }.map { |k, v| "#{k}=#{v}" }.join(" ")
        anhang_suffix = anhang_text.present? ? "  [#{anhang_text}]" : ""
        puts "   zusammen  id=#{dup.id} loc=#{dup.location_text.inspect}#{anhang_suffix}"

        next unless armed

        # Erst umhaengen, dann loeschen: games/seedings haengen mit
        # dependent: :destroy am Turnier und wuerden sonst mitgeloescht.
        ActiveRecord::Base.transaction do
          if anhang[:games] > 0
            dup.games.update_all(tournament_id: keeper.id)
            umgehaengt[:games] += anhang[:games]
          end
          if anhang[:seedings] > 0
            dup.seedings.update_all(tournament_id: keeper.id)
            umgehaengt[:seedings] += anhang[:seedings]
          end
          if anhang[:videos] > 0
            Video.where(videoable_type: dup.class.base_class.name, videoable_id: dup.id)
              .update_all(videoable_id: keeper.id)
            umgehaengt[:videos] += anhang[:videos]
          end
          dup.reload.destroy!
          geloescht += 1
        end
      end

      if armed && ort_uebernehmen
        keeper.update_columns(location_text: besserer_ort)
      end

      zusammengefuehrt += 1
      puts
    end

    puts "-" * 78
    if armed
      puts "Zusammengefuehrte Gruppen: #{zusammengefuehrt}"
      puts "Geloeschte Datensaetze:    #{geloescht}"
      puts "Umgehaengt:                #{umgehaengt.map { |k, v| "#{k}=#{v}" }.join(" ")}" if umgehaengt.any?
    else
      puts "Wuerde #{zusammengefuehrt} Gruppen zusammenfuehren."
      puts "Es wurde NICHTS geschrieben — mit ARMED=1 ausfuehren."
    end

    if uebersprungen.any?
      puts
      puts "UEBERSPRUNGEN — mehrere UMB-IDs in derselben Gruppe (#{uebersprungen.size}):"
      uebersprungen.each do |u|
        puts "   #{u[:title][0, 44]} (#{u[:date].to_date}) — IDs #{u[:ids].join(", ")}"
      end
      puts "   Hier ist von aussen nicht entscheidbar, welcher Eintrag gilt."
      puts "   Auf files.umb-carom.org/public/TournametDetails.aspx?ID=<id> nachsehen:"
      puts "   liefert eine der IDs HTTP 500, existiert sie dort nicht mehr."
    end
    puts "=" * 78
  end
end
