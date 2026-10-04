# Dirk Acx, "Over 160 collecting shots" als Trainingsprogramm.
#
# Baum: Programm → Figuren (sequence_number 1–167 in Buchreihenfolge,
# Nummern 1–164 plus 27b, 42b, 87b; danach Tisch-Korrekturen ab 168, z. B.
# „Nr. 22 (Tisch-Korrektur)“: Stellung für echte Tische angepasst, Stoß aus
# carom_sim, Herkunft in properties.tisch_korrektur). Jede Figur: Startstellung (exakt nach
# Acx' Positionsbild, 2,10 × 1,05), ein Stoß mit dem ersten Treffer
# B I → B II (Treffpunkt = Geisterball, Treffdicke aus dem Simulator-Panel),
# Stoßparameter als grobe Klassen plus Rohwerte, Link auf den Caromball-
# Favoriten. Endstellung, Laufwege und Zielzone gibt Acx nicht maßlich an —
# nicht angelegt.
#
# Daten: db/seeds/data/acx_versammlungsstoesse.json, erzeugt in
# TRAINING_SOURCES mit scripts/acx_seed_data.py. Parameter sind Startwerte
# (Gernot 2026-10-03), keine Eichung der Simulator-Skalen. Lizenz: nur
# Zahlen und Stellungen, kein Buchtext; Quelle genannt.
#
# Voraussetzungen: concepts.rb ist gelaufen (gather_shot).
#
# Idempotent: Upsert über fachliche Schlüssel — Figuren über
# (parent, sequence_number), BallConfigurations über Marker im notes-Feld.
#
# Run: bin/rails runner db/seeds/examples/acx_versammlungsstoesse.rb

data = JSON.parse(File.read(Rails.root.join("db/seeds/data/acx_versammlungsstoesse.json")))
table_variant = data.dig("program", "table_variant")

puts "Seed: Acx — Versammlungsstöße (#{table_variant})"
puts "=" * 60

source = TrainingSource.find_or_initialize_by(title: "Acx — #{data.dig("program", "source_title")}")
source.update!(
  author: data.dig("program", "author"),
  language: "nl",
  notes: "Versammlungsstöße auf dem 2,10-m-Tisch, je Figur Positionsbild und " \
         "Stoßparameter aus einem Billard-Simulator (Kraft, Effet, Treffpunkt, " \
         "Queuewinkel). Übernommen: nur Stellungen und Zahlenwerte."
)
puts "  ✓ TrainingSource  ##{source.id}"

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

gather = TrainingConcept.find_by!(key: "gather_shot")

data["figures"].each do |fig|
  n = fig["figur"]
  marker = "[SEED:acx_#{n.rjust(4, "0")}]"
  ex = TrainingExample.find_or_initialize_by(parent: program, sequence_number: fig["sequence_number"])
  label = fig["label"] || "Nr. #{n}"
  correction = fig.dig("collision", "properties", "tisch_korrektur")
  ex.update!(
    title: "Acx #{label} — Versammlungsstoß",
    source_language: "de",
    source_notes: "Over 160 collecting shots, #{label} (PDF-Seite #{fig["page"]}). " \
                  "B II #{fig["b2_sicher"] ? "" : "(unsicher) "}= #{fig["b2_colour"] == "yellow" ? "Gelb" : "Rot"}." +
                  (correction ? " Tisch-Korrektur: #{correction["quelle"]}" : "")
  )

  sp = fig["start"]
  start_config = upsert_config("#{marker} Start", {
    b1_x: sp["b1"][0], b1_y: sp["b1"][1], b2_x: sp["b2"][0], b2_y: sp["b2"][1],
    b3_x: sp["b3"][0], b3_y: sp["b3"][1],
    table_variant: table_variant, gather_state: "pre_gather", position_type: "exact"
  })

  sp_rec = StartPosition.find_or_initialize_by(training_example: ex)
  sp_rec.update!(ball_configuration: start_config, source_language: "de",
                 description_text: correction ? "Aufstellung nach Acx' Positionsbild, für echte Tische korrigiert (Tisch 2,10 × 1,05)."
                                              : "Aufstellung nach Acx' Positionsbild (Tisch 2,10 × 1,05).")

  SourceAttribution.find_or_initialize_by(training_source: source, sourceable: ex)
                   .update!(reference: label)

  shot = ex.shots.find_or_initialize_by(sequence_number: 1)
  shot.update!(shot_type: "ideal", source_language: "de", title: "#{label} nach Acx",
               notes: correction ? "Stoßparameter aus carom_sim (Wertesatz Heimtisch GU), Startwerte."
                                 : "Stoßparameter aus dem Simulator-Panel, grob umgerechnet (Startwerte).")

  c = fig["collision"]
  rec = shot.ball_collisions.find_or_initialize_by(sequence_number: c["sequence_number"])
  rec.update!(collision_type: c["collision_type"], ball_attacker: c["ball_attacker"],
              ball_target: c["ball_target"],
              contact_coords_normalized: { "x" => c["contact"][0], "y" => c["contact"][1] },
              quantity_of_ball: c["quantity_of_ball"], speed: c["speed"],
              effect_vertical: c["effect_vertical"], effect_horizontal: c["effect_horizontal"],
              properties: c["properties"])
  shot.ball_collisions.where.not(id: rec.id).destroy_all

  tce = ex.training_concept_examples.find_or_initialize_by(training_concept: gather)
  tce.update!(weight: 5, role: "illustrates")
  ex.training_concept_examples.where.not(id: tce.id).destroy_all

  puts "    · #{label.ljust(24)} ##{ex.id}  Treffdicke #{c["quantity_of_ball"]}  " \
       "Tempo #{c["speed"]}  Effet #{c["effect_horizontal"]}/#{c["effect_vertical"]}"
end

puts "=" * 60
