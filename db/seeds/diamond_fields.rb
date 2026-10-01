# Die 32 Diamantfelder als TableZones.
#
# Die Verbindungslinien gegenüberliegender Diamanten teilen die Spielfläche
# in 8 × 4 gleich große Felder. Weingartners Pflichtstoßprogramm legt die
# Versammlungszone (VZ) jeder Figur auf eines davon; allgemein sind sie das
# natürliche Raster für Positionsangaben.
#
# Koordinaten nach ONTOLOGY.md "Tisch-Geometrie": x entlang der langen
# Achse ab der linken kurzen Bande (short_left), y entlang der kurzen Achse
# ab der oberen langen Bande (long_far), beide normalisiert 0..1. Feld
# x{i}_y{j} reicht von x = i/8 bis (i+1)/8 und y = j/4 bis (j+1)/4. Weil
# die Felder diamantenproportional sind, gilt dasselbe Polygon auf jeder
# Tischgröße.
#
# Voraussetzung: zone_type "diamond_field" (Handoff Paul 2026-10-02).
# Idempotent: Upsert über key.
#
# Run: bin/rails runner db/seeds/diamond_fields.rb

puts "Seed: 32 Diamantfelder"

(0..7).each do |i|
  (0..3).each do |j|
    x0, x1 = (i / 8.0).round(4), ((i + 1) / 8.0).round(4)
    y0, y1 = (j / 4.0).round(4), ((j + 1) / 4.0).round(4)
    zone = TableZone.find_or_initialize_by(key: "diamond_field_x#{i}_y#{j}")
    zone.update!(
      label:              "Diamantfeld #{i + 1}/#{j + 1}",
      zone_type:          "diamond_field",
      polygon_normalized: [[x0, y0], [x1, y0], [x1, y1], [x0, y1]],
      description:        "Feld #{i + 1} von links (lange Achse ab short_left), " \
                          "#{j + 1} von oben (kurze Achse ab long_far) im " \
                          "8 × 4-Raster der Diamant-Verbindungslinien.",
      weingartner_ref:    "Versammlungszone: eines der 32 Felder der " \
                          "Diamant-Verbindungslinien (Pflichtstoßprogramm, Einleitung)"
    )
  end
end

puts "  ✓ #{TableZone.where(zone_type: "diamond_field").count} Diamantfelder"
