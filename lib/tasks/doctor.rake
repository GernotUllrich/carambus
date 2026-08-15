# frozen_string_literal: true

# Diagnose der CC-losen Turnier-Kette. STRIKT READ-ONLY.
#
#   bin/rails doctor:chain                  # auf einer Instanz: kann sie ihren Platz einnehmen?
#   NETWORK=0 bin/rails doctor:chain        # ohne Login-Proben (Offline/Wartung)
#   bin/rails doctor:scenarios              # aus dem Checkout: passen die Szenarien zusammen?
#   bin/rails doctor                        # beides
namespace :doctor do
  desc "Diagnose der laufenden Instanz: Rolle, Kontext, Zugaenge, Gegenstellen (read-only)"
  task chain: :environment do
    checks = Diagnostics::ChainCheck.new(probe_network: ENV["NETWORK"] != "0").call
    DoctorOutput.render("Instanz-Diagnose", checks)
    exit(1) if checks.any?(&:failed?)
  end

  desc "Statischer Abgleich aller Szenario-Configs untereinander (read-only, kein Netzwerk)"
  task scenarios: :environment do
    checks = Diagnostics::ScenarioCheck.new(data_path: ENV["CARAMBUS_DATA_PATH"].presence).call
    DoctorOutput.render("Szenario-Abgleich", checks)
    exit(1) if checks.any?(&:failed?)
  end
end

desc "Vollstaendige Diagnose: Instanz + Szenario-Abgleich"
task doctor: :environment do
  instance = Diagnostics::ChainCheck.new(probe_network: ENV["NETWORK"] != "0").call
  DoctorOutput.render("Instanz-Diagnose", instance)

  scenarios = Diagnostics::ScenarioCheck.new(data_path: ENV["CARAMBUS_DATA_PATH"].presence).call
  DoctorOutput.render("Szenario-Abgleich", scenarios)

  exit(1) if (instance + scenarios).any?(&:failed?)
end

# Ausgabe-Formatierung. Bewusst hier und nicht im Service: die Services liefern Daten, damit sie
# testbar bleiben und spaeter auch anders dargestellt werden koennen (Admin-Seite, JSON).
module DoctorOutput
  WIDTH = 78

  def self.render(title, checks)
    puts "=" * WIDTH
    puts title
    puts "=" * WIDTH

    checks.each do |check|
      puts "#{check.icon} #{check.name}: #{check.detail}"
      # Der Hinweis ist der eigentliche Wert eines Diagnose-Tools — er steht deshalb direkt unter
      # dem Befund und nicht in einer Fussnote, die niemand liest.
      check.hint.to_s.strip.split("\n").each { |line| puts "     → #{line}" } if check.hint.present?
    end

    failed = checks.count(&:failed?)
    warned = checks.count(&:warned?)
    puts "-" * WIDTH
    summary = if failed.zero? && warned.zero?
      "Alles in Ordnung (#{checks.size} Pruefungen)."
    elsif failed.zero?
      "Keine Blocker, #{warned} Auffaelligkeit(en) (#{checks.size} Pruefungen)."
    else
      "#{failed} Blocker, #{warned} Auffaelligkeit(en) (#{checks.size} Pruefungen)."
    end
    puts summary
    puts
  end
end
