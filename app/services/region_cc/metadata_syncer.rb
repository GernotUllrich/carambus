# frozen_string_literal: true

# Kapselt die Synchronisation von Metadaten-Referenzobjekten aus ClubCloud:
# Kategorien, Gruppen und Disziplinen. Alle drei Operationen sind strukturell
# identisch (POST → Optionsliste parsen → Records anlegen/aktualisieren).
#
# Verwendung:
#   RegionCc::MetadataSyncer.call(
#     region_cc: @region_cc,
#     client: @client,
#     operation: :sync_category_ccs,
#     **opts
#   )
class RegionCc::MetadataSyncer < ApplicationService
  def initialize(region_cc:, client:, operation:, **opts)
    @region_cc = region_cc
    @client = client
    @operation = operation
    @opts = opts
  end

  def call
    case @operation
    when :sync_category_ccs then sync_category_ccs
    when :sync_group_ccs then sync_group_ccs
    when :sync_discipline_ccs then sync_discipline_ccs
    else raise ArgumentError, "Unknown operation: #{@operation}"
    end
  end

  private

  def sync_category_ccs
    region = Region.find_by_shortname(@opts[:context].upcase)
    region_cc = region.region_cc
    region_cc.branch_ccs.each do |branch_cc|
      _, doc = @client.post("showCategoryList", { fedId: @region_cc.cc_id, branchId: branch_cc.cc_id }, @opts)
      options = doc.css("select[name=\"catId\"] > option")
      options.each do |option|
        option_cc_id = option["value"].to_i
        name = option.text.strip
        status = sex = max_age = min_age = nil
        category_cc = CategoryCc.find_or_initialize_by(cc_id: option_cc_id)
        _, doc_cat = @client.post("showCategory", { fedId: @region_cc.cc_id, branchId: branch_cc.cc_id, catId: option_cc_id }, @opts)
        lines = doc_cat.css("tr.tableContent > td > table > tr")
        lines.each do |tr|
          if /Kategorie/.match?(tr.css("td")[0].text.strip)
            name = tr.css("td")[2].text.strip
            if m = name.match(/(.*) \(\d+-\d+\)/)
              name = m[1]
            end
          elsif /Status/.match?(tr.css("td")[0].text.strip)
            status = tr.css("td > table > tr > td")[1].text.gsub(/^\u00A0/, "").strip
          elsif /Geschlecht/.match?(tr.css("td")[0].text.strip)
            sex = CategoryCc::SEX_MAP_REVERSE[tr.css("td")[2].text.strip]
          elsif /Alter/.match?(tr.css("td")[0].text.strip)
            m = tr.css("td")[2].text.strip.match(/(\d+)\s*-\s*(\d+)/)
            min_age = m[1].to_i
            max_age = m[2].to_i
          end
        end
        category_cc.update(context: @opts[:context], branch_cc_id: branch_cc.id, name: name, sex: sex, min_age: min_age,
                           max_age: max_age, status: status)
        CategoryCc.last
      end
    end
  end

  def sync_group_ccs
    region = Region.find_by_shortname(@opts[:context].upcase)
    region_cc = region.region_cc
    region_cc.branch_ccs.each do |branch_cc|
      _, doc = @client.post("showGroupList", { branchId: branch_cc.cc_id }, @opts)
      options = doc.css("select[name=\"groupId\"] > option")
      options.each do |option|
        option_cc_id = option["value"].to_i
        name = option.text.strip
        status = ""
        display = ""
        pos_hash = {}
        group_cc = GroupCc.find_or_initialize_by(cc_id: option_cc_id)
        _, doc_cat = @client.post("showGroup", { branchId: branch_cc.cc_id, groupId: option_cc_id }, @opts)
        lines = doc_cat.css("tr.tableContent > td > table > tr")
        lines.each do |tr|
          if /Name/.match?(tr.css("td")[0].text.strip)
            name = tr.css("td")[2].text.strip
          elsif /Status/.match?(tr.css("td")[0].text.strip)
            status = tr.css("td")[2].text.strip
          elsif /Darstellung/.match?(tr.css("td")[0].text.strip)
            display = tr.css("td")[2].text.strip
          elsif /Runden|Gruppen/.match?(tr.css("td")[0].text.strip)
            positions = tr.css("td > table > tr")
            positions.each do |position|
              pos = position.css("td").andand[0].andand.text.andand.to_i
              val = position.css("td").andand[1].andand.text
              pos_hash[pos.to_i] = val if pos.present?
            end
          end
        end
        group_cc.update(context: @opts[:context], branch_cc_id: branch_cc.id, name: name, status: status,
                        display: display, data: { positions: pos_hash }.to_json)
      end
    end
  end

  def sync_discipline_ccs
    season = Season.find_by_name(@opts[:season_name])
    region = Region.find_by_shortname(@opts[:context].upcase)
    region_cc = region.region_cc
    region_cc.branch_ccs.each do |branch_cc|
      _, doc = @client.post("createMeldelisteCheck",
                       { branchId: branch_cc.cc_id, fedId: region_cc.cc_id, disciplinId: "*", catId: "*", season: season.name, create: "" }, @opts)
      options = doc.css("select[name=\"selectedDisciplinId\"] > option")
      options.each do |option|
        option_cc_id = option["value"].to_i
        @strip = option.text.strip
        name = @strip
        discipline_cc = DisciplineCc.find_or_initialize_by(cc_id: option_cc_id)
        discipline = Discipline.find_by_name(name.gsub("(großes Billard)", "groß").gsub("(kleines Billard)", "klein").gsub("5-Kegel", "5 Kegel").gsub("14/1 endlos", "14.1 endlos").gsub("15-reds", "Snooker").gsub(
                                               "Billard Kegeln", "Billard-Kegeln"
                                             ))
        discipline_cc.update(context: region.shortname.downcase, name: name, branch_cc_id: branch_cc.id,
                             discipline_id: discipline.andand.id)
      end
    end
  end
end
