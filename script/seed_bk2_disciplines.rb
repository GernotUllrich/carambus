# frozen_string_literal: true

#
# Phase 38.4 Plan 04 + Phase 38.5 Plan 03 — central Discipline records (D-04, D-08).
# Phase 38.5 D-08 additions:
#   - allow_negative_score_input + negative_credits_opponent on BK50/BK100/BK-2/BK-2plus
#   - multiset_components on BK-2kombi (id 107)
# RUN ONLY IN carambus_api CONSOLE (production master). Local servers receive
# these records via Version sync once the new keys ship.
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
#
# Phase 38.5 D-08: add allow_negative_score_input + negative_credits_opponent
# defaults. BK-2plus is the only BK-* discipline that credits negatives to the
# opponent (DZ semantics). BK-2 / BK50 / BK100 keep negatives signed on the
# scoring player. BK-2kombi (id 107) does NOT carry these two keys — the
# resolver looks up the per-set effective_discipline (bk_2plus or bk_2) and
# reads THAT Discipline's params.
discs = [
  {
    name: "BK50",
    data: {
      free_game_form: "bk50",
      ballziel_choices: [50],
      allow_negative_score_input: true,        # Phase 38.5 D-08
      negative_credits_opponent: false         # Phase 38.5 D-08
    }
  },
  {
    name: "BK100",
    data: {
      free_game_form: "bk100",
      ballziel_choices: [100],
      allow_negative_score_input: true,        # Phase 38.5 D-08
      negative_credits_opponent: false         # Phase 38.5 D-08
    }
  },
  {
    name: "BK-2",
    data: {
      free_game_form: "bk_2",
      ballziel_choices: [50, 60, 70, 80, 90, 100],
      allow_negative_score_input: true,        # Phase 38.5 D-08
      negative_credits_opponent: false         # Phase 38.5 D-08
    }
  },
  {
    name: "BK-2plus",
    data: {
      free_game_form: "bk_2plus",
      ballziel_choices: [50, 60, 70, 80, 90, 100],
      allow_negative_score_input: true,        # Phase 38.5 D-08
      negative_credits_opponent: true          # Phase 38.5 D-08 (BK-2plus credits opponent)
    }
  }
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
# Phase 38.5 D-08: add multiset_components default. BK-2kombi does NOT carry
# allow_negative_score_input / negative_credits_opponent — resolver looks up
# effective_discipline (bk_2plus or bk_2) per set and reads THAT Discipline's params.
# Idempotent: re-running the script after Plan 11 / 38.5 only writes if drift detected.
bk2 = Discipline.find(107)
current = bk2.data.present? ? JSON.parse(bk2.data) : {}
needs_update = current["ballziel_choices"] != [50, 60, 70] ||
  current["nachstoss_allowed"] != true ||
  current["multiset_components"] != ["bk_2plus", "bk_2"]
if needs_update
  current["free_game_form"] ||= "bk2_kombi"
  current["ballziel_choices"] = [50, 60, 70]
  current["nachstoss_allowed"] = true
  current["multiset_components"] = ["bk_2plus", "bk_2"]   # Phase 38.5 D-08
  # Idempotency guard: if a previous Phase 38.5 run accidentally wrote the
  # two BK-param keys onto BK-2kombi, remove them — D-08 says BK-2kombi must
  # NOT carry them (resolver uses effective_discipline lookup).
  current.delete("allow_negative_score_input")
  current.delete("negative_credits_opponent")
  bk2.data = current.to_json
  bk2.save!
  puts "Updated Discipline.find(107) with ballziel_choices + nachstoss_allowed + multiset_components"
end
