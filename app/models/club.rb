# frozen_string_literal: true

# == Schema Information
#
# Table name: clubs
#
#  id         :bigint           not null, primary key
#  address    :text
#  dbu_entry  :string
#  dbu_nr     :integer
#  email      :string
#  founded    :string
#  homepage   :string
#  logo       :string
#  name       :string
#  priceinfo  :text
#  shortname  :string
#  source_url :string
#  status     :string
#  sync_date  :datetime
#  synonyms   :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  ba_id      :integer
#  cc_id      :integer
#  region_id  :integer
#
# Indexes
#
#  index_clubs_on_ba_id         (ba_id) UNIQUE
#  index_clubs_on_foreign_keys  (ba_id) UNIQUE
#
class Club < ApplicationRecord
  include LocalProtector
  include SourceHandler
  include RegionTaggable
  belongs_to :region
  # has_many :players, -> { where(type: nil) }
  has_many :season_participations, dependent: :destroy
  has_many :players, through: :season_participations
  has_many :club_locations, dependent: :destroy
  has_many :locations, through: :club_locations
  has_many :organized_tournaments, as: :organizer, class_name: "Tournament", dependent: :destroy
  has_many :league_teams
  has_many :admins, -> { where(role: :club_admin) }, class_name: 'User'

  attr_accessor :season_id

  before_save :update_synonyms

  REFLECTION_KEYS = %w[region season_participations].freeze

  COLUMN_NAMES = { "ID" => "clubs.id",
                   "BA_ID" => "clubs.ba_id",
                   "CC_ID" => "clubs.cc_id",
                   "Region" => "regions.shortname",
                   "Name" => "clubs.name",
                   "Shortname" => "clubs.shortname",
                   "Address" => "clubs.address",
                   "Homepage" => "",
                   "Status" => "",
                   "Founded" => "",
                   "Dbu entry" => "" }.freeze
  def self.search_hash(params)
    {
      model: Club,
      sort: params[:sort],
      direction: sort_direction(params[:direction]),
      search: "#{[params[:sSearch], params[:search]].compact.join("&")}",
      column_names: Club::COLUMN_NAMES,
      raw_sql: "(regions.shortname ilike :search)
 or (clubs.name ilike :search)
 or (clubs.address ilike :search)
 or (clubs.shortname ilike :search)
 or (clubs.email ilike :search)
 or (clubs.cc_id = :isearch)",
      joins: :region
    }
  end

  def update_synonyms
    self.shortname ||= name
    return unless shortname.present? && name.present?

    self.synonyms = (synonyms.to_s.split("\n").map(&:strip) +
      [name.strip.gsub("1.", "1. ").gsub("1.  ", "1. "),
       shortname.strip.gsub("1.", "1. ").gsub("1.  ", "1. ")]).uniq.join("\n")
  end

  def location
    locations.first
  end

  BA_COLUMNS = %i[
    address
    dbu_entry
    email
    founded
    homepage
    logo
    name
    priceinfo
    shortname
    status
    ba_id
  ].freeze
  CA_COLUMNS = %i[
    region_id
    id
    created_at
    updated_at
  ].freeze

  def self.scrape_clubs(season, opts = {})
    (Region::SHORTNAMES_CARAMBUS_USERS + Region::SHORTNAMES_OTHERS #+ ["BBV"]
    ).each do |shortname|
      Region.find_by_shortname(shortname).scrape_clubs(season, opts)
    end

    # fix title
    Player.where(type: nil).where("title ~ 'Herr.'").all.each { |p| p.update(title: "Herr") }
    Player.where(type: nil).where("title ~ 'Frau.'").all.each { |p| p.update(title: "Frau") }
  end

  def scrape_club(season, ref = nil, url = nil, opts = {})
    region_ = region
    if ref.blank?
      region_ = Region.find_by_shortname("DBU") if %w[BBV HBU].include?(region_.shortname)
      url ||= region_.public_cc_url_base
      clubs_url = "#{url}verein-details.php?eps=100000"
      uri = URI(clubs_url)
      html_clubs = Net::HTTP.get(uri)
      doc_clubs = Nokogiri::HTML(html_clubs)
      club_table = doc_clubs.css("article table.silver")[1]
      clubs = club_table.css("a")
      found = false
      clubs.each do |club_a|
        ref = club_a.attributes["href"].value
        next unless synonyms.split("\n").include?(club_a.text.strip)

        params = ref.split("p=")[1].split("|")
        self.cc_id = params[3].to_i
        found = true
        break
      end
      unless found
        msg = "===== scrape ===== ERROR Scraping Club #{name}[#{id}] failed - Naming problem?"
        Rails.logger.info msg
        return msg
      end
    end
    Rails.logger.info "===== scrape ===== Scraping #{url.to_s + ref.to_s}"
    uri = URI(url.to_s + ref.to_s)
    html_club = Net::HTTP.get(uri)
    doc_club = Nokogiri::HTML(html_club)
    doc_club.css("aside table.silver tr").each do |line|
      key = line.css("td:nth-child(1)").text.strip
      case key
      when "Postanschrift"
        self.address = line.css("td:nth-child(2)").inner_html
      when /verband/i
        if line.css("td:nth-child(3) img")[0].andand.attributes.andand["src"].present?
          self.logo = url + line.css("td:nth-child(3) img")[0].andand.attributes.andand["src"].to_s.split("?")[0]
        end
      when "Verein"
        self.name = line.css("td:nth-child(2)").text.strip
      when "DBU-Nr."
        self.dbu_nr = line.css("td:nth-child(2)").text.strip.to_i
      when "E-Mail"
        self.email = line.css("td:nth-child(2)").text.strip if line.css("td:nth-child(2)").text.strip.present?
      when "Webseite"
        self.homepage = line.css("td:nth-child(2)").text.strip if line.css("td:nth-child(2)").inner_html.present?
      when "Gründungsjahr"
        self.founded = line.css("td:nth-child(2)").text.strip if line.css("td:nth-child(2)").text.present?
      when "DBU Eintritt"
        self.dbu_entry = line.css("td:nth-child(2)").text.strip if line.css("td:nth-child(2)").text.strip.present?
      when "Mitgliedsbeitrag"
        self.priceinfo = line.css("td:nth-child(2)").inner_html if line.css("td:nth-child(2)").inner_html.present?
      else
        next
      end
    end
    save!
    Rails.logger.info "===== scrape ===== Scraping Club #{name}[#{id}]"
    # scrape players
    return unless opts[:player_details].present?

    player_ids_ok = []
    player_ids = season_participations.where(season: season).map(&:player_id)
    players_url = (url.to_s + ref.to_s).gsub("details", "mitglieder")
    u, p = players_url.split("p=")
    params = p.split("|")
    params[2] = season&.name
    params[8] = params[7]
    params[7] = params[6]
    params[6] = params[5]
    params[5] = ""
    players_url = "#{u}p=#{params.join("|")}"
    uri = URI(players_url)
    html_players = Net::HTTP.get(uri)
    doc_players = Nokogiri::HTML(html_players)
    if doc_players.present? && doc_players.css("aside table.silver")[1].present?
      player_urls = doc_players.css("aside table.silver")[1].css("a.cc_bluelink")
      player_urls.each do |pl_url_cc|
        purl = pl_url_cc["href"]
        name_ = pl_url_cc.text.strip
        purl_params = purl.split("p=")[1].split("|")
        cc_id = purl_params[5].to_i
        player_url = url + purl
        uri = URI(player_url)
        html_url = Net::HTTP.get(uri)
        doc_purl = Nokogiri::HTML(html_url)
        dbu_nr = nil
        full_name = doc_purl.css("article section table tr.even a.cc_bluelink")[0].text
        lastname, firstname = full_name.split(",").map(&:strip)
        doc_purl.css("aside table tr").each do |tr|
          if tr.css("td")[0].text.strip == "DBU-Nr." # && opts[:called_from_portal]
            dbu_nr = tr.css("td")[1].text.strip.to_i
          end
        end
        player = if opts[:called_from_portal]
                   players = Player.where(fl_name: name_, type: nil)
                   p = if players.count > 1
                         Rails.logger.info "===== scrape ===== ERROR cannot associate player - ambiguous: '#{name_}'"
                         nil
                       elsif players.count == 1
                         players.first
                       end
                   if p.blank?
                     p = Player.new(firstname: firstname, lastname: lastname, fl_name: name_, dbu_nr: dbu_nr,
                                    cc_id: cc_id)
                   end
                   p
                 else
                   p1 = Player.where(firstname: firstname, lastname: lastname, fl_name: name_, type: nil,
                                     ba_id: dbu_nr).first
                   p1 ||= Player.where(firstname: firstname, lastname: lastname, fl_name: name_, type: nil,
                                       dbu_nr: dbu_nr).first
                   p1 ||= Player.joins(season_participations: %i[club season])
                                .where(fl_name: name_, type: nil)
                                .where(seasons: { id: season.id })
                                .where(players: { cc_id: cc_id }, clubs: { id: id }).first
                   if p1.blank?
                     p1 = Player.where(type: nil).where(firstname: firstname, lastname: lastname, fl_name: name_,
                                                        cc_id: cc_id).first
                     if p1.blank?
                       p1 = Player.new(firstname: firstname, lastname: lastname, fl_name: name_, dbu_nr: dbu_nr,
                                       cc_id: cc_id)
                     else
                       p1
                     end
                   end
                   p1
                 end
        if player.present?

          if player.new_record?
            name_parts = name_.split(" ")
            player.firstname = name_parts[0]
            player.lastname = name_parts[1..].join(" ")
            Rails.logger.info "===== scrape ===== New Player #{player.firstname} #{player.lastname}"
          end
          player.cc_id = cc_id unless opts[:called_from_portal]
          player.dbu_nr = dbu_nr
          player.source_url = player_url
          player.save
          player_ids.delete(player.id)
          player_ids_ok << player.id
          sp = SeasonParticipation.where(season: season, player: player, club: self).first
          sp = SeasonParticipation.new(season: season, player: player, club: self) if sp.blank?
          sp.status = "active"
          sp.source_url = player_url
          sp.save
        else
          Rails.logger.info "===== scrape ===== ERROR with Player #{name_}"
        end
      end
      season_participations.where("status is null or status = 'active'").where(season: season,
                                                                               player_id: player_ids).destroy_all
      if opts[:fix_club_id].present?
        SeasonParticipation.where("status is null or status = 'active'").where(club: opts[:fix_club_id],
                                                                               player_id: player_ids_ok).each do |sp|
          if SeasonParticipation.where(player_id: sp.player_id, season_id: sp.season_id, club_id: id).blank?
            sp.update(club_id: id)
          end
        end
      end
    else
      Rails.logger.info "== scrape == No Players for club #{name} #{players_url}"
    end
  end

  def self.merge(club_a, club_b)
    master = club_a.address.present? ? club_a : club_b
    slave = master == club_a ? club_b : club_a
    slave.season_participations.each do |sp|
      sp.club = master
      if SeasonParticipation.where(club_id: master.id, player_id: sp.player_id, season_id: sp.season_id).blank?
        sp.source_url = club_a.source_url
        sp.save
      end
    end
    slave.locations.each do |location|
      location.update(club: master)
    end
    slave.organized_tournaments.each do |tournament|
      tournament.update(organizer: master)
    end
    slave.league_teams.each do |league_team|
      league_team.update(club: master)
    end
    slave.destroy
  end

  def self.find_duplicates
    Club.where("name = shortname").each do |slave|
      master = Club.where("name ilike '#{slave.name.tr("'", " ")} e.V.'").where.not(id: slave.id).first
      Club.merge(master, slave) if master.present?
    end
  end

  def self.merge_duplicates_method_two
    Club.where.not(ba_id: nil).where(cc_id: nil, dbu_nr: nil).each do |club|
      next if club.name.blank? || (club.name.split(" ").count < 2) || club.name == "BV Pool" || club.name == "XXXX -"

      Rails.logger.info "===== scrape ===== merging club '#{club.name}'"
      clubs = []
      if club.name.present?
        clubs |= Club.where("synonyms ilike ?", "%#{club.name.strip}%").to_a.select do |club_|
          club_.synonyms.split("\n").include?(club.name.strip)
        end
      end
      if club.shortname.present?
        clubs |= Club.where("synonyms ilike ?", "%#{club.shortname.strip}%").to_a.select do |club_|
          club_.synonyms.split("\n").include?(club.shortname.strip)
        end
      end
      next if clubs.count < 2

      clubs_with_ba_ids = clubs.select { |club_| club_.ba_id.present? && club_.ba_id < 900_000_000 }
      if clubs_with_ba_ids.present?
        club_master = clubs_with_ba_ids.inject(clubs_with_ba_ids[0]) do |memo, club_|
          memo = club_ if club_.ba_id > memo.ba_id
          memo
        end
      else
        clubs_without_ba_ids = clubs.select { |club_| club_.ba_id.present? && club_.ba_id > 900_000_000 }
        club_master = clubs_without_ba_ids[0]
        club_master.update(ba_id: (998_000_000 + club_master.id)) if club_master.present?
      end
      clubs_to_merge = clubs - [club_master]
      if club_master.present?
        if clubs_to_merge.present?
          club_master.merge_clubs(clubs_to_merge.map(&:id), force_merge: true)
        elsif club_master.present?
          club_master.update(ba_id: 998_000_000 + club_master.id)
        end
      end
    end
  end

  def self.merge_duplicates
    Club.where("ba_id > 999000000").each do |club|
      next if club.name.blank? || (club.name.split(" ").count < 2) || club.name == "BV Pool" || club.name == "XXXX -"

      Rails.logger.info "===== scrape ===== merging club '#{club.name}'"
      clubs = []
      if club.name.present?
        clubs |= Club.where("synonyms ilike ?", "%#{club.name.strip}%").to_a.select do |club_|
          club_.synonyms.split("\n").include?(club.name.strip)
        end
      end
      if club.shortname.present?
        clubs |= Club.where("synonyms ilike ?", "%#{club.shortname.strip}%").to_a.select do |club_|
          club_.synonyms.split("\n").include?(club.shortname.strip)
        end
      end
      clubs_with_ba_ids = clubs.select { |club_| club_.ba_id.present? && club_.ba_id < 900_000_000 }
      if clubs_with_ba_ids.present?
        club_master = clubs_with_ba_ids.inject(clubs_with_ba_ids[0]) do |memo, club_|
          memo = club_ if club_.ba_id > memo.ba_id
          memo
        end
      else
        clubs_without_ba_ids = clubs.select { |club_| club_.ba_id.present? && club_.ba_id > 900_000_000 }
        club_master = clubs_without_ba_ids[0]
        club_master.update(ba_id: (998_000_000 + club_master.id)) if club_master.present?
      end
      clubs_to_merge = clubs - [club_master]
      if club_master.present?
        if clubs_to_merge.present?
          club_master.merge_clubs(clubs_to_merge.map(&:id), force_merge: true)
        elsif club_master.present?
          club_master.update(ba_id: 998_000_000 + club_master.id)
        end
      end
    end
  end

  def self.find_potential_duplicates
    potential_duplicates = []

    # Get all clubs that have synonyms
    clubs = Club.where.not(synonyms: [nil, ""])

    # Create a hash to group clubs by their synonyms
    synonym_groups = {}

    clubs.find_each do |club|
      # Get all synonyms for this club, including name and shortname
      all_synonyms = (club.synonyms.to_s.split("\n") + [club.name, club.shortname])
        .map(&:strip)
        .reject(&:blank?)
        .map(&:downcase)
        .uniq

      # For each synonym, add the club to the corresponding group
      all_synonyms.each do |synonym|
        synonym_groups[synonym] ||= []
        synonym_groups[synonym] << club
      end
    end

    # Find groups that have multiple clubs
    synonym_groups.each do |synonym, clubs_in_group|
      next if clubs_in_group.size <= 1

      # For each pair of clubs in the group, check if they might be duplicates
      clubs_in_group.combination(2).each do |club1, club2|
        # Skip if these clubs have already been compared
        next if potential_duplicates.any? { |dup|
          (dup[:club1][:id] == club1.id && dup[:club2][:id] == club2.id) ||
          (dup[:club1][:id] == club2.id && dup[:club2][:id] == club1.id)
        }

        # Calculate how many synonyms they share
        club1_synonyms = club1.synonyms.to_s.split("\n").map(&:strip).map(&:downcase)
        club2_synonyms = club2.synonyms.to_s.split("\n").map(&:strip).map(&:downcase)
        shared_synonyms = (club1_synonyms & club2_synonyms)

        # If they share synonyms or have similar names/shortnames, they might be duplicates
        if shared_synonyms.any? ||
           calculate_similarity(club1.name, club2.name) > 0.8 ||
           calculate_similarity(club1.shortname, club2.shortname) > 0.8

          potential_duplicates << {
            club1: {
              id: club1.id,
              name: club1.name,
              shortname: club1.shortname,
              address: club1.address,
              ba_id: club1.ba_id,
              cc_id: club1.cc_id,
              synonyms: club1.synonyms
            },
            club2: {
              id: club2.id,
              name: club2.name,
              shortname: club2.shortname,
              address: club2.address,
              ba_id: club2.ba_id,
              cc_id: club2.cc_id,
              synonyms: club2.synonyms
            },
            shared_synonyms: shared_synonyms,
            name_similarity: calculate_similarity(club1.name, club2.name),
            shortname_similarity: calculate_similarity(club1.shortname, club2.shortname)
          }
        end
      end
    end

    # Sort by number of shared synonyms and name similarity
    potential_duplicates.sort_by { |dup|
      [
        -dup[:shared_synonyms].size,  # More shared synonyms first
        -dup[:name_similarity]        # Higher name similarity first
      ]
    }
  end

  def merge_clubs(with_club_ids = [], opts = {})
    Club.transaction do
      if opts[:force_merge] || (Club.where(id: with_club_ids).map(&:name).sort + synonyms.split("\n"))
                                 .uniq.compact.sort == synonyms.split("\n").uniq.compact.sort
        Rails.logger.info("REPORT merging clubs (#{name}[#{id}] with #{Array(with_club_ids).map do |idx|
          "#{Club[idx].name} [#{idx}]"
        end})")
        update(synonyms: (Club.where(id: with_club_ids).map(&:name) +
          Array(synonyms.andand.split("\n"))).uniq.join("\n"))
        SeasonParticipation.where(club_id: with_club_ids).each do |sp|
          unless SeasonParticipation.where(player_id: sp.player_id, season_id: sp.season_id, club_id: id).first.present?
            sp.update(club_id: id)
          end
        end
        SeasonParticipation.where(club_id: with_club_ids).destroy_all
        ClubLocation.where(club_id: with_club_ids).all.each do |l|
          l.update(club_id: id)
        end
        LeagueTeam.where(club_id: with_club_ids).all.each { |lt| lt.update(club_id: id) }
        Tournament.where(organizer_type: "Club", organizer_id: with_club_ids).all.each do |t|
          t.update(organizer_id: id)
        end
        Club.where(id: with_club_ids).destroy_all
      else
        merge_with = Array(with_club_ids).map do |idx|
          "#{Club[idx].name} [#{idx}]"
        end
        Rails.logger.info "===== scrape ===== ERROR cannot merge automatically - too different -\
 check manually merge clubs #{name}[#{id}] with #{merge_with}"
      end
    end
    reload
  end

  private

  def self.calculate_similarity(str1, str2)
    return 0.0 if str1.blank? || str2.blank?

    # Normalize strings
    str1 = str1.to_s.downcase.strip
    str2 = str2.to_s.downcase.strip

    # If strings are identical, return 1.0
    return 1.0 if str1 == str2

    # Calculate Levenshtein distance
    require 'text'
    max_length = [str1.length, str2.length].max
    distance = Text::Levenshtein.distance(str1, str2)

    # Convert distance to similarity score (0.0 to 1.0)
    1.0 - (distance.to_f / max_length)
  end
end
