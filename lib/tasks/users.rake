# frozen_string_literal: true

namespace :users do
  desc "Loescht unbestaetigte Bot-/Karteileichen-Accounts [Tage (default: 7)]"
  task :purge_unconfirmed, [:older_than_days] => :environment do |_t, args|
    days = (args[:older_than_days] || 7).to_i

    puts "🧹 Purge: unbestaetigte Accounts aelter als #{days} Tage (nie bestaetigt, nie eingeloggt, kein Player)..."
    deleted = User.purge_unconfirmed!(older_than: days.days)

    if deleted.empty?
      puts "✅ Keine zu loeschenden Accounts gefunden."
    else
      deleted.each { |id, email| puts "  🗑️  ##{id}  #{email}" }
      puts "✅ #{deleted.size} Account(s) geloescht."
    end
  end
end
