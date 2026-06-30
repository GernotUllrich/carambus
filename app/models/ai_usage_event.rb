# frozen_string_literal: true

# Phase 49-01: lokale Telemetrie des AI-Token-Verbrauchs im SpielleiterChat.
# Ein Record je Chat-Turn UND Modell (Haiku→Sonnet-Hybrid kann beide treffen), attribuiert
# nach scenario_context (= Local-Server/Scenario), user und persona. est_cost_eur ist eine
# Schätzung aus MODEL_RATES_EUR_PER_MTOK — NICHT die echte Anthropic-Rechnung.
class AiUsageEvent < ApplicationRecord
  # €/Mio-Tokens — SCHÄTZUNG auf Basis der Anthropic-Listenpreise (USD→EUR ~0,92, Stand 2026-06).
  # ⚠️ PFLEGEN: bei Preis-/Wechselkursänderung hier aktualisieren. Modell-Strings spiegeln
  # SpielleiterChatService::FAST_MODEL / STRONG_MODEL.
  MODEL_RATES_EUR_PER_MTOK = {
    "claude-haiku-4-5-20251001" => {input: 0.92, output: 4.60, cache_write: 1.15, cache_read: 0.092},
    "claude-sonnet-4-6" => {input: 2.76, output: 13.80, cache_write: 3.45, cache_read: 0.276}
  }.freeze

  before_save :compute_est_cost_eur

  # 49-01: schreibt je verwendetem Modell EINEN Event für einen Chat-Turn.
  # usage_by_model = { model_string => {input:, output:, cache_creation:, cache_read:} }
  # (aus SpielleiterChatService#converse). persona = Snapshot der Nutzer-Personas (D-38),
  # Fallback user.role. Gibt die erzeugten Events zurück.
  def self.record_turn(usage_by_model:, user:, scenario:)
    persona = Array(user.try(:personas)).join(",").presence || user.try(:role).to_s
    Array(usage_by_model).map do |model, u|
      u ||= {}
      create!(
        scenario_context: scenario.to_s, user_id: user&.id, persona: persona, model: model.to_s,
        input_tokens: u[:input].to_i, output_tokens: u[:output].to_i,
        cache_creation_tokens: u[:cache_creation].to_i, cache_read_tokens: u[:cache_read].to_i
      )
    end
  end

  # 49-01: Kostenbericht pro Scenario über Zeit (für `rake ai_usage:report`). bucket = :day | :week.
  # Gibt strukturierte Zeilen zurück (eine je scenario_context + Zeit-Bucket).
  def self.cost_report(since: nil, until_: nil, bucket: :day)
    trunc = (bucket.to_s == "week") ? "week" : "day"
    bucket_sql = Arel.sql("date_trunc('#{trunc}', created_at)")
    rel = all
    rel = rel.where("created_at >= ?", since) if since
    rel = rel.where("created_at < ?", until_) if until_
    rel.group(:scenario_context).group(bucket_sql).order(bucket_sql)
      .pluck(:scenario_context, bucket_sql,
        Arel.sql("count(*)"), Arel.sql("sum(input_tokens)"), Arel.sql("sum(output_tokens)"),
        Arel.sql("sum(cache_creation_tokens)"), Arel.sql("sum(cache_read_tokens)"), Arel.sql("sum(est_cost_eur)"))
      .map do |sc, bucket_time, cnt, inp, out, cc, cr, cost|
        {scenario: sc, bucket: bucket_time, events: cnt.to_i, input: inp.to_i, output: out.to_i,
         cache_creation: cc.to_i, cache_read: cr.to_i, cost_eur: cost.to_f}
      end
  end

  private

  # Schätzt die €-Kosten aus den Token-Spalten + den Modell-Raten. Unbekanntes Modell → 0,0
  # (mit Log-Warnung), damit Telemetrie nie crasht.
  def compute_est_cost_eur
    rate = MODEL_RATES_EUR_PER_MTOK[model]
    unless rate
      Rails.logger.warn("[AiUsageEvent] keine Kostenrate für Modell #{model.inspect} — est_cost_eur=0")
      self.est_cost_eur = 0
      return
    end
    self.est_cost_eur =
      input_tokens.to_i / 1_000_000.0 * rate[:input] +
      output_tokens.to_i / 1_000_000.0 * rate[:output] +
      cache_creation_tokens.to_i / 1_000_000.0 * rate[:cache_write] +
      cache_read_tokens.to_i / 1_000_000.0 * rate[:cache_read]
  end
end
