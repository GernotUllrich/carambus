# frozen_string_literal: true

# Quick-260505-auq Follow-up — strip obsolete tiebreak_on_draw config keys
# from carambus_api production data so local servers receive a clean state via
# the standard Version sync mechanism.
#
# Background:
#   Quick-260505-auq added a state-driven override:
#   TableMonitor#playing_finals_force_tiebreak_required! mutates
#   game.data['tiebreak_required']=true whenever the active TournamentMonitor is
#   in AASM state :playing_finals. The override fires at decision time, before
#   the resolver gates in TableMonitor#tiebreak_pending_block? and
#   ResultRecorder#tiebreak_pick_pending? read it.
#
#   This makes the data-side plumbing introduced in Phase 38.7-09..13
#   redundant for the case it was actually meant to fix (Finale 10:10).
#   The user opted to remove the now-noise from carambus_api production.
#
# What gets stripped:
#   Pass 1 — Tournament.data['tiebreak_on_draw']
#            (Level 1 of resolver in Game.derive_tiebreak_required)
#   Pass 2 — TournamentPlan.executor_params['g{N}']['tiebreak_on_draw']
#            (Level 2 of resolver; per-group buckets g1, g2, ...)
#   Pass 2 also defensively strips a top-level executor_params['tiebreak_on_draw']
#            if it ever leaked there.
#
# What is NOT touched:
#   - Game.data['tiebreak_required']  — in-flight runtime state, not config.
#   - Discipline rows                 — forbidden per project memory
#                                       "Tiebreak independent from Discipline".
#   - Application code (controllers, _form.html.erb, Game.derive_tiebreak_required)
#                                       — that's a separate refactor.
#
# Sync discipline:
#   Uses ONLY PaperTrail-aware ActiveRecord calls (update!). NEVER
#   update_columns / update_all / raw SQL. Each update! emits a PaperTrail
#   Version row, which local servers consume via Version#update_from_carambus_api
#   so their copies converge after the next sync cycle.
#
# Idempotent: a second run with no remaining keys is a safe no-op.
#
# Usage:
#   cd /Users/gullrich/DEV/carambus/carambus_api
#   RAILS_ENV=development bin/rails runner script/strip_tiebreak_on_draw.rb            # DRY-RUN (preview only)
#   RAILS_ENV=development APPLY=1 bin/rails runner script/strip_tiebreak_on_draw.rb    # actually mutate
#
# Note: on this machine the canonical carambus_api server runs in development
# mode (DB = carambus_api_development). RAILS_ENV=production only if the
# deployment-target host actually uses that env.
#
# Output:
#   tmp/strip-tiebreak-on-draw-{YYYYMMDD-HHMMSS}.md (Before/After protocol)

require "fileutils"

apply_mode = ENV["APPLY"] == "1"
log_lines = []

ts = Time.now.strftime("%Y%m%d-%H%M%S")
report_path = Rails.root.join("tmp", "strip-tiebreak-on-draw-#{ts}.md")
FileUtils.mkdir_p(File.dirname(report_path))

emit = lambda do |line|
  log_lines << line
  puts line
end

emit.call "# Strip tiebreak_on_draw — #{ts}"
emit.call ""
emit.call "Mode: #{apply_mode ? '**APPLY (mutating)**' : '**DRY-RUN (preview only)**'}"
emit.call "DB:   #{ActiveRecord::Base.connection_db_config.database}"
emit.call "Env:  #{Rails.env}"
emit.call ""

# Coerce a serialized-or-native jsonb column into a Hash. Tournament.data and
# TournamentPlan.executor_params are jsonb in schema, but defensive against
# legacy String values just in case.
to_hash = lambda do |raw|
  case raw
  when Hash then raw
  when String then (raw.empty? ? {} : JSON.parse(raw))
  when nil then {}
  else {}
  end
end

# --- Pass 1: Tournament.data['tiebreak_on_draw'] ---

emit.call "## Pass 1 — Tournament.data['tiebreak_on_draw']"
emit.call ""

t_count = 0
# Coarse string-match prefilter; works whether data is text or jsonb. Refine in
# Ruby below — the substring may also legitimately appear in non-key positions
# (unlikely but cheap to guard against).
Tournament.where("data::text LIKE '%tiebreak_on_draw%'").find_each do |t|
  data = to_hash.call(t.data)
  next unless data.key?("tiebreak_on_draw")

  before = data["tiebreak_on_draw"]
  emit.call "- Tournament ##{t.id} \"#{t.title}\" — data['tiebreak_on_draw']=#{before.inspect} → REMOVE"
  if apply_mode
    new_data = data.dup
    new_data.delete("tiebreak_on_draw")
    t.update!(data: new_data)
  end
  t_count += 1
end
emit.call ""
emit.call "→ #{t_count} Tournament row(s) #{apply_mode ? 'updated' : 'would be updated'}."
emit.call ""

# --- Pass 2: TournamentPlan.executor_params['g{N}']['tiebreak_on_draw'] (+ defensive top-level) ---

emit.call "## Pass 2 — TournamentPlan.executor_params['g{N}']['tiebreak_on_draw']"
emit.call ""

p_count = 0
# Coarse string-match prefilter; refine in Ruby. Captures the key whether it
# appears under g{N} or (defensively) at any other depth.
TournamentPlan.where("executor_params::text LIKE '%tiebreak_on_draw%'").find_each do |plan|
    puts "#{plan.id}#{plan.name}"
    ep = JSON.parse(plan.executor_params)
  next if ep.empty?

  # new_ep = Marshal.load(Marshal.dump(ep)) # deep copy without depending on AS deep_dup
  new_ep = ep
  changed = false

  # Defensive: top-level key (not expected, but if it leaked there we strip it).
  if new_ep.key?("tiebreak_on_draw")
    before = new_ep["tiebreak_on_draw"]
    emit.call "- TournamentPlan ##{plan.id} (executor_params['tiebreak_on_draw']=#{before.inspect} → REMOVE (defensive: top-level)"
    new_ep.delete("tiebreak_on_draw")
    changed = true
  end

  # Round-bucket Hashes at the top level. Real-world executor_params carry
  # tiebreak_on_draw under any of: g1/g2/... (groups), hf1/hf2 (half-finals),
  # fin (final), p<3-4>/p<5-6>/... (placement matches). Match any top-level key
  # whose value is a Hash containing the key — covers all observed shapes
  # without hard-coding the bucket vocabulary.
  new_ep.keys.each do |k|
    bucket = new_ep[k]
    next unless bucket.is_a?(Hash) && bucket.key?("tiebreak_on_draw")

    before = bucket["tiebreak_on_draw"]
    emit.call "- TournamentPlan ##{plan.id} (executor_params['#{k}']['tiebreak_on_draw']=#{before.inspect} → REMOVE"
    bucket.delete("tiebreak_on_draw")
    changed = true
  end

  if changed
    plan.update!(executor_params: new_ep.to_json) if apply_mode
    p_count += 1
  end
end
emit.call ""
emit.call "→ #{p_count} TournamentPlan row(s) #{apply_mode ? 'updated' : 'would be updated'}."
emit.call ""

# --- Summary ---

emit.call "## Summary"
emit.call ""
emit.call "| Pass | Rows | Status |"
emit.call "|------|------|--------|"
emit.call "| Tournament.data['tiebreak_on_draw'] | #{t_count} | #{apply_mode ? 'applied' : 'preview'} |"
emit.call "| TournamentPlan.executor_params (g{N} + top-level) | #{p_count} | #{apply_mode ? 'applied' : 'preview'} |"
emit.call ""
emit.call(apply_mode ? "Done. Local servers will converge on the next Version sync cycle." : "Re-run with `APPLY=1` to mutate.")
emit.call ""
emit.call "Idempotent: re-running this script with no remaining keys is a safe no-op."

File.write(report_path, log_lines.join("\n"))
puts ""
puts "Report written: #{report_path}"
