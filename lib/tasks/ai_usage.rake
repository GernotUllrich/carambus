# frozen_string_literal: true

# Phase 49-01/49-02: AI-Chat-Kostenbericht pro Scenario (= dieser Local-Server) UND Modell über Zeit.
# Misst aus den lokal erfassten AiUsageEvents — unabhängig vom geteilten Anthropic-Konto.
namespace :ai_usage do
  # Kurzlabel fürs LLM (Token-Modell-String → "haiku"/"sonnet", sonst gekürzt).
  short_model = lambda do |m|
    s = m.to_s
    if s[/haiku/i]
      "haiku"
    elsif s[/sonnet/i]
      "sonnet"
    else
      s[0, 14]
    end
  end

  desc "AI-Chat-Kosten/Tokens pro Scenario + Modell über Zeit (ENV: SINCE=YYYY-MM-DD UNTIL=YYYY-MM-DD BUCKET=day|week)"
  task report: :environment do
    since = ENV["SINCE"].present? ? Date.parse(ENV["SINCE"]) : nil
    until_ = ENV["UNTIL"].present? ? Date.parse(ENV["UNTIL"]) : nil
    bucket = ENV["BUCKET"].presence || "day"

    rows = AiUsageEvent.cost_report(since: since, until_: until_, bucket: bucket)
    if rows.empty?
      puts "Keine AiUsageEvents im Zeitraum (Bucket=#{bucket})."
      next
    end

    puts format("%-10s %-10s %-8s %7s %12s %12s %14s",
      "Scenario", bucket.to_s.capitalize, "Modell", "Turns", "In-Tok", "Out-Tok", "€ (Schätzung)")
    puts "-" * 78
    by_scenario = Hash.new(0.0)
    by_scenario_model = Hash.new(0.0)
    rows.each do |r|
      m = short_model.call(r[:model])
      puts format("%-10s %-10s %-8s %7d %12d %12d %14.4f",
        r[:scenario], r[:bucket].to_date.iso8601, m, r[:events], r[:input], r[:output], r[:cost_eur])
      by_scenario[r[:scenario]] += r[:cost_eur]
      by_scenario_model[[r[:scenario], m]] += r[:cost_eur]
    end
    puts "-" * 78
    by_scenario_model.sort.each { |(sc, m), cost| puts format("Summe %-10s / %-8s %14.4f €", sc, m, cost) }
    by_scenario.sort.each { |sc, cost| puts format("Summe %-10s (gesamt) %12.4f €", sc, cost) }
    puts "\nHinweis: € ist eine Schätzung aus AiUsageEvent::MODEL_RATES_EUR_PER_MTOK (pflegen)."
  end
end
