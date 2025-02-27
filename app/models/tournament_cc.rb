# frozen_string_literal: true

# == Schema Information
#
# Table name: tournament_ccs
#
#  id                        :bigint           not null, primary key
#  branch_cc_name            :string
#  category_cc_name          :string
#  championship_type_cc_name :string
#  context                   :string
#  description               :text
#  entry_fee                 :decimal(6, 2)
#  flowchart                 :string
#  league_climber_quote      :integer
#  location_text             :string
#  max_players               :integer
#  name                      :string
#  poster                    :string
#  ranking_list              :string
#  registration_rule         :integer
#  season                    :string
#  shortname                 :string
#  starting_at               :time
#  status                    :string
#  successor_list            :string
#  tender                    :string
#  tournament_end            :datetime
#  tournament_start          :datetime
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  branch_cc_id              :integer
#  category_cc_id            :integer
#  cc_id                     :integer
#  championship_type_cc_id   :integer
#  discipline_id             :integer
#  group_cc_id               :integer
#  location_id               :integer
#  registration_list_cc_id   :integer
#  tournament_id             :integer
#  tournament_series_cc_id   :integer
#
# Indexes
#
#  index_tournament_ccs_on_cc_id_and_context  (cc_id,context) UNIQUE
#  index_tournament_ccs_on_tournament_id      (tournament_id) UNIQUE
#
class TournamentCc < ApplicationRecord
  include LocalProtector
  belongs_to :branch_cc, optional: true
  belongs_to :location, optional: true
  belongs_to :registration_list_cc, optional: true
  belongs_to :discipline, optional: true
  belongs_to :group_cc, optional: true
  belongs_to :championship_type_cc, optional: true
  belongs_to :category_cc, optional: true
  belongs_to :tournament_series_cc, optional: true
  belongs_to :tournament, optional: true

  COLUMN_NAMES = { # TODO: FILTERS
    "CC_ID" => "tournament_ccs.cc_id",
    "Name" => "tournament_ccs.name",
    "Shortname" => "tournament_ccs.shortname",
    "Discipline" => "disciplines.name",
    "Context" => "tournament_ccs.context",
    "SingleOrLeague" => "tournament_ccs.single_or_league",
    "Season" => "tournament_ccs.season",
    "BranchCc" => "branch_ccs.name",
    "Type" => "championship_type_ccs.name",
    "CategoryCc" => "category_ccs.name",
    "GroupCc" => "group_ccs.name"
  }

  REGISTRATION_RULES = {
    1 => "Standard (nur Aktive dürfen gemeldet werden)",
    2 => "Flexibel (Aktive und Passive dürfen gemeldet werden (Teilnehmer-Liste))",
    3 => "Meine Club Cloud (Meldung durch Spieler möglich / Extra-Meldeliste)"
  }.freeze
  REGISTRATION_RULES_INV = REGISTRATION_RULES.invert.merge({ "Jackpot ist auf Startseite ausgeblendet" => 1,
                                                             "Jackpot wird auf Startseite angezeigt" => 2 })

  JACKPOT_DISPLAY = {
    1 => "Nein, Jackpot auf Startseite AUSBLENDEN",
    2 => "Ja, Jackpot auf Startseite DARSTELLEN"
  }.freeze
  JACKPOT_DISPLAY_INV = JACKPOT_DISPLAY.invert

  TYPE_MAP = {
    6 => { # Pool
      1 => ["Norddeutsche Meisterschaft", "NDM"],
      2 => %w[Bezirksmeisterschaft BM]
    },
    7 => { # Snooker
      6 => ["Norddeutsche Meisterschaft", "NDM"]
    },
    8 => { # Kegel
      7 => ["Norddeutsche Meisterschaft", "NDM"]
    },
    10 => { # Karambol
      5 => ["Norddeutsche Meisterschaft", "NDM"],
      8 => %w[Vorgabepokal VP],
      9 => ["Petit Prix", "PP"],
      10 => ["Grand Prix", "GP"],
      11 => %w[NordCup NC],
      12 => %w[Bezirksmeisterschaft BM]
    }
  }.freeze

  TYPE_MAP_REV = {
    6 => { # Pool
      "Norddeutsche Meisterschaft" => 1,
      "NDM" => 1,
      "Bezirksmeisterschaft" => 2,
      "BM" => 2,
      "BKMR" => 2
    },
    7 => { # Snooker
      "Norddeutsche Meisterschaft" => 6,
      "NDM" => 6
    },
    8 => { # Kegel
      "Norddeutsche Meisterschaft" => 7,
      "NDM" => 7
    },
    10 => { # Karambol
      "Norddeutsche Meisterschaft" => 5,
      "NDM" => 5,
      "Vorgabepokal" => 8,
      "VP" => 8,
      "Petit Prix" => 9,
      "PP" => 9,
      "Grand Prix" => 10,
      "Grand-Prix" => 10,
      "GP" => 10,
      "NordCup" => 11,
      "NC" => 11,
      "Bezirksmeisterschaft" => 12,
      "BM" => 12,
      "BKMR" => 12
    }
  }.freeze

  def self.create_from_ba(tournament, opts)
    region = tournament.organizer
    region_cc = region.region_cc
    registration_list_ccs = RegistrationListCc.where(
      name: tournament.title,
      context: region.shortname.downcase,
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
    branch_cc = tournament.discipline.root.branch_cc
    begin
      TYPE_MAP_REV[branch_cc.cc_id].keys.each do |type_name|
        if /#{type_name}/.match?(tournament.title)
          type_found = TYPE_MAP_REV[branch_cc.cc_id][type_name]
          break
        end
      end
    rescue Exception => e
      Rails.logger.error "Error: #{e} Tournament[#{tournament.id}]"
      return
    end
    tournament_cc = TournamentCc.where(name: tournament.title, discipline_id: tournament.discipline_id,
                                       branch_cc_id: branch_cc.id, season: opts[:season_name]).first
    begin
      args = {
        fedId: region.cc_id,
        branchId: branch_cc.cc_id,
        season: opts[:season_name],
        meisterName: tournament.title,
        meisterShortName: tournament.shortname.presence || "NDM",
        meldeListId: registration_list_cc&.cc_id,
        mr: 1,
        meisterTypeId: type_found.to_s,
        groupId: 10,
        playDate: tournament.date.strftime("%Y-%m-%d"),
        playDateTo: tournament.end_date.andand.strftime("%Y-%m-%d"),
        startTime: tournament.date.strftime("%H:%M"),
        quote: "",
        sg: "",
        maxtn: "",
        countryId: "free",
        pubName: "",
        save: ""
      }
    rescue Exception => e
      Rails.logger.error "Error: #{e} Tournament[#{tournament.id}]"
      return
    end
    region_cc.post_cc("createMeisterschaftSave", args, opts)
    tournament_cc.update(tournament_id: tournament.id) if tournament_cc.present?
  end

  #noinspection RubyLocalVariableNamingConvention
  def delete_tournament_results(opts)
    region = tournament.organizer
    tournament_cc = TournamentCc.find_by_tournament_id(tournament.id)
    branch_cc = tournament_cc.branch_cc
    args = {
      fedId: region.cc_id,
      branchId: branch_cc.cc_id,
      season: tournament.season.name,
      disciplinId: tournament.discipline.discipline_cc.cc_id,
      catId: "*",
      meisterTypeId: "*",
      meisterschaftsId: tournament_cc.cc_id,
      teilnehmerId: "*"
    }
    _, doc = region.region_cc.post_cc_with_formdata("showErgebnisliste", args, opts)

    doc.css(".cc_bluelink").each do |line|
      partieId = line["href"].match(/.*partieId=(\d+).*/).andand[1].to_i
      region.region_cc.post_cc_with_formdata("deleteErgebnis", args.merge(partieId: partieId), opts)
    end
  end

  def upload_csv(opts)
    # GRUPPE/RUNDE;PARTIE;SATZ-NR.;PASS-NR. SPIELER 1;PASS-NR. SPIELER 2;PUNKTE SPIELER 1;PUNKTE SPIELER 2;AUFNAHMEN SPIELER 1;AUFNAHMEN SPIELER 2;HÖCHSTSERIE SPIELER 1;HÖCHSTSERIE SPIELER 2
    game_data = []
    game_scope = tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").count > 0 ? "games.id >= #{Game::MIN_ID}" : "games.id < #{Game::MIN_ID}"
    tournament.games.where(game_scope).each do |game|
      game.gname = game.gname.presence || "Gruppe 1"
      if (m = game.gname.match(/^G(\d)-/))
        game.gname = "Gruppe #{m[1]}"
      end
      game.gname = "Gruppe 1" if /.*Runde/.match?(game.gname)
      gruppe = GroupCc::NAME_MAPPING[:groups]["#{/^group/.match?(game.gname) ? "Gruppe" : game.gname}#{if game.group_no.present?
                                                                                                         " #{game.group_no}"
                                                                                                       end}"] ||
               GroupCc::NAME_MAPPING[:round]["#{/^group/.match?(game.gname) ? "Gruppe" : game.gname}#{if game.group_no.present?
                                                                                                        " #{game.group_no}"
                                                                                                      end}"]
      begin
        gruppe = gruppe.gsub("Runde", "Gruppe").gsub("Hauptrunde", "Gruppe 1")
      rescue Exception
        Rails.logger.error "Error: Unknown group name Tournament[#{tournament.id}]"
        return
      end
      partie = game.seqno
      gp1 = game.game_participations.where(role: %w[playera Heim]).first
      gp2 = game.game_participations.where(role: %w[playerb Gast]).first

      line = begin
        "#{gruppe};#{partie};;#{gp1&.player&.cc_id};#{gp2&.player&.cc_id};#{gp1&.result};#{gp2&.result};#{gp1&.innings};#{gp2&.innings};#{gp1&.hs};#{gp2&.hs}"
      rescue StandardError
        nil
      end
      game_data << line if line.present?
    end

    region = tournament.organizer
    tournament_cc = TournamentCc.find_by_tournament_id(tournament.id)
    branch_cc = tournament_cc.branch_cc
    args = {
      fedId: region.cc_id,
      branchId: branch_cc.cc_id,
      season: tournament.season.name,
      disciplinId: "*",
      catId: "*",
      meisterTypeId: "*",
      meisterschaftsId: tournament_cc.cc_id
    }
    seeding_scope = tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").count > 0 ? "seedings.id >= #{Seeding::MIN_ID}" : "seedings.id < #{Seeding::MIN_ID}"
    begin
      ranking_data = tournament.seedings.where(seeding_scope).select do |seeding|
                       seeding.data["result"].andand["Gesamtrangliste"].present?
                     end.sort_by { |seeding| seeding.data["result"]["Gesamtrangliste"]["Rank"].to_i }.map do |s|
        [
          s.data["result"]["Gesamtrangliste"]["#"].to_i, s.data["result"]["Gesamtrangliste"]["Punkte"].to_i, "", s.player.cc_id, "", ""
        ].join(";")
      end
    rescue Exception
      Rails.logger.error "Error: One ore more Players not assignable Tournament[#{tournament.id}]"
      return
    end

    f = File.new("#{Rails.root}/tmp/ranking#{tournament_cc.cc_id}.csv", "w")
    f.write(ranking_data.join("\n"))
    f.close
    _, doc0a = region.region_cc.post_cc_with_formdata("importRangliste2",
                                                      args.merge(importBut: "", ranglistenimport: UploadIO.new("#{Rails.root}/tmp/ranking#{tournament_cc.cc_id}.csv", "text/csv", "ranking#{tournament_cc.cc_id}.csv")), opts)
    _, doc0b = region.region_cc.post_cc_with_formdata("showRangliste", args, opts)

    f = File.new("#{Rails.root}/tmp/result#{tournament_cc.cc_id}.csv", "w")
    f.write(game_data.join("\n"))
    f.close
    _, doc2 = region.region_cc.post_cc_with_formdata("importErgebnisseStep2",
                                                     args.merge(disciplinId: tournament.discipline.discipline_cc.cc_id, saveBut: "", importFile: UploadIO.new("#{Rails.root}/tmp/result#{tournament_cc.cc_id}.csv", "text/csv", "result#{tournament_cc.cc_id}.csv")), opts)
    _, doc3 = region.region_cc.post_cc("importErgebnisseStep3", args.merge(saveBut: ""), opts)

    [doc0a, doc0b, doc2, doc3]
  end
end
