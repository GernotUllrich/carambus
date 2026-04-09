# frozen_string_literal: true

# Extrahiert sync_branches aus RegionCc in einen eigenstaendigen Service.
# Synchronisiert Branch-Cc-Datensaetze (Disziplinen) aus der ClubCloud-API.
#
# Verwendung:
#   RegionCc::BranchSyncer.call(region_cc: region_cc, client: club_cloud_client, **opts)
class RegionCc::BranchSyncer < ApplicationService
  def initialize(kwargs = {})
    @region_cc = kwargs[:region_cc]
    @client = kwargs[:client]
    @opts = kwargs.except(:region_cc, :client)
  end

  # Liest Branch-Optionen aus der CC-API und legt BranchCc-Datensaetze an/aktualisiert sie.
  # Gibt ein Array der synchronisierten Branch-Objekte zurueck.
  # Wirft ArgumentError wenn ein Branch-Name nicht in der Datenbank gefunden wird.
  def call
    branches = []
    context = @region_cc.shortname.downcase
    opts = @opts.dup
    opts.delete("armed")
    _, doc = @client.get("showClubList", {}, opts)
    selector = doc.css('select[name="branchId"]')[0]
    option_tags = selector.css("option")
    option_tags.each do |option|
      cc_id = option["value"].to_i
      name_str = option.text.strip
      match = name_str.match(/(.*)(:? \((.*)\))?/)
      branch_name = match[1]
      branch = Branch.find_by_name(branch_name)
      if branch.blank?
        msg = "No Branch with name #{branch_name} in database"
        RegionCc.logger.error "[get_branches_from_cc] #{msg}"
        raise ArgumentError, msg, caller
      else
        args = { cc_id: cc_id, region_cc_id: @region_cc.id, discipline_id: branch.id, context: context, name: branch_name }
        branch_cc = BranchCc.find_by_cc_id(cc_id) || BranchCc.new(args)
        branch_cc.assign_attributes(args)
        branch_cc.save
        branches.push(branch)
      end
    end
    branches
  end
end
