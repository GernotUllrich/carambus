# Weingartners Pflichtstoßprogramm als Trainingsprogramm.
#
# Baum: Programm → Gruppen (sequence_number 1–19) → Figuren (1–4 je Gruppe).
# Jede Figur: Startstellung, Endstellung mit der Versammlungszone (VZ) als
# Ziel, Lauflinien von B I und B II, Ball-Kollisionen von B I, Banden-
# kontakte, Wertpunkte, Contre-Kennzeichen, Concept-Verknüpfungen.
#
# Daten: db/seeds/data/weingartner_pflichtstoss.json, erzeugt in
# TRAINING_SOURCES mit scripts/weingartner_seed_data.py aus Bild- und
# Legendenauswertung des PDFs (Positionen exakt nach Legende, Zieltisch
# 210 × 105 inkl. Weingartners Klammerangaben).
#
# Voraussetzungen: Schema mit training_examples.points/contre_allowed/
# sequence_number und zone_type "diamond_field" (Handoff 2026-10-02);
# concepts.rb und diamond_fields.rb sind gelaufen.
#
# Idempotent: Upsert über fachliche Schlüssel — Beispiele über
# (parent, sequence_number), BallConfigurations über Marker im notes-Feld,
# Kollisionen/Ereignisse/Gewichte wie in den übrigen Beispiel-Seeds.
#
# Run: bin/rails runner db/seeds/examples/weingartner_pflichtstoss.rb

data = JSON.parse(File.read(Rails.root.join("db/seeds/data/weingartner_pflichtstoss.json")))
table_variant = data.dig("program", "table_variant")

puts "Seed: Weingartner — Pflichtstoßprogramm (#{table_variant})"
puts "=" * 60

source = TrainingSource.find_or_initialize_by(title: "Weingartner — Pflichtstoßprogramm")
source.update!(
  author: "Heinrich Weingartner (Wien)",
  language: "de",
  notes: "76 Figuren in 19 Gruppen à 4, Wertpunkte 4–11 (Summe 500). " \
         "Gelöst, wenn nach Zeichnung gespielt, in der Versammlungszone " \
         "karamboliert und alle drei Bälle dort verbleiben. Angaben für " \
         "284 × 142, Klammerangaben für 210 × 105."
)
puts "  ✓ TrainingSource  ##{source.id}"

def upsert_example(parent:, sequence_number:, title:, attrs: {})
  ex = TrainingExample.find_or_initialize_by(parent: parent, sequence_number: sequence_number)
  ex.update!({ title: title, source_language: "de" }.merge(attrs))
  ex
end

def upsert_config(marker, attrs)
  config = BallConfiguration.where("notes LIKE ?", "#{marker}%").first || BallConfiguration.new
  config.update!(attrs.merge(notes: marker))
  config
end

program = TrainingExample.find_or_initialize_by(parent: nil, title: data.dig("program", "title"))
program.update!(source_language: "de",
                source_notes: "Trainingsprogramm, Wurzel des Baums. " \
                              "Quelle: #{data.dig("program", "source_file")}")
SourceAttribution.find_or_create_by!(training_source: source, sourceable: program)
puts "  ✓ Programm        ##{program.id}"

data["groups"].each do |group|
  roman = %w[I II III IV V VI VII VIII IX X XI XII XIII XIV XV XVI XVII XVIII XIX][group["number"] - 1]
  grp = upsert_example(parent: program, sequence_number: group["number"],
                       title: "Gruppe #{roman} — #{group["name"]}")
  puts "  ✓ Gruppe #{roman.ljust(5)}    ##{grp.id}"

  group["figures"].each do |fig|
    n = fig["figur"]
    marker = "[SEED:weingartner_f#{format("%02d", n)}]"
    ex = upsert_example(
      parent: grp, sequence_number: fig["position_in_group"],
      title: "Weingartner Figur #{n} — #{group["name"]}",
      attrs: {
        points: fig["points"],
        contre_allowed: fig["contre_allowed"],
        source_notes: "Pflichtstoßprogramm Figur #{n}, Gruppe #{roman}. Legende: " \
                      "B I #{fig.dig("legend", "b1")}, B II #{fig.dig("legend", "b2")}, " \
                      "B III #{fig.dig("legend", "b3")}."
      }
    )

    sp, ep = fig["start"], fig["end"]
    start_config = upsert_config("#{marker} Start", {
      b1_x: sp["b1"][0], b1_y: sp["b1"][1], b2_x: sp["b2"][0], b2_y: sp["b2"][1],
      b3_x: sp["b3"][0], b3_y: sp["b3"][1],
      table_variant: table_variant, gather_state: "pre_gather", position_type: "exact"
    })
    end_config = upsert_config("#{marker} Ende", {
      b1_x: ep["b1"][0], b1_y: ep["b1"][1], b2_x: ep["b2"][0], b2_y: ep["b2"][1],
      b3_x: ep["b3"][0], b3_y: ep["b3"][1],
      table_variant: table_variant, gather_state: "post_gather", position_type: "approximate"
    })

    # VZ als Ziel aller drei Bälle an der Endstellung
    vz = TableZone.find_by!(key: fig["vz_zone"])
    target = BallConfigurationZone.find_or_initialize_by(
      ball_configuration: end_config, table_zone: vz, which_ball: "any", role: "target"
    )
    target.update!(notes: "Versammlungszone (Weingartner): alle drei Bälle müssen hier verbleiben.")
    end_config.ball_configuration_zones.where.not(id: target.id).destroy_all

    sp_rec = StartPosition.find_or_initialize_by(training_example: ex)
    sp_rec.update!(ball_configuration: start_config, source_language: "de",
                   description_text: "Aufstellung nach Weingartners Legende (Tisch #{table_variant}): " \
                                     "B I #{fig.dig("legend", "b1")}, B II #{fig.dig("legend", "b2")}, " \
                                     "B III #{fig.dig("legend", "b3")}.")

    SourceAttribution.find_or_initialize_by(training_source: source, sourceable: ex)
                     .update!(reference: "Figur #{n} (Gruppe #{roman})")

    shot = ex.shots.find_or_initialize_by(sequence_number: 1)
    shot.update!(shot_type: "ideal", source_language: "de", end_ball_configuration: end_config,
                 title: "Figur #{n} nach Zeichnung",
                 trajectory_polylines: fig["trajectories"])

    collisions = fig["collisions"].map do |c|
      rec = shot.ball_collisions.find_or_initialize_by(sequence_number: c["sequence_number"])
      rec.update!(collision_type: c["collision_type"], ball_attacker: c["ball_attacker"],
                  ball_target: c["ball_target"], scored: c["scored"],
                  contact_coords_normalized: { "x" => c["contact"][0], "y" => c["contact"][1] })
      rec
    end
    shot.ball_collisions.where.not(id: collisions.map(&:id)).destroy_all

    events = fig["cushion_events"].map do |e|
      rec = shot.shot_events.find_or_initialize_by(ball_involved: e["ball"], sequence_number: e["sequence_number"])
      rec.update!(event_type: "cushion_contact", cushion_involved: e["cushion"],
                  contact_coords_normalized: { "x" => e["contact"][0], "y" => e["contact"][1] })
      rec
    end
    shot.shot_events.where.not(id: events.map(&:id)).destroy_all

    links = group["concepts"].map do |link|
      tce = ex.training_concept_examples.find_or_initialize_by(
        training_concept: TrainingConcept.find_by!(key: link["key"])
      )
      tce.update!(weight: link["weight"], role: "illustrates")
      tce
    end
    ex.training_concept_examples.where.not(id: links.map(&:id)).destroy_all

    puts "    · Figur #{n.to_s.rjust(2)}  ##{ex.id}  #{fig["points"]} Pkt  VZ #{fig["vz_zone"]}  " \
         "#{collisions.size} Kollisionen, #{events.size} Banden"
  end
end

puts "=" * 60
