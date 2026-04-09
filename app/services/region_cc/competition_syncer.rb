# frozen_string_literal: true

# Syncer fuer Wettbewerbs- und Saison-Daten aus dem ClubCloud-System.
# Extrahiert aus RegionCc: sync_competitions und sync_seasons_in_competitions.
#
# Verwendung:
#   RegionCc::CompetitionSyncer.call(
#     region_cc: region_cc, client: client,
#     operation: :sync_competitions, context: "nbv"
#   )
class RegionCc::CompetitionSyncer < ApplicationService
  def initialize(options = {})
    @region_cc = options.fetch(:region_cc)
    @client = options.fetch(:client)
    @operation = options.fetch(:operation)
    @opts = options.except(:region_cc, :client, :operation)
  end

  def call
    case @operation
    when :sync_competitions then sync_competitions
    when :sync_seasons_in_competitions then sync_seasons_in_competitions
    else raise ArgumentError, "Unknown operation: #{@operation}"
    end
  end

  private

  def sync_competitions
    competitions = []
    context = @opts[:context]
    # fuer alle Disziplin-Zweige
    BranchCc.where(context: context).each do |branch_cc|
      _, doc = @client.post("showLeagueList", { fedId: @region_cc.cc_id, branchId: branch_cc.cc_id }, @opts)
      selector = doc.css('select[name="subBranchId"]')[0]
      unless selector.present?
        RegionCc.logger.error "[sync_competitions] No subBranchId select found in response"
        next
      end
      option_tags = selector.css("option")
      option_tags.each do |option|
        cc_id = option["value"].to_i
        name_str = option.text.strip
        match = name_str.match(/(.*)(:? \((.*)\))?/)
        name = match[1]
        carambus_name = name == "Mannschaft" ? "#{name} #{branch_cc.name}" : "Mannschaft #{name}"
        carambus_name = carambus_name.gsub("Großes Billard", "Karambol großes Billard")
        carambus_name = carambus_name.gsub("Kleines Billard", "Karambol kleines Billard")
        competition = Competition.find_by_name(carambus_name)
        if competition.blank?
          msg = "No Competition with name #{carambus_name} in database"
          RegionCc.logger.error "[sync_competitions] #{msg}"
          raise ArgumentError, msg, caller
        else
          args = { cc_id: cc_id, branch_cc_id: branch_cc.id, discipline_id: competition.id, context: context,
                   name: name }
          competition_cc = CompetitionCc.where(cc_id: cc_id,
                                               branch_cc_id: branch_cc.id).first || CompetitionCc.new(args)
          competition_cc.assign_attributes(args)
          competition_cc.save
          competitions.push(competition)
        end
      end
    end

    competitions
  end

  def sync_seasons_in_competitions
    context = @region_cc.shortname.downcase
    season = Season.find_by_name(@opts[:season_name])
    raise ArgumentError, "unknown season name #{@opts[:season_name]}", caller if season.blank?

    competition_ccs = []
    # fuer alle Disziplin-Zweige
    BranchCc.where(context: context).each do |branch_cc|
      branch_cc.competition_ccs.each do |competition_cc|
        _, doc = @client.post(
          "showLeagueList",
          { fedId: @region_cc.cc_id,
            branchId: branch_cc.cc_id,
            subBranchId: competition_cc.cc_id },
          @opts
        )
        selector = doc.css('select[name="seasonId"]')[0]
        option_tags = selector.css("option")
        option_tags.each do |option|
          cc_id = option["value"].to_i
          name_str = option.text.strip
          match = name_str.match(%r{\s*(.*/.*)\s*})
          s_name = match[1]
          next unless s_name == @opts[:season_name]

          args = { cc_id: cc_id, context: context, name: s_name, season_id: season.id,
                   competition_cc_id: competition_cc.id }
          season_cc = SeasonCc.find_by_cc_id_and_competition_cc_id_and_context(cc_id, competition_cc.id,
                                                                               context) || SeasonCc.new(args)
          season_cc.assign_attributes(args)
          season_cc.save
          competition_ccs.push(competition_cc)
          break
        end
      end
    end

    competition_ccs
  end
end
