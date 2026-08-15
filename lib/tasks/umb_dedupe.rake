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
      puts "   Mit PURGE_DEAD=1 werden diese Gruppen live gegen UMB geprueft und"
      puts "   geloescht, wenn dort KEINE der IDs mehr existiert."
    end

    # Zurueckgezogene Turniere: liefert die Detailseite zu JEDER external_id der
    # Gruppe HTTP 500, hat UMB den Eintrag entfernt. Solche Termine stehen sonst
    # mit state "finished" im Bestand, obwohl sie nie stattgefunden haben — und
    # ziehen im Video-Matcher Videos an, weil ihr Datumsfenster passt.
    # Geloescht wird nur, was nachweislich weg ist UND woran nichts haengt.
    if ENV["PURGE_DEAD"].present? && uebersprungen.any?
      puts
      puts "-" * 78
      puts "PRUEFE ZURUECKGEZOGENE TURNIERE GEGEN UMB"
      puts "-" * 78
      details = Umb::DetailsScraper.new
      purge_gruppen = 0
      purge_records = 0

      uebersprungen.each do |u|
        records = scope.where(title: u[:title], date: u[:date]).to_a
        lebt = u[:ids].select { |ext| details.send(:fetch_tournament_basic_data, ext.to_i).present? }
        anhang = records.sum { |r| r.games.count + r.seedings.count } +
          Video.where(videoable_type: "Tournament", videoable_id: records.map(&:id)).count

        puts "#{u[:title][0, 44]} (#{u[:date].to_date})"
        if lebt.any?
          puts "   BEHALTEN — bei UMB existiert noch: #{lebt.join(", ")}"
          next
        elsif anhang > 0
          puts "   BEHALTEN — bei UMB weg, aber #{anhang} Games/Seedings/Videos haengen daran"
          next
        end

        puts "   bei UMB entfernt (alle IDs #{u[:ids].join(", ")} liefern 500), nichts haengt daran"
        puts "   -> #{records.size} Datensaetze #{armed ? "werden geloescht" : "wuerden geloescht"}"
        if armed
          records.each(&:destroy!)
          purge_records += records.size
        end
        purge_gruppen += 1
      end

      puts
      puts armed ? "Geloescht: #{purge_records} Datensaetze aus #{purge_gruppen} Gruppen" : "Wuerde #{purge_gruppen} Gruppen loeschen (ARMED=1 zum Ausfuehren)"
    end
    puts "=" * 78
  end
end

namespace :umb do
  desc "Setzt state (planned/finished) anhand des Turnierdatums — Trockenlauf, schreibt nur mit ARMED=1"
  task fix_states: :environment do
    # Der DetailsScraper setzte den State pauschal auf "finished" — auch fuer
    # Termine, die noch bevorstehen (im Bestand bis 2030). FutureScraper und
    # ArchiveScraper machen es datumsabhaengig richtig; seit dem Fix tut es der
    # DetailsScraper auch. Dieser Task zieht den Altbestand nach.
    #
    # "planned"/"finished" sind KEINE AASM-States der Tournament-Statemaschine,
    # sondern eine eigene Konvention der internationalen Scraper — deshalb hier
    # update_columns statt AASM-Events.
    armed = ENV["ARMED"].present? && ENV["ARMED"] != "0"
    umb_source = InternationalSource.find_by(source_type: "umb")
    abort "UMB-Quelle nicht gefunden." if umb_source.nil?

    scope = InternationalTournament.where(international_source: umb_source).where.not(date: nil)
    zu_planned = scope.where(state: "finished").where("date > ?", Date.current)
    zu_finished = scope.where(state: "planned").where("date < ?", Date.current)

    puts "\n" + "=" * 78
    puts armed ? "UMB-STATES KORRIGIEREN (ARMED — schreibt!)" : "UMB-STATES — TROCKENLAUF (schreibt nichts)"
    puts "=" * 78
    puts "finished, aber Datum in der Zukunft: #{zu_planned.count}  -> planned"
    puts "planned, aber Datum in der Vergangenheit: #{zu_finished.count}  -> finished"
    puts

    zu_planned.order(:date).limit(8).each { |t| puts "   #{t.date.to_date}  #{t.title[0, 50]}" }
    puts "   ..." if zu_planned.count > 8

    if armed
      p_count = zu_planned.update_all(state: "planned")
      f_count = zu_finished.update_all(state: "finished")
      puts "\nKorrigiert: #{p_count} -> planned, #{f_count} -> finished"
    else
      puts "\nEs wurde NICHTS geschrieben — mit ARMED=1 ausfuehren."
    end
    puts "=" * 78
  end
end
