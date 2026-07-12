namespace :disciplines do
  desc "Titel-Synonyme auf den Disziplinen ergaenzen (idempotent). DRY-RUN default; ARMED=1 mutiert. Nur Authority."
  task extend_title_synonyms: :environment do
    raise "Abbruch: nur auf der Authority ausfuehren (Carambus.config.carambus_api_url muss leer sein)" if ApplicationRecord.local_server?

    # Kuratierte Titel-Synonyme, damit Discipline.classify_from_title (generischer Synonym-Match)
    # deutsche/abgekuerzte Titel-Schreibweisen findet — und der Scraper aus derselben Quelle schoepft.
    # Keyed by Disziplin-NAME (robust gg. id-Aenderung). Karambol-Familien/Cadre/Snooker werden vom
    # Matcher strukturell behandelt (keine Synonyme noetig). Kegel-DUBLETTEN (5 Kegel/5-Kegel,
    # Billard-Kegeln-Varianten) werden bewusst NICHT disambiguiert -> bleiben Triage.
    synonyms_by_name = {
      "10-Ball" => ["10er Ball", "10 Ball"],
      "8-Ball" => ["8er Ball", "8 Ball"],
      "9-Ball" => ["9er Ball", "9 Ball"],
      "14.1 endlos" => ["14/1", "14.1", "14er"],
      "5-Pin Billards" => ["5-Pin", "5 Pin", "5-Pins", "5 Pins", "5Kegel"],
      "Ausstoßen" => ["Ausstoss"],
      "BK-2kombi" => ["BK2-kombi", "BK2 Kombi", "BK2kombi"],
      # Kuratierte internationale Brand-Namen (3-Band-Events, Titel verraet die Disziplin nicht) -> Dreiband groß.
      # User-Domaenenentscheidung 2026-07-12 (Triage-Review).
      "Dreiband groß" => ["Lausanne Billard Masters", "Verhoeven Open", "Continental Cup", "AGIPI",
        "Sang Lee", "Crystal Kelly", "Super-Cup", "Player of the Year", "Carom Cafe", "Femina Belgian Open"],
      "Snooker" => ["Billiard Charity Challenge"],
      "Pool" => ["USBA Women"]
    }

    armed = ENV["ARMED"] == "1"
    puts "== disciplines:extend_title_synonyms — #{armed ? "ARMED (mutating)" : "DRY-RUN (read-only preview)"} =="

    added = 0
    Discipline.skip_cable_ready_updates do
      synonyms_by_name.each do |name, syns|
        d = Discipline.find_by(name: name)
        unless d
          puts "  ?? Disziplin nicht gefunden: #{name.inspect} (uebersprungen)"
          next
        end
        existing = d.synonyms.to_s.split("\n")
        missing = syns.reject { |s| existing.include?(s) }
        next if missing.empty?

        puts "  #{name} (##{d.id}) += #{missing.inspect}"
        added += missing.size
        d.update!(synonyms: (existing + missing).uniq.join("\n")) if armed
      end
    end

    puts armed ? "Fertig: #{added} Synonym-Zeile(n) ergaenzt." : "DRY-RUN: #{added} Synonym-Zeile(n) wuerden ergaenzt. ARMED=1 zum Schreiben."
  end

  desc "Unbranchten Turnieren (discipline_id nil ODER 'Unknown Discipline') die exakte Disziplin aus dem Titel zuweisen. DRY-RUN default; ARMED=1 mutiert. Nur Authority + PaperTrail."
  task backfill_from_title: :environment do
    raise "Abbruch: nur auf der Authority ausfuehren (Carambus.config.carambus_api_url muss leer sein)" if ApplicationRecord.local_server?
    unless PaperTrail.enabled? && PaperTrail.request.enabled?
      raise "Abbruch: PaperTrail ist deaktiviert — ohne neue Versionen erreicht der Backfill keinen Regional-Server"
    end

    armed = ENV["ARMED"] == "1"
    puts "== disciplines:backfill_from_title — #{armed ? "ARMED (mutating)" : "DRY-RUN (read-only preview)"} =="

    unknown_id = Discipline.find_by(name: "Unknown Discipline")&.id
    scope = Tournament.where("discipline_id IS NULL OR discipline_id = ?", unknown_id)
    puts "Selektiert: #{scope.count} unbranchte Turniere (discipline_id nil#{" oder ##{unknown_id} Unknown Discipline" if unknown_id})"

    Discipline.reset_classify_index!
    assigned = Hash.new(0)
    triage = []
    failures = []

    Tournament.skip_cable_ready_updates do
      scope.find_each(batch_size: 500) do |t|
        d = Discipline.classify_from_title(t.title)
        # Branch-Treffer sind erlaubt (Titel nur "Pool"/"Kegel" -> Branch-Disziplin;
        # User-Entscheidung 2026-07-12). Nur echte nil gehen in die Triage.
        if d.nil?
          triage << [t.id, t.title]
          next
        end
        assigned[d.name] += 1
        next unless armed

        begin
          t.update!(discipline_id: d.id) # instance-level -> PaperTrail-Version -> Sync
        rescue => e
          failures << {id: t.id, title: t.title, error: e.message}
        end
      end
    end

    puts "\n== Zuordnung (#{armed ? "geschrieben" : "geplant"}): #{assigned.values.sum} Turniere =="
    assigned.sort_by { |_, n| -n }.each { |name, n| puts sprintf("  %-26s %5d", name, n) }

    puts "\n== Triage (nicht ableitbar, bleiben unveraendert): #{triage.size} =="
    triage.first(25).each { |id, title| puts "  ##{id} #{title}" }
    puts "  ..." if triage.size > 25

    if failures.any?
      puts "\n== Apply-Fehler: #{failures.size} =="
      failures.first(10).each { |f| puts "  ##{f[:id]} #{f[:title]}: #{f[:error]}" }
    end

    puts "\n#{armed ? "Fertig." : "DRY-RUN: keine Aenderung. ARMED=1 schreibt discipline_id (versioniert)."}"
  end
end
