puts "="*60
puts "Creating Example Tags"
puts "="*60
puts ""

# Position Tags
position_tags = [
  { name: "Amerika-Position", category: "Position", description: "Ball 2 und 3 in der Ecke oder am Rand" },
  { name: "Ecke-Position", category: "Position", description: "Bälle in oder nahe einer Ecke" },
  { name: "Mitte-Position", category: "Position", description: "Bälle in der Tischmitte" },
  { name: "Band-Position", category: "Position", description: "Einer oder mehrere Bälle am Band" },
]

# Technik Tags
technik_tags = [
  { name: "Versammlungsstoß", category: "Technik", description: "Alle drei Bälle zusammenbringen" },
  { name: "Konterstoß", category: "Technik", description: "Rücklauf über mehrere Banden" },
  { name: "Rückläufer", category: "Technik", description: "Ball läuft nach Karambolage zurück" },
  { name: "Doppelbande", category: "Technik", description: "Spielball über zwei Banden vor Karambolage" },
  { name: "Effet-Stoß", category: "Technik", description: "Stoß mit starkem Seiteneffet" },
]

# Schwierigkeit Tags
schwierigkeit_tags = [
  { name: "Anfänger", category: "Schwierigkeit", description: "Für Einsteiger geeignet" },
  { name: "Fortgeschritten", category: "Schwierigkeit", description: "Mittleres Niveau" },
  { name: "Profi", category: "Schwierigkeit", description: "Für erfahrene Spieler" },
]

# Spielart Tags
spielart_tags = [
  { name: "1-shot zu Amerika", category: "Spielart", description: "Ein Stoß zur Amerika-Position" },
  { name: "2-shot zu Amerika", category: "Spielart", description: "Zwei Stöße zur Amerika-Position" },
  { name: "3-shot zu Amerika", category: "Spielart", description: "Drei Stöße zur Amerika-Position" },
  { name: "Seriespiel", category: "Spielart", description: "Position für Serien-Aufbau" },
]

# Zone Tags
zone_tags = [
  { name: "Cadre-Kreuz", category: "Zone", description: "Zielzone im Cadre-Kreuz" },
  { name: "Anker", category: "Zone", description: "Anker-Position in der Ecke" },
  { name: "Lange Ecke", category: "Zone", description: "Lange Ecke des Tisches" },
  { name: "Kurze Ecke", category: "Zone", description: "Kurze Ecke des Tisches" },
]

# Spezial Tags
spezial_tags = [
  { name: "Klassiker", category: "Spezial", description: "Klassische Trainingsposition" },
  { name: "Wettkampf", category: "Spezial", description: "Häufig in Wettkämpfen" },
  { name: "System", category: "Spezial", description: "Systemposition mit Berechnung" },
]

all_tags = position_tags + technik_tags + schwierigkeit_tags + spielart_tags + zone_tags + spezial_tags

all_tags.each do |tag_data|
  tag = Tag.find_or_create_by!(name: tag_data[:name]) do |t|
    t.category = tag_data[:category]
    t.description = tag_data[:description]
  end
  
  puts "✓ #{tag.category}: #{tag.name}"
end

puts ""
puts "="*60
puts "Tag Creation Complete!"
puts "="*60
puts ""
puts "Summary:"
puts "  Total tags: #{Tag.count}"
Tag::CATEGORIES.each do |category|
  count = Tag.where(category: category).count
  puts "  #{category}: #{count} tags" if count > 0
end
puts ""
