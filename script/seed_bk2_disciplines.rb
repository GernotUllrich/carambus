# frozen_string_literal: true
#
# Phase 38.4 Plan 04 — create 4 new central Discipline records (D-04).
# RUN ONLY IN carambus_api CONSOLE (production master). Local servers receive
# these records via Version sync once Plan 38.4-01 (sync bug fix) is deployed.
#
# Usage (carambus_api production):
#   cd /path/to/carambus_api
#   bin/rails runner script/seed_bk2_disciplines.rb
#
# Idempotent: re-run is safe (uses find_or_initialize_by on name).
# Discipline.find(107) is BK2-Kombi: type=nil, table_kind_id=3

# Probe Discipline.find(107) to mirror type + table_kind_id
source = Discipline.find(107)
type_value = source.type
table_kind_id_value = source.table_kind_id
puts "Source BK2-Kombi: type=#{type_value.inspect}, table_kind_id=#{table_kind_id_value.inspect}"

discs = [
  { name: "BK50", data: { free_game_form: "bk50", ballziel_choices: [50] } },
  { name: "BK100", data: { free_game_form: "bk100", ballziel_choices: [100] } },
  { name: "BK-2", data: { free_game_form: "bk_2", ballziel_choices: [50, 60, 70, 80, 90, 100] } },
  { name: "BK-2plus", data: { free_game_form: "bk_2plus", ballziel_choices: [50, 60, 70, 80, 90, 100] } }
]

created = []
updated = []
discs.each do |attrs|
  json_data = attrs[:data].to_json
  rec = Discipline.find_or_initialize_by(name: attrs[:name])
  rec.data = json_data
  rec.type = type_value
  rec.table_kind_id = table_kind_id_value
  if rec.new_record?
    rec.save!
    created << rec.name
  else
    rec.save! if rec.changed?
    updated << rec.name if rec.previous_changes.any?
  end
end

puts "Created: #{created.inspect}"
puts "Updated: #{updated.inspect}"
puts "All BK-* disciplines: #{Discipline.where(name: %w[BK2-Kombi BK50 BK100 BK-2 BK-2plus]).order(:id).pluck(:id, :name, :data)}"

# Also ensure BK2-Kombi (id 107) has ballziel_choices populated
bk2 = Discipline.find(107)
current = bk2.data.present? ? JSON.parse(bk2.data) : {}
unless current["ballziel_choices"] == [50, 60, 70]
  current["free_game_form"] ||= "bk2_kombi"
  current["ballziel_choices"] = [50, 60, 70]
  bk2.data = current.to_json
  bk2.save!
  puts "Updated Discipline.find(107) with ballziel_choices"
end
