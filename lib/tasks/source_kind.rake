# frozen_string_literal: true

# Backfill: Provenienz-Kennung `source_kind` fuer den Altbestand (Phase 34-01).
#
# Der Stempel in `ProvenanceStamped` greift nur beim Anlegen und beim Wechsel der `source_url`.
# Bestandsdaten holt dieser Task nach — aus derselben Quelle der Wahrheit, `Provenance::Classifier`.
#
# GEHOERT AUF DIE AUTHORITY. Dort ist PaperTrail aktiv (`has_paper_trail ... unless
# Carambus.config.carambus_api_url.present?`) und globale Records sind schreibbar. Auf einem
# Regional-Server ist der Lauf sinnlos: `LocalProtector` blockiert globale Records, und die Kennung
# trifft dort ohnehin per Version-Sync ein.
#
# WARUM `update!` UND NICHT `update_all`/`update_column`: Ohne PaperTrail-Version erreicht
# `source_kind` die Regional-Server NIE — der Version-Sync ist der einzige Weg nach unten.
# Genau daran lief `region_taggings.rake` schon einmal leer (siehe Kommentar in local_protector.rb
# zum touch-Gate). Ein `update!` mit echter Feldaenderung passiert das `unless`-Gate regulaer.
#
# WARUM `set_branch_id` AUSGEHAENGT WIRD (Betreiber 2026-08-16): `BranchTaggable` haengt an
# `before_save` mit der Bedingung `branch_id.nil?` — und die trifft auf 17 562 Turniere und
# 5 810 Ligen zu. Ein schlichtes `update!` wuerde also nebenher eine Massenaenderung an `branch_id`
# ausloesen, die niemand beauftragt hat und die im selben Version-Batch nach unten reisen wuerde.
# Der Backfill aendert genau eine Spalte. Die `branch_id`-Luecke bleibt bestehen und ist ein
# eigenes Vorhaben — der Abdeckungsreport umgeht die Spalte ohnehin bewusst und loest den Zweig
# ueber die Wurzel des Disziplin-Baums auf.
#
# Usage:
#   bundle exec rake source_kind:backfill              # DRY-RUN (Default, keine Writes)
#   bundle exec rake source_kind:backfill ARMED=1      # LIVE (schreibt)
#
# Auf Produktion nur nach Freigabe.

namespace :source_kind do
  desc "Backfill source_kind fuer Tournament und League (ARMED=1 zum Schreiben, sonst DRY-RUN)"
  task backfill: :environment do
    armed = ENV["ARMED"].present?

    puts "== source_kind:backfill == #{armed ? "ARMED (schreibt)" : "DRY-RUN (schreibt nicht)"}"
    puts

    without_branch_tagging([Tournament, League]) do
      [Tournament, League].each do |model|
        # Die dritte Stufe der Kaskade. `LeagueCc` UNSCOPED plucken: `League#league_cc` ist auf
        # `context: "nbv"` gescopt und wuerde andere Kontexte verschlucken.
        cc_ids = ((model <= Tournament) ? TournamentCc.distinct.pluck(:tournament_id) : LeagueCc.distinct.pluck(:league_id)).compact.to_set

        before = model.group(:source_kind).count
        planned = Hash.new(0)
        changed = 0
        unclassified = []
        forced = []

        model.find_each(batch_size: 500) do |record|
          kind = Provenance::Classifier.source_kind_for(
            source_url: record.source_url,
            ba_id: record.ba_id,
            cc_present: cc_ids.include?(record.id)
          )

          if kind.nil?
            unclassified << [record.id, record.source_url]
            next
          end

          planned[kind.to_s] += 1
          next if record.source_kind == kind.to_s # idempotent

          changed += 1
          next unless armed

          model.skip_cable_ready_updates do
            record.update!(source_kind: kind)
          rescue ActiveRecord::RecordInvalid
            # Der Altbestand traegt Records, die heutige Validierungen verletzen (gemessen: Ligen
            # ohne `shortname`). Das ist ein eigenes Thema — es darf den Backfill aber nicht
            # anhalten, sonst blieben Luecken in der Kennung, und 34-02 haengt genau daran, dass
            # jeder Record einen Wert traegt. Callbacks und PaperTrail laufen weiterhin mit;
            # nur die Validierung wird uebergangen. Die Faelle werden unten ausgewiesen.
            forced << record.id
            record.save(validate: false)
          end
        end

        puts "--- #{model.name} (#{model.count}) ---"
        puts "  vorher:  #{fmt_distribution(before)}"
        puts "  geplant: #{fmt_distribution(planned)}"
        puts "  #{armed ? "geschrieben" : "zu aendern"}: #{changed}"
        puts "  nachher: #{fmt_distribution(model.group(:source_kind).count)}" if armed

        if unclassified.any?
          puts "  ANOMALIE — nicht klassifizierbar (source_url vorhanden, Muster unbekannt): #{unclassified.size}"
          unclassified.first(10).each { |id, url| puts "    #{model.name}##{id} #{url}" }
        else
          puts "  nicht klassifizierbar: 0"
        end

        if forced.any?
          puts "  ANOMALIE — gegen bestehende Validierungsfehler gestempelt: #{forced.size}"
          puts "    #{model.name} ids: #{forced.first(10).join(", ")}#{"…" if forced.size > 10}"
        end
        puts
      end
    end
  end
end

# Haengt `BranchTaggable#set_branch_id` fuer die Dauer des Blocks aus und setzt den Callback
# danach exakt so wieder ein, wie er in der Concern deklariert ist. Nur prozesslokal — der Task
# laeuft in einem eigenen Prozess, laufende Server sind nicht betroffen.
def without_branch_tagging(models)
  models.each { |m| m.skip_callback(:save, :before, :set_branch_id, raise: false) }
  yield
ensure
  models.each do |m|
    m.set_callback(:save, :before, :set_branch_id,
      if: -> { will_save_change_to_discipline_id? || branch_id.nil? })
  end
end

def fmt_distribution(hash)
  return "—" if hash.empty?

  hash.sort_by { |k, v| [-v, k.to_s] }.map { |k, v| "#{k || "(leer)"}=#{v}" }.join(" · ")
end
