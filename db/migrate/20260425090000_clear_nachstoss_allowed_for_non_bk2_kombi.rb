# frozen_string_literal: true

class ClearNachstossAllowedForNonBk2Kombi < ActiveRecord::Migration[7.2]
  # Phase 38.4-16 P5 — flag-only narrowing.
  # Plan 11 erroneously wrote nachstoss_allowed: true onto BK50, BK100, BK-2, BK-2plus
  # via script/seed_bk2_disciplines.rb (and propagated to local-server DBs via
  # Version sync). User clarified (P5, interpretation b): only BK-2kombi (id 107)
  # should carry the flag. This migration removes the key from the 4 non-BK-2kombi
  # records on every existing DB. Idempotent — re-run is a no-op once the key is gone.
  #
  # Defense-in-depth alongside the seed-script edit (script/seed_bk2_disciplines.rb):
  # - Seed edit: source of truth for new installs and re-runs on carambus_api master.
  # - This migration: catch-up for servers that don't re-run the seed AND for the
  #   Version-sync race where a stale Plan-11 payload may have already propagated.

  disable_ddl_transaction! # safety; no DDL

  TARGET_NAMES = %w[BK50 BK100 BK-2 BK-2plus].freeze

  # Mirror of the Carambus MIN_ID constant. Records with id < MIN_LOCAL_ID are global
  # (managed on master); id >= MIN_LOCAL_ID are local. LocalProtector enforces this
  # boundary on local servers via app/models/local_protector.rb:32.
  MIN_LOCAL_ID = 50_000_000

  def up
    # Phase 38.4-16 P5 / I-16-02: residual sync-race risk WARNING.
    # This migration is a one-shot cleanup. If a stale Plan-11 payload arrives via
    # Version sync AFTER this migration runs (e.g., on a local server whose Discipline
    # records sync in late), the nachstoss flag will REAPPEAR on that server until
    # the seed re-runs on master AND the new flag-less payload propagates.
    # Residual sync-race risk documented in 38.4-16-PLAN.md threat T-38.4-16-07 and
    # tracked in .planning/STATE.md deferred items. Mitigation: production deployment
    # sequence ALWAYS runs the corrected seed on master FIRST (master is the canonical
    # source), then this migration on local servers (catch-up). If a server's clock
    # skews and the cleanup race triggers, re-run this migration after the next sync —
    # the idempotency guard makes re-runs safe.
    #
    # Phase 38.4-16 P5 / round-4 iteration-2 BLOCKER 2 fix (Option (i) — explicit pre-check):
    # The original Plan 16 design used `rec.update!` wrapped in a rescue block
    # catching the AR validation-failure exception, intending to catch LocalProtector's
    # rejection on local servers. That rescue was UNREACHABLE:
    # LocalProtector#disallow_saving_global_records (after_save callback) raises
    # ActiveRecord::Rollback, which AR silently swallows inside the surrounding
    # transaction. update! returns true, the row is rolled back, and no exception
    # bubbles up. The migration would silently no-op on local servers while
    # reporting cleared+=1.
    #
    # Replaced with an EXPLICIT pre-check that mirrors LocalProtector's predicate
    # (id < MIN_LOCAL_ID && ApplicationRecord.local_server?) BEFORE calling update!.
    # On master: local_server? is false → update! fires → PaperTrail records the
    # change → Version sync propagates. On local servers: for global records (id <
    # MIN_LOCAL_ID), pre-check skips with skipped_local counter + log. The local-DB
    # cleanup flows from master via Version sync (see sync-race note above).

    say_with_time "Removing nachstoss_allowed key from non-BK-2kombi BK-* disciplines (P5 narrowing)" do
      cleared = 0
      skipped_already_clean = 0
      skipped_local = 0
      missing = 0

      TARGET_NAMES.each do |name|
        rec = Discipline.find_by(name: name)
        unless rec
          missing += 1
          next
        end
        unless rec.data.present?
          skipped_already_clean += 1
          next
        end
        parsed = begin
          JSON.parse(rec.data)
        rescue JSON::ParserError
          skipped_already_clean += 1
          next
        end
        unless parsed.key?("nachstoss_allowed")
          skipped_already_clean += 1
          next
        end
        parsed.delete("nachstoss_allowed")

        # ROUND-4 ITERATION-2 BLOCKER 2 FIX (Option (i) — explicit pre-check).
        # Permit the write iff (we're on master, OR this is a local-id record on a
        # local server). Global records on local servers are skipped — cleanup
        # arrives via Version sync from master (sync-race note above).
        if !ApplicationRecord.local_server? || rec.id >= MIN_LOCAL_ID
          rec.update!(data: parsed.to_json)
          cleared += 1
          say "  cleared #{name} (id=#{rec.id})"
        else
          skipped_local += 1
          say "  [skipped on local server] #{name} (id=#{rec.id} < MIN_ID=#{MIN_LOCAL_ID}; cleanup arrives via Version sync from master — see sync-race note above)"
        end
      end

      say "Migration complete: cleared=#{cleared} skipped_already_clean=#{skipped_already_clean} skipped_local=#{skipped_local} missing=#{missing} of #{TARGET_NAMES.size} targets."
    end
  end

  def down
    # No-op: we never want to re-introduce the flag on disciplines it should not have.
    say "No-op: ClearNachstossAllowedForNonBk2Kombi is not reversible."
  end
end
