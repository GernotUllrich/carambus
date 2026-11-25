# frozen_string_literal: true

# DBU-Nr. von Vereinen zurückschreiben, die ein Liga-Scrape gelöscht hat.
#
# Anlass: DBU-Rescrape 2026-11-25. Auf billard-union.net liest League::ClubCloudScraper die DBU-Nr. von der
# Vereinsseite verein-details.php; die liefert seit November HTTP 410, die Nr. blieb nil und wurde trotzdem
# gespeichert. Die gelöschten Werte stehen in den Club-Versionen (object_changes dbu_nr: [X, nil]).
#
# Zurückgeschrieben wird nur, wenn der Verein heute noch keine dbu_nr hat und kein anderer Verein X trägt.
# Erzeugt Club-Versionen — die Korrektur repliziert wie der Schaden an die Regional-Server.
#
# Usage:
#   bundle exec rake clubs:restore_dbu_nr FROM_VERSION=13955200                       # Probelauf
#   bundle exec rake clubs:restore_dbu_nr FROM_VERSION=13955200 TO_VERSION=13955331   # Bereich begrenzen
#   bundle exec rake clubs:restore_dbu_nr FROM_VERSION=13955200 ARMED=true            # schreiben
namespace :clubs do
  desc "Von einem Scrape gelöschte dbu_nr aus den Club-Versionen zurückschreiben (FROM_VERSION, ARMED=true)"
  task restore_dbu_nr: :environment do
    armed = ENV["ARMED"] == "true"
    from = Integer(ENV.fetch("FROM_VERSION"))
    to = ENV["TO_VERSION"].presence && Integer(ENV["TO_VERSION"])
    puts armed ? "ARMED — schreibe" : "Probelauf (ARMED=true zum Schreiben)"

    versions = PaperTrail::Version.where(item_type: "Club", event: "update").where("id >= ?", from)
    versions = versions.where("id <= ?", to) if to
    restored = skipped = 0
    versions.order(:id).each do |version|
      old, new = version.changeset["dbu_nr"]
      next unless old.to_i.positive? && new.nil?

      club = Club.find_by(id: version.item_id)
      reason = if club.nil? then "Verein gelöscht"
      elsif club.dbu_nr.present? then "hat wieder dbu_nr #{club.dbu_nr}"
      elsif (other = Club.where(dbu_nr: old).where.not(id: club.id).pick(:id)) then "dbu_nr #{old} trägt Verein #{other}"
      end
      if reason
        skipped += 1
        puts "Version #{version.id} Verein #{version.item_id}: übersprungen — #{reason}"
        next
      end

      restored += 1
      puts "#{club.shortname}[#{club.id}]: dbu_nr nil → #{old} (Version #{version.id})"
      Club.skip_cable_ready_updates { club.update!(dbu_nr: old) } if armed
    end
    puts "#{armed ? "zurückgeschrieben" : "würde zurückschreiben"}: #{restored} · übersprungen: #{skipped}"
  end
end
