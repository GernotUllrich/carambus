# frozen_string_literal: true

# Syncer fuer Meldelisten-Daten aus dem ClubCloud-System.
# Extrahiert aus RegionCc: sync_registration_list_ccs und sync_registration_list_ccs_detail.
#
# Verwendung:
#   RegionCc::RegistrationSyncer.call(
#     region_cc: region_cc, client: client,
#     operation: :sync_registration_list_ccs_detail,
#     season: season, branch_cc: branch_cc
#   )
class RegionCc::RegistrationSyncer < ApplicationService
  def initialize(options = {})
    @region_cc = options.fetch(:region_cc)
    @client = options.fetch(:client)
    @operation = options.fetch(:operation)
    @season = options[:season]
    @branch_cc = options[:branch_cc]
    @opts = options.except(:region_cc, :client, :operation, :season, :branch_cc)
  end

  def call
    case @operation
    when :sync_registration_list_ccs then sync_registration_list_ccs
    when :sync_registration_list_ccs_detail then sync_registration_list_ccs_detail(@season, @branch_cc)
    else raise ArgumentError, "Unknown operation: #{@operation}"
    end
  end

  private

  def sync_registration_list_ccs
    region = Region.find_by_shortname(@opts[:context].upcase)
    season = Season.find_by_name(@opts[:season_name])
    region_cc = region.region_cc
    if @opts[:branch_cc_cc_id].present?
      branch_cc = BranchCc.find_by_cc_id(@opts[:branch_cc_cc_id].to_i)
      sync_registration_list_ccs_detail(season, branch_cc) if branch_cc.present?
    else
      region_cc.branch_ccs.each do |branch_cc|
        sync_registration_list_ccs_detail(season, branch_cc)
      end
    end
  end

  def sync_registration_list_ccs_detail(season, branch_cc)
    context = @opts[:context]
    _, doc = @client.post("showMeldelistenList",
                          { fedId: @region_cc.cc_id, branchId: branch_cc.cc_id, disciplinId: "*", catId: "*", season: season.name }, @opts)
    options = doc.css("select[name=\"meldelisteId\"] > option")
    options.each do |option|
      cc_id_ml = option["value"].to_i
      name = option.text.strip
      status = ""
      deadline = Date.today
      qualifying_date = Date.today
      discipline_id = nil
      category_cc_id = nil
      pos_hash = {}
      registration_list_cc = RegistrationListCc.find_or_initialize_by(cc_id: cc_id_ml)
      # if branch_cc.cc_id == 10 && season.name == "2010/2011"
      #   _, doc_cat = @client.post('deleteMeldeliste', { branchId: 10, fedId: @region_cc.cc_id, season: season.name, meldelisteId: cc_id_ml }, @opts)
      #   next
      # end
      next if !registration_list_cc.new_record? && @opts[:update_from_cc].blank?

      _, doc_cat = @client.post("showMeldeliste",
                                { fedId: @region_cc.cc_id, branchId: branch_cc.cc_id, disciplinId: "*", meldelisteId: cc_id_ml, catId: "*", season: season.name }, @opts)
      lines = doc_cat.css("tr.tableContent > td > table > tr")
      begin
        lines.each do |tr|
          if /Meldungen/.match?(tr.css("td")[0].text.strip)
            positions = tr.css("td > table > tr")
            positions.each do |position|
              pos = position.css("td").andand[0].andand.text.andand.to_i
              val = position.css("td").andand[1].andand.text
              pos_hash[pos.to_i] = val if pos.present?
            end
          elsif /Meldeliste/.match?(tr.css("td")[0].text.strip)
            name = tr.css("td")[2].text.strip
          elsif /Disziplin/.match?(tr.css("td")[0].text.strip)
            d_name = tr.css("td")[2].text.strip.gsub("(großes Billard)", "groß").gsub("(kleines Billard)", "klein").gsub("5-Kegel", "5 Kegel").gsub("14/1 endlos", "14.1 endlos").gsub("15-reds", "Snooker").gsub(
              "Billard Kegeln", "Billard-Kegeln"
            )
            discipline_id = Discipline.find_by_name(d_name).andand.id
          elsif /Kategorie/.match?(tr.css("td")[0].text.strip)
            k_name = tr.css("td")[2].text.strip
            m = k_name.match(/(.*) \(\d+-\d+\)/)
            category_cc_id = CategoryCc.where(context: context, branch_cc_id: branch_cc.id, name: m[1]).first.andand.id
          elsif /Meldeschluss/.match?(tr.css("td")[0].text.strip)
            deadline = tr.css("td")[2].text.strip
            deadline = Date.parse(deadline) if /\d\d\.\d\d\.\d\d\d\d/.match?(deadline)
          elsif /Stichtag/.match?(tr.css("td")[0].text.strip)
            qualifying_date = tr.css("td")[2].text.strip
            if m = qualifying_date.match(/(\d\d\.\d\d\.\d\d\d\d).*/)
              qualifying_date = Date.parse(m[1])
            end
          elsif /Status/.match?(tr.css("td")[0].text.strip)
            status = tr.css("td")[2].text.strip.gsub(/^\u00A0/, "").strip
          end
        end
        if @opts[:release] && status != "Freigegeben"
          _, doc = @client.post("releaseMeldeliste",
                                { branchId: branch_cc.cc_id, fedId: branch_cc.region_cc.cc_id, season: season.name, meldelisteId: registration_list_cc.cc_id, release: "" }, @opts)
        end
        registration_list_cc.update(season_id: season.id, discipline_id: discipline_id, category_cc_id: category_cc_id,
                                    context: context, branch_cc_id: branch_cc.id, name: name, status: "Freigegeben", deadline: deadline, qualifying_date: qualifying_date)
      rescue Exception
        Rails.logger.error "Error"
      end
    end
  end
end
