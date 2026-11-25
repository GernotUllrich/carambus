# frozen_string_literal: true

# Heimat-Region eines Doppelmitglieds festlegen (Verein in zwei Regional-ClubClouds gelistet, ClubCcEntry).
# Maßgeblich ist die DBU-Vereinsliste je Mitgliedsverband (billard-union.net/cbdet.php, Auswahl „sk“); führt
# die DBU einen Verein unter zwei Verbänden, entscheidet der Betreiber (2026-11-25: RLP/Saar → BVRP).
#
# Setzt clubs.region_id/cc_id/source_url auf die Heimat und trägt deren Listung in club_cc_entries ein. Die
# bisherige Listung bleibt als Fremdlistung stehen; der nächtliche Vereins-Scrape lässt den Verein dann dort
# in Ruhe. Name/Adresse übernimmt der nächste Scrape der Heimat-Region. Erzeugt Club-Versionen (Sync).
#
# Usage:
#   bundle exec rake clubs:set_home HOMES="3:BVRP:2754,8:BVRP:3116"              # Probelauf
#   bundle exec rake clubs:set_home HOMES="3:BVRP:2754,8:BVRP:3116" ARMED=true   # schreiben
# HOMES: <club_id>:<Region-Kürzel>:<cc_id in dieser Region>, kommagetrennt.
namespace :clubs do
  desc "Heimat-Region von Doppelmitgliedern setzen (HOMES=club:REGION:cc_id,… ARMED=true)"
  task set_home: :environment do
    armed = ENV["ARMED"] == "true"
    puts armed ? "ARMED — schreibe" : "Probelauf (ARMED=true zum Schreiben)"

    ENV.fetch("HOMES").split(",").map(&:strip).each do |spec|
      club_id, region_short, cc_id = spec.split(":")
      club = Club.find_by(id: club_id.to_i)
      region = Region.find_by(shortname: region_short)
      cc_id = cc_id.to_i
      if club.nil? || region.nil? || region.public_cc_url_base.blank? || !cc_id.positive?
        puts "#{spec}: übersprungen — Verein, Region mit ClubCloud oder cc_id fehlt"
        next
      end

      taken = ClubCcEntry.find_by(region_id: region.id, cc_id: cc_id)
      taken_club = taken.club_id if taken && taken.club_id != club.id
      taken_club ||= Club.where(region_id: region.id, cc_id: cc_id).where.not(id: club.id).pick(:id)
      if taken_club
        puts "#{spec}: übersprungen — #{region.shortname} cc_id #{cc_id} gehört Verein #{taken_club}"
        next
      end

      url = ClubCloudPublicClient.new(base_url: region.public_cc_url_base, fed_id: region.cc_id).url_for("cbdet.php", a: cc_id)
      before = "#{club.region&.shortname} cc_id #{club.cc_id}"
      club.assign_attributes(region_id: region.id, cc_id: cc_id, source_url: url)
      if club.changed?
        puts "#{club.shortname}[#{club.id}]: #{before} → #{region.shortname} cc_id #{cc_id}"
        Club.skip_cable_ready_updates { club.save! } if armed
      else
        puts "#{club.shortname}[#{club.id}]: Heimat ist bereits #{region.shortname} cc_id #{cc_id}"
      end
      ClubCcEntry.record!(club, region, cc_id) if armed
    end
  end
end
