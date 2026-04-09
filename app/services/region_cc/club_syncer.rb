# frozen_string_literal: true

# Extrahiert sync_clubs aus RegionCc in einen eigenstaendigen Service.
# Synchronisiert Club-Datensaetze (Vereine) aus der ClubCloud-API.
#
# Verwendung:
#   RegionCc::ClubSyncer.call(region_cc: region_cc, client: club_cloud_client, **opts)
class RegionCc::ClubSyncer < ApplicationService
  STATUS_MAP = { active: 1, passive: 2 }.freeze

  def initialize(kwargs = {})
    @region_cc = kwargs[:region_cc]
    @client = kwargs[:client]
    @opts = kwargs.except(:region_cc, :client)
  end

  # Liest Club-Optionen aus der CC-API und aktualisiert Club-Datensaetze.
  # Gibt ein Array der synchronisierten Club-Objekte zurueck.
  # Loggt eine Warnung fuer Clubs die nicht in der Datenbank gefunden werden.
  def call
    context = @region_cc.shortname.downcase
    region = Region.find_by_shortname(context.upcase)
    done_clubs = []
    done_club_cc_ids = []
    BranchCc.where(context: context).each do |branch_cc|
      branch_cc.competition_ccs.each do |competition_cc|
        %i[active passive].each do |status|
          _, doc = @client.post(
            "showClubList",
            { sortKey: "NAME",
              fedId: branch_cc.fedId,
              branchId: branch_cc.cc_id,
              subBranchId: competition_cc.cc_id,
              sportDistrictId: "*",
              statusId: STATUS_MAP[status] },
            @opts
          )
          clubs = doc.css('select[name="clubId"] option')
          clubs.each do |club|
            cc_id = club["value"].to_i
            next if done_club_cc_ids.include?(cc_id)

            name_str = club.text.strip
            shortname = name_str.match(/\s*([^(]*)\s*(?:\(.*)?/).andand[1].strip
            c = Club.find_by_cc_id(cc_id)
            if c.present?
              if c.shortname != shortname
                RegionCc.logger.warn "REPORT! [sync_clubs] name mismatch found - CC: '#{shortname}' BA: #{c.shortname}"
              end
              c.assign_attributes(cc_id: cc_id, status: status)
              c.save!
              done_club_cc_ids.push(cc_id)
              done_clubs.push(c)
            else
              c = Club.where(shortname: shortname, region_id: region.id).first
              unless c.present?
                RegionCc.logger.warn "REPORT! [sync_clubs] no club with name '#{shortname}' found in region #{context}"
              end
            end
          end
        end
      end
    end
    done_clubs
  end
end
