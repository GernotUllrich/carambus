# frozen_string_literal: true

# Phase 38.5 BK-Param-Hierarchy + Multiset-Config.
#
# Resolves two BK scoring parameters through a 7-level hierarchy:
#   1. Discipline       (lowest priority, default)
#   2. Tournament       (Tournament-Pfad, deferred — slot reserved)
#   3. TournamentPlan   (RESERVED — schema has no `data` column on tournament_plans;
#                        skip silently. Add migration in follow-up phase if override needed.)
#   4. TournamentMonitor (Tournament-Pfad, deferred — slot reserved)
#   5. Quickstart-Preset (UI-Toggle deferred per D-16; values flow into table_monitor.data
#                         via controller params, so this level is functionally a no-op
#                         in Phase 38.5 — falls through to Level 7 below.)
#   6. Detail-Form      (UI-Toggle deferred per D-16; same as Level 5 — falls through.)
#   7. TableMonitor     (highest priority — explicit override)
#
# Walk: highest-priority first; first-found explicit `data.key?(param)` wins.
# Fallback `false` per D-04 if no level explicitly sets the param.
#
# Effective Discipline (BK-2kombi only):
#   For BK-2kombi matches, per-set effective_discipline alternates between
#   bk_2plus and bk_2 driven by data["multiset_components"] and the current
#   set index. For non-BK-2kombi matches, effective_discipline ==
#   data["free_game_form"] (identity).
module BkParamResolver
  REGISTERED_PARAMS = %i[allow_negative_score_input negative_credits_opponent].freeze

  MULTISET_DEFAULT_DZ_FIRST = %w[bk_2plus bk_2].freeze
  MULTISET_DEFAULT_SP_FIRST = %w[bk_2 bk_2plus].freeze

  # Resolves all REGISTERED_PARAMS through the hierarchy and writes results
  # (plus effective_discipline) into table_monitor.data. Caller is responsible
  # for tm.save! — this method does NOT save.
  #
  # Idempotent: calling bake! twice in a row produces the same result.
  def self.bake!(table_monitor)
    eff_form = compute_effective_discipline(table_monitor)
    table_monitor.data["effective_discipline"] = eff_form

    REGISTERED_PARAMS.each do |param|
      table_monitor.data[param.to_s] = resolve(
        param,
        table_monitor: table_monitor,
        effective_discipline_form: eff_form
      )
    end
  end

  # Walks the hierarchy for one param. Returns the first explicitly-set value
  # (data.key?(param) is the test, NOT .present? — so explicit false overrides true).
  # Falls back to false (D-04) when no level sets the param.
  def self.resolve(param, table_monitor:, effective_discipline_form: nil)
    eff_form = effective_discipline_form || compute_effective_discipline(table_monitor)
    discipline_record = lookup_discipline(eff_form)
    key = param.to_s

    # Walk highest priority FIRST (Level 7 → Level 1).
    # Levels 5 and 6 (Quickstart-Preset, Detail-Form) are deferred per D-16 — values
    # already flow into table_monitor.data via controller params, so the
    # TableMonitor level captures them. They collapse into Level 7.
    levels = [
      table_monitor.data,                                  # Level 7 (highest)
      # Level 6 Detail-Form: deferred (D-16) — values land in tm.data
      # Level 5 Quickstart-Preset: deferred (D-16) — values land in tm.data
      table_monitor.tournament_monitor&.data,              # Level 4
      # Level 3 TournamentPlan: SKIPPED — no `data` column in schema
      # (db/schema.rb:1255–1268). Add column + migration in follow-up phase
      # if override needed.
      table_monitor.tournament_monitor&.tournament&.data,  # Level 2
      parsed_discipline_data(discipline_record)            # Level 1 (lowest, default)
    ]

    levels.each do |lvl|
      next if lvl.nil?
      return lvl[key] if lvl.key?(key)
    end

    false # D-04 fallback
  end

  # For BK-2kombi: per-set alternation between bk_2plus and bk_2.
  # For all other free_game_forms: identity with data["free_game_form"].
  def self.compute_effective_discipline(table_monitor)
    form = table_monitor.data["free_game_form"]
    return form unless form == "bk2_kombi"

    first_mode = table_monitor.data.dig("bk2_options", "first_set_mode").to_s
    first_mode = "direkter_zweikampf" unless %w[direkter_zweikampf serienspiel].include?(first_mode)

    components = table_monitor.data["multiset_components"]
    components = nil unless components.is_a?(Array) && components.length == 2
    components ||= ((first_mode == "direkter_zweikampf") ? MULTISET_DEFAULT_DZ_FIRST : MULTISET_DEFAULT_SP_FIRST)

    set_index = Array(table_monitor.data["sets"]).length + 1
    components[(set_index - 1) % 2]
  end

  # Looks up the Discipline AR record for a free_game_form string.
  # Uses TableMonitor::GameSetup::BK_NAME_TO_FORM.invert for BK-* family.
  # Returns nil if no match — caller falls through to default false.
  #
  # Non-BK families (karambol, snooker, pool, etc.) intentionally return nil here:
  # Discipline-defaults for non-BK are not seeded (D-08), so the resolver falls
  # through to false at Level 1, which preserves today's behaviour for
  # karambol/snooker/pool.
  def self.lookup_discipline(free_game_form)
    return nil if free_game_form.blank?

    bk_name = TableMonitor::GameSetup::BK_NAME_TO_FORM.invert[free_game_form]
    return Discipline.find_by(name: bk_name) if bk_name

    nil
  end

  # Discipline.data is raw JSON text (no `serialize` declaration on Discipline).
  # Mirror the pattern from discipline.rb:397–428.
  def self.parsed_discipline_data(discipline)
    return {} if discipline.nil? || discipline.data.blank?
    JSON.parse(discipline.data)
  rescue JSON::ParserError
    {}
  end

  private_class_method :compute_effective_discipline,
    :lookup_discipline,
    :parsed_discipline_data
end
