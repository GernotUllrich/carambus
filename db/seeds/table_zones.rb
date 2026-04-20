# v0.8 Tier 2B seed: six named geometric zones from the Gretillat spine.
# Polygons are PLACEHOLDERS — real calibration against Gretillat's free-
# game diagrams and ACBillar 3-cushion catches still pending. Each zone
# ships with an empty polygon array and a note flagging the pending
# calibration; topology/semantics (band_strip vs corner_region vs
# line_passage) is already final.
#
# EXCLUDED by design: `american_position`. That is a ball-arrangement
# pattern, not a table region, and belongs in a future
# `ball_arrangements` catalog (Tier 3+).

puts "Creating table zones..."

TABLE_ZONES_SEED = [
  {
    key: "catches",
    label: "Catches (Fanggebiete)",
    zone_type: "corner_region",
    description: "Gretillats Catch-Zonen: Areale in Ecken- und Bandenberei" \
                 "chen, in denen Bälle sich natürlicherweise sammeln und " \
                 "für kurze Serien-Stöße verfügbar sind. Polygon-Kalibrie" \
                 "rung gegen Gretillat free-game Kapitel ausstehend.",
    gretillat_ref: "book 1, Part 2 The Free Game (pp. 317-375)"
  },
  {
    key: "corner_ascent",
    label: "Aufsteigende Ecke",
    zone_type: "line_passage",
    description: "Passage, auf der Bälle in die Ecke hinein laufen. Polygo" \
                 "n-Kalibrierung ausstehend.",
    gretillat_ref: "book 1, Part 2"
  },
  {
    key: "corner_descent",
    label: "Absteigende Ecke",
    zone_type: "line_passage",
    description: "Passage, auf der Bälle aus der Ecke heraus laufen. Pol" \
                 "ygon-Kalibrierung ausstehend.",
    gretillat_ref: "book 1, Part 2"
  },
  {
    key: "small_line",
    label: "Kleine Linie",
    zone_type: "band_strip",
    description: "Schmaler Streifen nahe der langen Bande, auf dem Linien-" \
                 "Serien in Conti-Art laufen. Polygon-Kalibrierung " \
                 "ausstehend.",
    gretillat_ref: "book 1, Part 2"
  },
  {
    key: "draw_passage",
    label: "Ziehball-Passage",
    zone_type: "line_passage",
    description: "Zone, in der Rückläufer (Draw) bevorzugt eingesetzt wer" \
                 "den — typisch untere Tischhälfte nahe der Kopfbande. " \
                 "Polygon-Kalibrierung ausstehend.",
    gretillat_ref: "book 1, Part 2"
  },
  {
    key: "position_passage",
    label: "Stellungs-Passage",
    zone_type: "line_passage",
    description: "Zone für Positions-Stöße, in der die Folge-Stellung pri" \
                 "mär gesichert wird. Polygon-Kalibrierung ausstehend.",
    gretillat_ref: "book 1, Part 2"
  }
].freeze

TABLE_ZONES_SEED.each do |attrs|
  z = TableZone.find_or_initialize_by(key: attrs[:key])
  z.assign_attributes(attrs)
  z.polygon_normalized ||= []
  z.save!
  puts "  ✓ #{z.key.ljust(20)} (#{z.zone_type})"
end

puts "\nTable zones seeding completed. Total: #{TableZone.count}"
