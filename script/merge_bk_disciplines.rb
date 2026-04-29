# frozen_string_literal: true

#
# Phase 38.6 — Discipline Master-Data Cleanup (BK-* Duplikate auf carambus_api).
#
# Merges 6 duplicate BK-family Discipline rows (losers) into 5 canonical winners
# and renames Winner 107 to "BK-2kombi". Run ONLY on carambus_api production
# (Source of Truth for global records, id < 50_000_000). Local servers receive
# the cleanup automatically via Version#update_from_carambus_api once the
# emitted PaperTrail Versions sync.
#
# Sync discipline (D-04): ONLY PaperTrail-aware AR calls (update!, save!,
# destroy). NEVER update_column, update_columns, update_all, delete, delete_all,
# raw SQL. Otherwise local-server sync silently breaks.
#
# Idempotent (D-11): re-run with no losers present is a safe no-op.
#
# Usage:
#   cd /path/to/carambus_api
#   RAILS_ENV=development bin/rails runner script/merge_bk_disciplines.rb   # dev dry-run
#   RAILS_ENV=production  bin/rails runner script/merge_bk_disciplines.rb   # production
#
# Output: tmp/merge-bk-disciplines-{YYYYMMDD-HHMMSS}.md (Before/After protocol)
#

require "fileutils"

# Locked merge map (Phase 38.6 D-01, D-02). Winner-IDs match Phase 38.5 seed
# anchors so seed_bk2_disciplines.rb does NOT need to be re-run after this script.
WINNER_TO_LOSERS = {
  107 => [57, 59, 95],   # BK-2kombi (currently named "BK2-Kombi") ← "BK 2kombi", "BK2-Kombi", "BK-2 Kombi"
  108 => [61],           # BK50 ← "BK 50"
  109 => [60, 62],       # BK100 ← "BK 2-100" (D-02 semantic identity), "BK 100"
  110 => [],             # BK-2 (no losers)
  111 => []              # BK-2plus (no losers)
}.freeze

WINNER_CANONICAL_NAMES = {
  107 => "BK-2kombi",    # D-12: rename from "BK2-Kombi" → "BK-2kombi"
  108 => "BK50",
  109 => "BK100",
  110 => "BK-2",
  111 => "BK-2plus"
}.freeze

ALL_LOSER_IDS = WINNER_TO_LOSERS.values.flatten.freeze   # [57, 59, 95, 61, 60, 62]

# Reflection plan derived from app/models/discipline.rb (17 reflections).
# - :versions  → SKIP per D-10 (audit history stays at original item_id; reassign would require raw SQL)
# - :training_concepts → SKIP (through-only, no direct FK; transferred via training_concept_disciplines)
# - :sub_disciplines → handled separately as D-09 Pass 1 (FK is super_discipline_id, not discipline_id)
# - :seeding_plays → FK is :playing_discipline_id (not :discipline_id)
# - :table_kind, :super_discipline → belongs_to on Discipline itself; loser-row destroyed with loser
# All other has_many/has_one use FK :discipline_id.
DISCIPLINE_ID_FK_REFLECTIONS = %i[
  discipline_tournament_plans
  tournaments
  player_classes
  player_rankings
  discipline_cc
  leagues
  game_plan_ccs
  game_plan_row_ccs
  competition_cc
  branch_cc
  training_concept_disciplines
].freeze

CC_REFLECTIONS = %i[discipline_cc competition_cc branch_cc].freeze

# Protocol output path
TIMESTAMP = Time.now.strftime("%Y%m%d-%H%M%S")
PROTOCOL_PATH = Rails.root.join("tmp", "merge-bk-disciplines-#{TIMESTAMP}.md")

# ---------------------------------------------------------------------------
# Protocol-Hilfsmethoden
# ---------------------------------------------------------------------------

def protocol_append(text)
  FileUtils.mkdir_p(File.dirname(PROTOCOL_PATH))
  File.open(PROTOCOL_PATH, "a") { |f| f.puts(text) }
end

def protocol_init
  protocol_append("# Phase 38.6 — BK-* Discipline Merge Protocol")
  protocol_append("")
  protocol_append("- Timestamp: #{TIMESTAMP}")
  protocol_append("- Rails.env: #{Rails.env}")
  protocol_append("- Database: #{ActiveRecord::Base.connection_db_config.database}")
  protocol_append("")
end

# ---------------------------------------------------------------------------
# Phase 1: Pre-flight — Loser-Existenz-Check (D-11) + Winner-Existenz-Check
# ---------------------------------------------------------------------------

def pre_flight!
  puts "=== Phase 1/6: Pre-flight ==="
  protocol_append("## Phase 1: Pre-flight")
  protocol_append("")

  existing_losers = Discipline.where(id: ALL_LOSER_IDS).pluck(:id, :name)
  if existing_losers.empty?
    puts "→ Cleanup bereits durchgeführt (keine Loser-IDs gefunden). Exit 0."
    protocol_append("Cleanup already complete — no loser IDs found in DB. Idempotent no-op.")
    exit 0
  end
  puts "→ Found #{existing_losers.size} loser(s) to merge: #{existing_losers.inspect}"
  protocol_append("Losers found: #{existing_losers.size}")
  existing_losers.each { |id, name| protocol_append("- id=#{id} name=#{name.inspect}") }
  protocol_append("")

  WINNER_TO_LOSERS.keys.each do |winner_id|
    rec = Discipline.find_by(id: winner_id)
    raise "FATAL: Winner Discipline id=#{winner_id} missing on this DB. Did Phase 38.5 seed run?" if rec.nil?
    puts "→ Winner id=#{winner_id} present: name=#{rec.name.inspect}"
    protocol_append("- Winner id=#{winner_id} present: name=#{rec.name.inspect}")
  end
  protocol_append("")
end

# ---------------------------------------------------------------------------
# Phase 2: Stats — Loser × Reflection Row-Count (D-07, vor Mutation)
# ---------------------------------------------------------------------------

def reflection_count(loser_id, reflection_name)
  case reflection_name
  when :versions
    PaperTrail::Version.where(item_type: "Discipline", item_id: loser_id).count
  when :sub_disciplines
    Discipline.where(super_discipline_id: loser_id).count
  when :seeding_plays
    Seeding.where(playing_discipline_id: loser_id).count
  when :training_concepts
    # Through-only — count is determined by training_concept_disciplines; report 0 here
    0
  else
    # Generic discipline_id FK
    klass = Discipline.reflect_on_association(reflection_name)&.klass
    return 0 if klass.nil?
    klass.where(discipline_id: loser_id).count
  end
end

def emit_stats_matrix!
  puts "=== Phase 2/6: Stats (D-07) ==="
  protocol_append("## Phase 2: Stats — Loser × Reflection Row Counts (BEFORE merge)")
  protocol_append("")

  all_reflections = %i[
    versions discipline_tournament_plans sub_disciplines tournaments
    player_classes player_rankings discipline_cc leagues game_plan_ccs
    game_plan_row_ccs seeding_plays competition_cc branch_cc
    training_concept_disciplines training_concepts
  ]

  ALL_LOSER_IDS.each do |loser_id|
    loser = Discipline.find_by(id: loser_id)
    next if loser.nil?   # already destroyed in earlier partial run; idempotency

    puts "Loser #{loser_id} (#{loser.name.inspect}):"
    protocol_append("### Loser id=#{loser_id} name=#{loser.name.inspect}")
    protocol_append("")
    protocol_append("| Reflection | Count |")
    protocol_append("|------------|-------|")
    all_reflections.each do |refl|
      count = reflection_count(loser_id, refl)
      puts "  #{refl}: #{count}"
      protocol_append("| #{refl} | #{count} |")
    end
    protocol_append("")
  end
end

# ---------------------------------------------------------------------------
# Phase 3: CC-Konflikt-Scan (D-08 — interaktiv vor Merge-Phase)
# ---------------------------------------------------------------------------

def cc_present?(discipline_id, cc_reflection)
  # cc_reflection ∈ {:discipline_cc, :competition_cc, :branch_cc}
  klass = Discipline.reflect_on_association(cc_reflection)&.klass
  return false if klass.nil?
  klass.where(discipline_id: discipline_id).exists?
end

def cc_describe(discipline_id, cc_reflection)
  klass = Discipline.reflect_on_association(cc_reflection)&.klass
  return "(reflection missing)" if klass.nil?
  rec = klass.find_by(discipline_id: discipline_id)
  return "(none)" if rec.nil?
  rec.attributes.inspect
end

def scan_cc_conflicts!
  puts "=== Phase 3/6: CC-Konflikt-Scan (D-08) ==="
  protocol_append("## Phase 3: CC-Conflict Scan")
  protocol_append("")
  conflicts = []

  WINNER_TO_LOSERS.each do |winner_id, loser_ids|
    loser_ids.each do |loser_id|
      next unless Discipline.exists?(id: loser_id)
      CC_REFLECTIONS.each do |cc|
        next unless cc_present?(winner_id, cc) && cc_present?(loser_id, cc)
        conflicts << [winner_id, loser_id, cc]
      end
    end
  end

  if conflicts.empty?
    puts "→ No CC-Konflikte gefunden."
    protocol_append("No CC conflicts detected. Proceeding to merge.")
    protocol_append("")
    return
  end

  # D-08: Merge-fields option deferred — only keep-winner / move-loser / abort
  # auto-handled here. Contextabhängige CC-Entscheidungen erfordern manuelle Klärung.
  conflicts.each do |winner_id, loser_id, cc|
    puts "CC-KONFLIKT: winner=#{winner_id} loser=#{loser_id} reflection=#{cc}"
    puts "  winner.#{cc}: #{cc_describe(winner_id, cc)}"
    puts "  loser.#{cc}:  #{cc_describe(loser_id, cc)}"
    puts "Choose: [k]eep-winner / [m]ove-loser / [a]bort"
    print "> "
    choice = $stdin.gets&.chomp&.downcase
    case choice
    when "k"
      protocol_append("- CC conflict (winner=#{winner_id} loser=#{loser_id} #{cc}): KEEP-WINNER chosen — loser.#{cc} will be destroyed via cascade when loser destroys")
      # No action — loser.destroy will cascade-delete loser.cc per dependent: :destroy
    when "m"
      # Destroy winner's CC, then loser's CC will be FK-reassigned during merge
      klass = Discipline.reflect_on_association(cc)&.klass
      winner_cc = klass.find_by(discipline_id: winner_id)
      winner_cc&.destroy
      protocol_append("- CC conflict (winner=#{winner_id} loser=#{loser_id} #{cc}): MOVE-LOSER chosen — winner.#{cc} destroyed; merge phase will reassign loser.#{cc}")
    when "a"
      protocol_append("- CC conflict (winner=#{winner_id} loser=#{loser_id} #{cc}): ABORT chosen — exiting")
      raise "User aborted on CC-conflict winner=#{winner_id} loser=#{loser_id} #{cc}"
    else
      raise "Invalid choice #{choice.inspect} for CC-conflict resolution"
    end
  end
  protocol_append("")
end

# ---------------------------------------------------------------------------
# Phase 4: Merge — pro Loser in eigener Transaction (D-13 Schritt 4)
# ---------------------------------------------------------------------------

# Recompute list collected during PlayerRanking conflict resolution (D-03).
# Format: [[player_id, winner_discipline_id], ...] — serialized to protocol in post-flight.
RECOMPUTE_LIST = []

def merge_loser_into_winner(loser, winner)
  puts "  Merging loser #{loser.id} (#{loser.name.inspect}) into winner #{winner.id} (#{winner.name.inspect})"
  protocol_append("### Merging loser id=#{loser.id} name=#{loser.name.inspect} → winner id=#{winner.id} name=#{winner.name.inspect}")
  protocol_append("")

  Discipline.transaction do
    # --- D-09 Pass 1: super_discipline self-ref children ---
    # Children of loser (Disciplines with super_discipline_id = loser.id) are reassigned to winner.
    # Must happen BEFORE loser.destroy because super_discipline FK has no dependent: :destroy
    # but leaving stale FK pointing at deleted loser would orphan the children.
    Discipline.where(super_discipline_id: loser.id).find_each do |child|
      child.update!(super_discipline_id: winner.id)
      protocol_append("- super_discipline reassign: child id=#{child.id} → super_discipline_id=#{winner.id}")
    end

    # --- has_many / has_one with FK :discipline_id (DISCIPLINE_ID_FK_REFLECTIONS) ---
    DISCIPLINE_ID_FK_REFLECTIONS.each do |refl|
      klass = Discipline.reflect_on_association(refl)&.klass
      next if klass.nil?

      if refl == :player_rankings
        # D-03: Unique-constraint conflict → destroy loser-side + collect for recompute
        klass.where(discipline_id: loser.id).find_each do |ranking|
          begin
            ranking.update!(discipline_id: winner.id)
          rescue ActiveRecord::RecordNotUnique
            player_id = ranking.player_id
            ranking.destroy   # PaperTrail-aware destroy
            RECOMPUTE_LIST << [player_id, winner.id]
            protocol_append("- player_ranking conflict: player_id=#{player_id} loser_ranking destroyed → recompute marked")
          end
        end
        next
      end

      if CC_REFLECTIONS.include?(refl)
        # has_one *_cc — only reassign loser's CC if winner has none (cc_scan already
        # resolved conflicts via destroy-winner if user chose "move-loser").
        next if klass.where(discipline_id: winner.id).exists?
        loser_cc = klass.find_by(discipline_id: loser.id)
        if loser_cc
          loser_cc.update!(discipline_id: winner.id)
          protocol_append("- #{refl} reassign: loser_cc id=#{loser_cc.id} → discipline_id=#{winner.id}")
        end
        next
      end

      # Generic has_many FK :discipline_id reassign
      reassigned = 0
      klass.where(discipline_id: loser.id).find_each do |child|
        child.update!(discipline_id: winner.id)
        reassigned += 1
      end
      protocol_append("- #{refl}: #{reassigned} row(s) reassigned to winner #{winner.id}") if reassigned > 0
    end

    # --- :seeding_plays uses FK :playing_discipline_id (NOT :discipline_id) ---
    seeding_count = Seeding.where(playing_discipline_id: loser.id).count
    if seeding_count > 0
      Seeding.where(playing_discipline_id: loser.id).find_each do |seeding|
        seeding.update!(playing_discipline_id: winner.id)
      end
      protocol_append("- seeding_plays: #{seeding_count} row(s) reassigned (playing_discipline_id) to winner #{winner.id}")
    end

    # --- versions: SKIP per D-10 (audit history stays at original item_id) ---
    # No action — PaperTrail Versions on the loser remain as-is. Local servers
    # are assumed sync-current; audit history at item_id=loser.id is preserved.

    # --- training_concepts: SKIP (through reflection; transferred via training_concept_disciplines) ---

    # --- Preserve loser aliases in winner.synonyms ---
    # Capture loser.name + loser.synonyms (newline-separated) so scrapers and
    # legacy lookups still resolve via Discipline#synonyms after destroy.
    # Uses winner.save! so the existing before_save :update_synonyms callback
    # deduplicates entries and adds winner.name automatically (D-04 compliant).
    loser_aliases = ([loser.name] + loser.synonyms.to_s.split("\n"))
                      .map { |s| s.to_s.strip }
                      .reject(&:empty?)
    existing       = winner.synonyms.to_s.split("\n").map(&:strip).reject(&:empty?)
    merged         = (existing + loser_aliases).uniq
    if merged.sort != existing.sort
      winner.synonyms = merged.join("\n")
      winner.save!  # before_save :update_synonyms keeps dedup + ensures name present
      protocol_append("- synonyms preserved on winner #{winner.id}: added #{(merged - existing).inspect}")
    else
      protocol_append("- synonyms unchanged on winner #{winner.id} (loser aliases already present)")
    end

    # --- Finally: destroy the loser. PaperTrail emits destroy Version. ---
    # The 4 dependent: :destroy reflections (discipline_cc, competition_cc, branch_cc,
    # training_concept_disciplines) have already been reassigned above OR (CC-cases)
    # explicitly chosen by the user to be cascade-deleted. Loser-row is now safe to destroy.
    loser_id_snapshot = loser.id
    loser_name_snapshot = loser.name
    loser.destroy
    protocol_append("- loser destroyed: id=#{loser_id_snapshot} name=#{loser_name_snapshot.inspect}")
    protocol_append("")
  end
rescue ActiveRecord::Rollback => e
  puts "ROLLBACK on loser #{loser.id}: #{e.message}"
  protocol_append("ROLLBACK on loser id=#{loser.id}: #{e.message}")
  raise
end

def perform_merges!
  puts "=== Phase 4/6: Merge ==="
  protocol_append("## Phase 4: Merge")
  protocol_append("")

  WINNER_TO_LOSERS.each do |winner_id, loser_ids|
    next if loser_ids.empty?
    winner = Discipline.find(winner_id)
    loser_ids.each do |loser_id|
      loser = Discipline.find_by(id: loser_id)
      next if loser.nil?   # already merged in a partial earlier run
      merge_loser_into_winner(loser, winner)
    end
  end
end

# ---------------------------------------------------------------------------
# Phase 5: Rename Winners (D-12 — D-13 Schritt 5)
# ---------------------------------------------------------------------------

def rename_winners!
  puts "=== Phase 5/6: Rename Winners ==="
  protocol_append("## Phase 5: Rename Winners")
  protocol_append("")

  WINNER_CANONICAL_NAMES.each do |winner_id, canonical_name|
    winner = Discipline.find(winner_id)
    next if winner.name == canonical_name

    old_name = winner.name
    winner.update!(name: canonical_name)
    puts "  Renamed Discipline id=#{winner_id}: #{old_name.inspect} → #{canonical_name.inspect}"
    protocol_append("- Discipline id=#{winner_id}: name #{old_name.inspect} → #{canonical_name.inspect}")
  end
  protocol_append("")
end

# ---------------------------------------------------------------------------
# Phase 6: Post-flight — Winner-Counts (AFTER merge) + Recompute-Liste (D-03)
# ---------------------------------------------------------------------------

def winner_reflection_count(winner_id, reflection_name)
  case reflection_name
  when :versions
    PaperTrail::Version.where(item_type: "Discipline", item_id: winner_id).count
  when :sub_disciplines
    Discipline.where(super_discipline_id: winner_id).count
  when :seeding_plays
    Seeding.where(playing_discipline_id: winner_id).count
  when :training_concepts
    0
  else
    klass = Discipline.reflect_on_association(reflection_name)&.klass
    return 0 if klass.nil?
    klass.where(discipline_id: winner_id).count
  end
end

def post_flight!
  puts "=== Phase 6/6: Post-flight ==="
  protocol_append("## Phase 6: Post-flight — Winner Counts (AFTER merge)")
  protocol_append("")

  all_reflections = %i[
    versions discipline_tournament_plans sub_disciplines tournaments
    player_classes player_rankings discipline_cc leagues game_plan_ccs
    game_plan_row_ccs seeding_plays competition_cc branch_cc
    training_concept_disciplines training_concepts
  ]

  WINNER_TO_LOSERS.keys.each do |winner_id|
    winner = Discipline.find(winner_id)
    puts "Winner #{winner_id} (#{winner.name.inspect}):"
    protocol_append("### Winner id=#{winner_id} name=#{winner.name.inspect}")
    protocol_append("")
    protocol_append("| Reflection | Count |")
    protocol_append("|------------|-------|")
    all_reflections.each do |refl|
      count = winner_reflection_count(winner_id, refl)
      puts "  #{refl}: #{count}"
      protocol_append("| #{refl} | #{count} |")
    end
    protocol_append("")
  end

  # PlayerRanking recompute list (D-03)
  protocol_append("## PlayerRanking Recompute Todo (D-03)")
  protocol_append("")
  if RECOMPUTE_LIST.empty?
    protocol_append("No PlayerRanking conflicts encountered. Recompute list empty.")
  else
    protocol_append("The following (player_id, winner_discipline_id) tuples had unique-constraint conflicts on FK-update.")
    protocol_append("The loser-side ranking was destroyed; the winner-side ranking value is now stale and must be recomputed.")
    protocol_append("")
    protocol_append("| player_id | winner_discipline_id |")
    protocol_append("|-----------|----------------------|")
    RECOMPUTE_LIST.uniq.each do |player_id, winner_id|
      protocol_append("| #{player_id} | #{winner_id} |")
    end
  end
  protocol_append("")

  puts "→ Protocol written to: #{PROTOCOL_PATH}"
  protocol_append("---")
  protocol_append("End of protocol — written #{Time.now.iso8601}")
end

# ---------------------------------------------------------------------------
# Entry point — D-13 Phasen sequentiell
# ---------------------------------------------------------------------------

protocol_init
pre_flight!
emit_stats_matrix!
scan_cc_conflicts!
perform_merges!
rename_winners!
post_flight!
puts "=== Merge complete ==="
puts "Protocol: #{PROTOCOL_PATH}"
