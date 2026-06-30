# frozen_string_literal: true

# Phase 49-01: AI-Chat-Kostenbericht pro Scenario (= dieser Local-Server) über Zeit.
# Misst aus den lokal erfassten AiUsageEvents — unabhängig vom geteilten Anthropic-Konto.
namespace :ai_usage do
  desc "AI-Chat-Kosten/Tokens pro Scenario über Zeit (ENV: SINCE=YYYY-MM-DD UNTIL=YYYY-MM-DD BUCKET=day|week)"
  task report: :environment do
    since = ENV["SINCE"].present? ? Date.parse(ENV["SINCE"]) : nil
    until_ = ENV["UNTIL"].present? ? Date.parse(ENV["UNTIL"]) : nil
    bucket = ENV["BUCKET"].presence || "day"

    rows = AiUsageEvent.cost_report(since: since, until_: until_, bucket: bucket)
    if rows.empty?
      puts "Keine AiUsageEvents im Zeitraum (Bucket=#{bucket})."
      next
    end

    puts format("%-12s %-12s %7s %12s %12s %14s", "Scenario", bucket.to_s.capitalize, "Turns", "In-Tok", "Out-Tok", "€ (Schätzung)")
    puts "-" * 74
    by_scenario = Hash.new(0.0)
    rows.each do |r|
      puts format("%-12s %-12s %7d %12d %12d %14.4f",
        r[:scenario], r[:bucket].to_date.iso8601, r[:events], r[:input], r[:output], r[:cost_eur])
      by_scenario[r[:scenario]] += r[:cost_eur]
    end
    puts "-" * 74
    by_scenario.each { |sc, cost| puts format("Summe %-20s %14.4f €", sc, cost) }
    puts "\nHinweis: € ist eine Schätzung aus AiUsageEvent::MODEL_RATES_EUR_PER_MTOK (pflegen)."
  end
end
