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

  desc "Scoreboard-Konto anlegen, falls es fehlt (Regionsdump-Server, Plan 18-03)"
  task ensure_scoreboard: :environment do
    user, created = LocalAccounts.ensure_scoreboard!
    puts(created ? "✅ Scoreboard-Konto angelegt: #{user.email} (id #{user.id})" : "✅ Scoreboard-Konto vorhanden: #{user.email} (id #{user.id})")
  end

  desc "Ersten Admin (system_admin) anlegen, Passwort wird einmal ausgegeben. Usage: rake \"users:create_admin[name@verein.de]\""
  task :create_admin, [:email] => :environment do |_t, args|
    user, password = LocalAccounts.create_admin!(args[:email])
    puts "✅ Admin angelegt: #{user.email} (system_admin, id #{user.id})"
    puts "   Passwort (wird nicht noch einmal angezeigt): #{password}"
    puts "   Nach der ersten Anmeldung unter „Profil“ ändern."
  rescue ArgumentError => e
    puts "❌ #{e.message}"
    exit 1
  end
end
