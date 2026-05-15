# frozen_string_literal: true

# Syncer fuer Turnier-Daten aus dem ClubCloud-System.
# Extrahiert aus RegionCc: sync_tournaments, sync_tournament_ccs, sync_tournament_series_ccs,
# sync_championship_type_ccs und fix_tournament_structure.
#
# Hinweis: synchronize_tournament_structure verbleibt im RegionCc-Model (Multi-Syncer-Orchestrator).
#
# Verwendung:
#   RegionCc::TournamentSyncer.call(
#     region_cc: region_cc, client: client,
#     operation: :sync_tournaments, context: "nbv", season_name: "2023/2024"
#   )
class RegionCc::TournamentSyncer < ApplicationService
  def initialize(options = {})
    @region_cc = options.fetch(:region_cc)
    @client = options.fetch(:client)
    @operation = options.fetch(:operation)
    @opts = options.except(:region_cc, :client, :operation)
  end

  def call
    case @operation
    when :sync_tournaments then sync_tournaments
    when :sync_tournament_ccs then sync_tournament_ccs
    when :sync_tournament_series_ccs then sync_tournament_series_ccs
    when :sync_championship_type_ccs then sync_championship_type_ccs
    when :fix_tournament_structure then fix_tournament_structure
    else raise ArgumentError, "Unknown operation: #{@operation}"
    end
  end

  private

  def sync_tournaments
    region = Region.find_by_shortname(@opts[:context].upcase)
    season_name = @opts[:season_name]
    season = Season.find_by_name(season_name)
    raise ArgumentError, "unknown season name #{season_name}", caller if season.blank?

    tournaments = []
    region.region_cc.branch_ccs.each do |branch_cc|
      next if branch_cc.name == "Pool" || branch_cc.name == "Snooker" # TODO: remove restriction on branch

      # Turnierliste aus CC laden
      _, doc = @client.post("showMeisterschaftenList", {
                              fedId: region.cc_id,
                              branchId: branch_cc.cc_id,
                              disciplinId: "*",
                              catId: "*",
                              meisterTypeId: "*",
                              season: season.name,
                              t: 1
                            }, @opts)
      if (msg = doc.css('input[name="errMsg"]')[0].andand["value"]).present?
        RegionCc.logger.error msg
        return [[], msg]
      end
      options = doc.css("a.cc_bluelink")
      options.each do |option|
        next unless m = option["href"].match(/.*\?p=([^&]*)&/)

        cc_id = m[1].split("-")[6].to_i
        tournament_cc = TournamentCc.find_by(cc_id: cc_id)
        if tournament_cc.present?
          tournament = tournament_cc.tournament
          unless tournament.present?
            tournaments_tmp = Tournament.where(
              title: tournament_cc.name,
              season_id: season.id,
              discipline_id: tournament_cc.discipline_id
            )
            if tournaments_tmp.count != 1
              RegionCc.logger.error "Error: no unique matching Tournament for TournamentCc(#{cc_id})"
            else
              tournament = tournaments_tmp[0]
              tournament_cc.update(tournament_id: tournament.id)
            end
          end
          tournaments.push(tournament) if tournament.present?
        else
          RegionCc.logger.error "Error: TournamentCc[] not found - run synchronize_tournament_ccs first"
        end
      end
    end

    [tournaments, nil]
  rescue StandardError => e
    [[], e.to_s]
  end

  def sync_tournament_ccs
    region = Region.find_by_shortname(@opts[:context].upcase)
    season_name = @opts[:season_name]
    season = Season.find_by_name(season_name)
    raise ArgumentError, "unknown season name #{season_name}", caller if season.blank?

    region_cc = region.region_cc
    region_cc.branch_ccs.each do |branch_cc|
      next if branch_cc.name == "Pool" || branch_cc.name == "Snooker" # TODO: remove restriction on branch

      _, doc = @client.post("showMeisterschaftenList", {
                              fedId: region_cc.cc_id,
                              branchId: branch_cc.cc_id,
                              disciplinId: "*",
                              catId: "*",
                              meisterTypeId: "*",
                              season: season.name,
                              t: 1
                            }, @opts)
      if (msg = doc.css('input[name="errMsg"]')[0].andand["value"]).present?
        RegionCc.logger.error msg
        return [[], msg]
      end
      options = doc.css("a.cc_bluelink")
      options.each do |option|
        if m = option["href"].match(/.*\?p=([^&]*)&/)
          cc_id = m[1].split("-")[6].to_i
          args = {}
          pos_hash = {}
          tournament_cc = TournamentCc[cc_id]
          next if tournament_cc.present? && !@opts[:update_from_cc]

          tournament_cc = TournamentCc.find_or_initialize_by(cc_id: cc_id)
          _, doc_cat = @client.get("showMeisterschaft", { p: m[0] }, @opts)
          lines = doc_cat.css("tr.tableContent > td > table > tr")
          lines.each do |tr|
            if /Meldungen/.match?(tr.css("td")[0].text.strip)
              positions = tr.css("td > table > tr")
              positions.each do |position|
                pos = position.css("td").andand[0].andand.text.andand.to_i
                val = position.css("td").andand[1].andand.text
                pos_hash[pos.to_i] = val if pos.present?
              end
            elsif tr.css("td")[0].text.strip == "Meisterschaft"
              args.merge!(name: tr.css("td")[2].text.strip)
            elsif /Kurzbezeichner/.match?(tr.css("td")[0].text.strip)
              args.merge!(shortname: tr.css("td")[2].text.strip)
            elsif /Turnier-Serie/.match?(tr.css("td")[0].text.strip)
              unless /Keine Serien-Zuordnung vorhanden/.match?(tr.css("td")[2].text.gsub(/\u00A0/, "").strip)
                ts_name = tr.css("td")[2].text.gsub(/\u00A0/, "").strip
                tournament_series_cc = TournamentSeriesCc.where(name: ts_name, branch_cc_id: branch_cc.id,
                                                                season: season.name).first
                args.merge!(tournament_series_cc_id: tournament_series_cc.id)
              end
            elsif /Disziplin/.match?(tr.css("td")[0].text.strip)
              d_name = tr.css("td")[2].text.strip.gsub("(großes Billard)", "groß").gsub("(kleines Billard)", "klein")
              args.merge!(discipline_id: Discipline.find_by_name(d_name).andand.id)
            elsif /Melde-Regel/.match?(tr.css("td")[0].text.strip)
              args.merge!(registration_rule: TournamentCc::REGISTRATION_RULES_INV[tr.css("td")[2].text.strip])
            elsif /Sortierung nach/.match?(tr.css("td")[0].text.strip)
              # args.merge!(sorting_by: tr.css("td")[2].text.strip)
            elsif /Startgeld/.match?(tr.css("td")[0].text.strip)
              args.merge!(entry_fee: tr.css("td")[2].text.strip.tr(",", ".").to_f)
            elsif /Meisterschaftstyp/.match?(tr.css("td")[0].text.strip)
              name, shortname = tr.css("td")[2].text.strip.match(/\s*(.*)\s*\((.*)\)/)[1..2]
              name = name.gsub(/\u00A0/, "").strip
              shortname = shortname.gsub(/\u00A0/, "").strip
              championship_type_cc = ChampionshipTypeCc.where(name: name, shortname: shortname,
                                                              branch_cc_id: branch_cc.id).first
              args.merge!(championship_type_cc_id: championship_type_cc.andand.id)
            elsif /Meisterschaftsgruppe/.match?(tr.css("td")[0].text.strip)
              group_cc = GroupCc.where(name: tr.css("td")[2].text.strip, branch_cc_id: branch_cc.id).first
              args.merge!(group_cc_id: group_cc.andand.id)
            elsif /Kategorie/.match?(tr.css("td")[0].text.strip)
              k_name = tr.css("td")[2].text.strip
              if m = k_name.match(/(.*) \(\d+-\d+\)/)
                args.merge!(category_cc_id: CategoryCc.where(context: @opts[:context], branch_cc_id: branch_cc.id,
                                                             name: m[1]).first.andand.id)
              end
            elsif /Datum/.match?(tr.css("td")[0].text.strip)
              args[:tournament_start] = tr.css("td")[2].text.strip
              if m = args[:tournament_start].match(/(\d+\.\d+\.\d+).*\u00A0\(Spielbeginn am \d+\.\d+\.\d+ um (\d+:\d+) Uhr\)/)
                args.merge!(tournament_start: DateTime.parse("#{m[1]} #{m[2]}"))
              end
            elsif /Location/.match?(tr.css("td")[0].text.strip)
              args.merge!(location_text: tr.css("td")[2].inner_html.strip)
            elsif /Status/.match?(tr.css("td")[0].text.strip)
              args.merge!(status: tr.css("td")[2].text.strip.gsub(/^\u00A0/, "").strip)
            end
          end
          if args[:name].present?
            # Plan 14-G.7 / Task 3 / F11: season.name kann nil sein wenn `season` AR-Objekt
            # ohne persistierten name geliefert wird. Fallback aus tournament_start ableiten,
            # um null-Records im Mirror zu vermeiden (Read-Side-Default-Season-Filter blind).
            season_name = season&.name
            if season_name.blank? && args[:tournament_start].present?
              derived = Season.season_from_date(args[:tournament_start].to_date)
              season_name = derived&.name
            end
            tournament_cc.update(args.merge(cc_id: cc_id, season: season_name, branch_cc_id: branch_cc.id))
            tournament_cc.attributes
          end
        end
      rescue StandardError => e
        Rails.logger.error "Errror: #{e} #{e.backtrace.join("\n")}"
      end
    end
  end

  def sync_tournament_series_ccs
    region = Region.find_by_shortname(@opts[:context].upcase)
    season = Season.find_by_name(@opts[:season_name])
    region_cc = region.region_cc
    region_cc.branch_ccs.each do |branch_cc|
      _, doc = @client.post("showSerienList", { fedId: @region_cc.cc_id, branchId: branch_cc.cc_id, season: @opts[:season_name] }, @opts)
      options = doc.css("select[name=\"serienId\"] > option")
      options.each do |option|
        cc_id = option["value"].to_i
        args = { season: season.name, branch_cc_id: branch_cc.id }
        pos_hash = {}
        tournament_series_cc = TournamentSeriesCc.find_or_initialize_by(cc_id: cc_id)

        _, doc_cat = @client.post("showSerie",
                                  { fedId: region_cc.cc_id, branchId: branch_cc.cc_id, season: @opts[:season_name], serienId: cc_id, show: "", referer: "/admin/einzel/serie/showSerienList.php?branchId=#{branch_cc.cc_id}&fedId=#{cc_id}&season=#{@opts[:season_name]}" }, @opts.merge)
        lines = doc_cat.css("tr.tableContent > td > table > tr")
        lines.each do |tr|
          if /Status/.match?(tr.css("td")[0].text.strip)
            args.merge!(status: tr.css("td")[2].text.strip.gsub(/^\u00A0/, "").strip)
          elsif /Turnier-Serie/.match?(tr.css("td")[0].text.strip)
            args.merge!(name: tr.css("td")[2].text.strip)
          elsif /Serienwertung/.match?(tr.css("td")[0].text.strip)
            args.merge!(series_valuation: tr.css("td")[2].text.strip.to_i)
          elsif /Turniere anzeigen/.match?(tr.css("td")[0].text.strip)
            args.merge!(no_tournaments: tr.css("td")[2].text.strip.to_i)
          elsif /Punkte-Formel/.match?(tr.css("td")[0].text.strip)
            args.merge!(point_formula: tr.css("td")[2].text.strip.match(/([^(]*)\(.*/).andand[1].andand.gsub(/\u00A0/,
                                                                                                             " ").andand.strip.to_s)
          elsif /Minimal-Punktzahl/.match?(tr.css("td")[0].text.strip)
            args.merge!(min_points: tr.css("td")[2].text.strip.to_i)
          elsif /Rundung Punktzahl/.match?(tr.css("td")[0].text.strip)
            args.merge!(point_fraction: tr.css("td")[2].text.strip.to_i)
          elsif /Verein/.match?(tr.css("td")[0].text.strip)
            if m = tr.css("td")[2].text.strip.match(/.*\((\d+)\).*/)
              club_cc_id = m[1].to_i
              args.merge!(club_id: Club.find_by_cc_id(club_cc_id))
            end
          elsif /Jackpot \(manuell\)/.match?(tr.css("td")[0].text.strip)
            if m = tr.css("td")[2].text.strip.match(/(\d+,\d+).*/)
              args.merge!(point_fraction: m[1].tr(",", ".").to_f)
            end
          elsif /Mannschaften/.match?(tr.css("td")[0].text.strip)
            zeilen = tr.css("table > tr.odd td")
            zeilen.each do |zeile|
              pos = zeile.css("td").andand[0].andand.text.andand.to_i
              val = zeile.css("td").andand[1].andand.text
              pos_hash[pos] = val if pos.present?
            end
          end
        end
        tournament_series_cc.update(args)
      end
    end
  end

  def sync_championship_type_ccs
    region = Region.find_by_shortname(@opts[:context].upcase)
    region_cc = region.region_cc
    region_cc.branch_ccs.each do |branch_cc|
      _, doc = @client.post("showTypeList", { fedId: @region_cc.cc_id, branchId: branch_cc.cc_id }, @opts)
      options = doc.css("select[name=\"typeId\"] > option")
      options.each do |option|
        cc_id = option["value"].to_i
        name = option.text.strip
        shortname = ""
        status = ""
        championship_type_cc = ChampionshipTypeCc.find_or_initialize_by(cc_id: cc_id)
        _, doc_cat = @client.post("showType", { fedId: @region_cc.cc_id, branchId: branch_cc.cc_id, typeId: cc_id }, @opts)
        lines = doc_cat.css("tr.tableContent > td > table > tr")
        lines.each do |tr|
          if /Meisterschaftstyp/.match?(tr.css("td")[0].text.strip)
            name = tr.css("td")[2].text.strip
          elsif /Status/.match?(tr.css("td")[0].text.strip)
            status = tr.css("td > table > tr > td")[1].text.gsub(/\u00A0/, "").strip
          elsif /Kurzbezeichnung/.match?(tr.css("td")[0].text.strip)
            shortname = tr.css("td")[2].text.strip
          end
        end
        championship_type_cc.update(context: @opts[:context], branch_cc_id: branch_cc.id, name: name,
                                    shortname: shortname, status: status)
        ChampionshipTypeCc.last
      end
    end
  end

  def fix_tournament_structure
    season = Season.find_by_name(@opts[:season_name])
    raise ArgumentError, "unknown season name #{@opts[:season_name]}", caller if season.blank?

    tournaments = Tournament
                  .where(season: season, organizer_type: "Region", organizer_id: @region_cc.region.id)
                  .where.not(tournaments: { ba_id: @opts[:exclude_tournament_ba_ids] }).to_a
    tournaments.each do |tournament|
      next if tournament.discipline.root.name == "Pool" || tournament.discipline.root.name == "Snooker"

      tournament_cc = TournamentCc.find_by(tournament_id: tournament.id)
      if tournament_cc.present?
        branch_cc = tournament.discipline.root.branch_cc
        registration_list_ccs = RegistrationListCc.where(
          name: tournament.title,
          context: @region_cc.region.shortname.downcase,
          discipline_id: tournament.discipline_id,
          season_id: tournament.season_id
        )
        registration_list_cc = nil
        if registration_list_ccs.count == 1
          registration_list_cc = registration_list_ccs.first
        elsif registration_list_ccs.count > 1
          Rails.logger.info "Error: Ambiguity Problem"
        else
          Rails.logger.info "Error: No RegistrationList for Tournament"
        end
        type_found = nil
        begin
          TournamentCc::TYPE_MAP_REV[branch_cc.cc_id].keys.each do |type_name|
            if /#{type_name}/.match?(tournament.title)
              type_found = TournamentCc::TYPE_MAP_REV[branch_cc.cc_id][type_name]
              break
            end
          end
        rescue StandardError => e
          Rails.logger.error "Error: #{e} Tournament[#{tournament.id}]"
          return
        end
        args = {
          fedId: @region_cc.cc_id,
          branchId: branch_cc.cc_id,
          disciplinId: "*",
          season: @opts[:season_name],
          catId: "*",
          meisterTypeId: "*",
          meisterschaftsId: tournament_cc.cc_id,
          ebut: ""
        }
        _, doc = @client.post("editMeisterschaftCheck", args, @opts)
        args = {
          fedId: @region_cc.cc_id,
          branchId: branch_cc.cc_id,
          disciplinId: tournament.discipline.discipline_cc.cc_id,
          season: @opts[:season_name],
          catId: "*",
          meisterschaftsId: tournament_cc.cc_id,
          firstEntry: 1,
          meisterName: tournament.title,
          meisterShortName: tournament.shortname.presence || tournament.title,
          meldeListId: registration_list_cc.cc_id,
          mr: 1,
          meisterTypeId: type_found.to_s,
          groupId: 10, # NBV History is good for all
          playDate: tournament.date.strftime("%Y-%m-%d"),
          playDateTo: tournament.end_date.andand.strftime("%Y-%m-%d"),
          startTime: tournament.date.strftime("%H:%M"),
          quote: "0",
          sg: "0,00",
          maxtn: "0",
          countryId: "free",
          pubName: doc.css('input[name="pubName"]')[0].attributes["value"].to_s,
          pubStreet: doc.css('input[name="pubStreet"]')[0].attributes["value"].to_s,
          pubZipcode: doc.css('input[name="pubZipcode"]')[0].attributes["value"].to_s,
          pubCity: doc.css('input[name="pubCity"]')[0].attributes["value"].to_s,
          pubPhone: doc.css('input[name="pubPhone"]')[0].attributes["value"].to_s,
          besch: "",
          attachment4: "",
          attachment5: "",
          attachment1: "",
          attachment2: "",
          attachment3: "",
          referer: "/admin/einzel/meisterschaft/editMeisterschaftCheck.php?",
          save: ""
        }
        _, doc = @client.post("editMeisterschaftSave", args, @opts)
        doc
      else
        Rails.logger.error "Error: Problem in tournament_structure - Tournament[#{tournament.id}]"
      end
    end
  end
end
