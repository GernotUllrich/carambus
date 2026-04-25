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

# Phase 38.4-16 P5: nachstoss_allowed flag NARROWED to BK-2kombi only (per user
# clarification at /gsd-plan-phase checkpoint, interpretation b — flag-only narrowing).
# The 4 non-BK-2kombi entries below NO LONGER carry nachstoss_allowed. The flag
# remains on BK-2kombi (id 107) via the backfill block at lines 51-63 (UNCHANGED).
# Discipline#nachstoss_allowed? returns false when key absent (verified by
# T-O2-nachstoss-allowed-default-false), so omitting the key is safe.
discs = [
  { name: "BK50",    data: { free_game_form: "bk50",    ballziel_choices: [50] } },
  { name: "BK100",   data: { free_game_form: "bk100",   ballziel_choices: [100] } },
  { name: "BK-2",    data: { free_game_form: "bk_2",    ballziel_choices: [50, 60, 70, 80, 90, 100] } },
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

# Phase 38.4-11 O2 / 38.4-16 P5: ensure BK2-Kombi (id 107) carries the nachstoss flag.
# Per Plan 16 P5 narrowing, BK-2kombi is the SOLE discipline with this flag set
# to true (the 4 non-BK-2kombi entries above no longer have the key).
# Idempotent: re-running the script after Plan 11 only writes if the flag is missing.
bk2 = Discipline.find(107)
current = bk2.data.present? ? JSON.parse(bk2.data) : {}
needs_update = current["ballziel_choices"] != [50, 60, 70] || current["nachstoss_allowed"] != true
if needs_update
  current["free_game_form"] ||= "bk2_kombi"
  current["ballziel_choices"] = [50, 60, 70]
  current["nachstoss_allowed"] = true
  bk2.data = current.to_json
  bk2.save!
  puts "Updated Discipline.find(107) with ballziel_choices + nachstoss_allowed"
end
