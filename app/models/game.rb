# frozen_string_literal: true

# == Schema Information
#
# Table name: games
#
#  id              :bigint           not null, primary key
#  data            :text
#  ended_at        :datetime
#  gname           :string
#  group_no        :integer
#  roles           :text
#  round_no        :integer
#  seqno           :integer
#  started_at      :datetime
#  table_no        :integer
#  tournament_type :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  tournament_id   :integer
#
class Game < ApplicationRecord
  include LocalProtector
  include RegionTaggable

  self.ignored_columns = ["region_ids"]

  # Configure PaperTrail to ignore automatic timestamp updates
  # This prevents unnecessary version records during scraping operations
  has_paper_trail ignore: [:updated_at] unless Carambus.config.carambus_api_url.present?

  # belongs_to :tournament, polymorphic: true, optional: true
  belongs_to :tournament, optional: true
  has_many :game_participations, dependent: :destroy
  has_one :table_monitor, dependent: :nullify
  has_one :was_table_monitor, foreign_key: :prev_game_id, class_name: "TableMonitor", dependent: :nullify

  before_save :set_paper_trail_whodunnit

  # serialize :data, coder: YAML, type: Hash
  serialize :data, coder: JSON, type: Hash

  # Helper method to safely decode legacy YAML or JSON data
  def self.safe_decode_data(raw_data)
    return {} if raw_data.blank?

    # Try JSON first
    begin
      return JSON.parse(raw_data)
    rescue JSON::ParserError
      # If JSON fails, try YAML with safe loading
      begin
        # Use YAML.load instead of safe_load for better compatibility with old data
        return YAML.load(raw_data)
      rescue Psych::SyntaxError => e
        Rails.logger.error "Failed to parse data: #{e.message}"
        return {}
      end
    end
  end

  # Override the data getter to handle both formats
  def data
    raw_data = read_attribute_before_type_cast(:data)
    decoded_data = self.class.safe_decode_data(raw_data)

    # If we successfully decoded YAML data, convert it to JSON
    if decoded_data.present? && raw_data.start_with?('---')
      begin
        self.data = decoded_data # This will serialize it as JSON
        save!
        Rails.logger.info "Converted YAML to JSON for Game[#{id}]"
      rescue StandardError => e
        Rails.logger.error "Failed to save data: #{e.message}"
        exit 1
      end
    end

    decoded_data
  end

  #   #"data"=>
  #   { "ba_results" =>
  #       { "Gruppe" => 1,
  #         "Partie" => 5,
  #         "Spieler1" => 352853,
  #         "Spieler2" => 121340,
  #         "Points1" => 3,
  #         "Points2" => 0,
  #         "Sets1" => 2,
  #         "Sets2" => 0,
  #         "Ergebnis1" => 150,
  #         "Ergebnis2" => 64,
  #         "Aufnahmen1" => 22,
  #         "Aufnahmen2" => 22,
  #         "Höchstserie1" => 20,
  #         "Höchstserie2" => 15,
  #         "Tischnummer" => 2
  #       },
  #     {
  #     "sets" =>
  #       [
  #         { "Gruppe" => 1,
  #           "SetNo" => 1,
  #           "Spieler1" => 352853,
  #           "Spieler2" => 121340,
  #           "Ergebnis1" => 75,
  #           "Ergebnis2" => 32,
  #           "Aufnahmen1" => 11,
  #           "Aufnahmen2" => 11,
  #           "Höchstserie1" => 20,
  #           "Höchstserie2" => 15,
  #           "Tischnummer" => 2
  #         },
  #         { "Gruppe" => 1,
  #           "SetNo" => 2,
  #           "Partie" => 5,
  #           "Spieler1" => 352853,
  #           "Spieler2" => 121340,
  #           "Ergebnis1" => 75,
  #           "Ergebnis2" => 32,
  #           "Aufnahmen1" => 11,
  #           "Aufnahmen2" => 11,
  #           "Höchstserie1" => 20,
  #           "Höchstserie2" => 15,
  #           "Tischnummer" => 2
  #         },
  #       ]
  #   }
  #   }

  MIN_ID = 50_000_000

  before_create :log

  def log
    Tournament.logger.info "NEW Game attributes = #{attributes.inspect}"
  end

  before_save do
    Tournament.logger.info "Game[#{id}] - #{gname} ##{seqno}" if seqno_changed?
  end

  COLUMN_NAMES = {
    "Date" => "tournaments.date::date",
    "Tournament" => "tournaments.title",
    "Name" => "games.gname",
    "Remarks" => "games.data",
    "Player" => "players.fl_name"
  }.freeze

  def self.search_hash(params)
    {
      model: Game,
      sort: params[:sort],
      direction: sort_direction(params[:direction]),
      search: "#{[params[:sSearch], params[:search]].compact.join("&")}",
      column_names: Game::COLUMN_NAMES,
      raw_sql: "(tournaments.title ilike :search)
      or (regions.shortname ilike :search)
      or (games.gname ilike :search)
      or (seasons.name ilike :search)
      or exists (
        select 1
        from game_participations gp
        join players p on p.id = gp.player_id
        where gp.game_id = games.id
        and p.fl_name ilike :search
      )",
      joins: [
        "LEFT JOIN tournaments ON (games.tournament_id = tournaments.id)",
        'LEFT JOIN regions ON (regions.id = tournaments.organizer_id AND tournaments.organizer_type = \'Region\')',
        'LEFT JOIN seasons ON (seasons.id = tournaments.season_id)',
        'LEFT JOIN game_participations ON game_participations.game_id = games.id',
        'LEFT JOIN players ON players.id = game_participations.player_id'
      ]
    }
  end

  def self.legacy_role_joins
    # Define legacy roles with their exact database values
    legacy_roles = {
      'guest' => 'Gast',
      'home' => 'Heim',
      'playera' => 'playera',
      'playerb' => 'playerb'
    }

    legacy_roles.map do |alias_name, role_value|
      [
        "LEFT JOIN game_participations AS #{alias_name}_game_participations ON
        #{alias_name}_game_participations.game_id = games.id AND
        #{alias_name}_game_participations.role = '#{role_value}'",

        "LEFT JOIN players AS #{alias_name}_players ON
        #{alias_name}_game_participations.player_id = #{alias_name}_players.id"
      ]
    end
  end

  def log_state_change
    if DEBUG
      Rails.logger.info "-------------m6[#{id}]-------->>> log_state_change <<<------------------------------------------"
    end
    if state_changed?
      # Tournament.logger.info "[PartyMonitor] STATE_CHANGED [#{id}]: #{state_change[0]} -> #{state_change[1]} #{caller.select{|s| s.include?("/app/")}.join("\n")}"
      Tournament.logger.info "[PartyMonitor] STATE_CHANGED [#{id}]: #{state_change[0]} -> #{state_change[1]}"
      Rails.logger.info "[PartyMonitor] STATE_CHANGED [#{id}]: #{state_change[0]} -> #{state_change[1]}" if DEBUG
    end
  rescue StandardError => e
    Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError
  end

  def deep_merge_data!(hash)
    h = data.dup
    h.deep_merge!(hash)
    
    # Only call data_will_change! if the data actually changed
    if h != data
      data_will_change!
      self.data = JSON.parse(h.to_json)
    end
    # save!
  end

  def deep_delete!(key)
    h = data.dup
    res = nil
    if h[key].present?
      res = h.delete(key)
      
      # Only call data_will_change! if the data actually changed
      if h != data
        data_will_change!
        self.data = JSON.parse(h.to_json)
        save!
      end
    end
    res
  end

  RANKING_KEY_PATTERNS = {
    %r{group(\d+):(\d+)-(\d+)(?:\/(\d+))} => ->(m) { I18n.t("game.display_group_game_name_rp", group_no: m[1], playera: m[2], playerb: m[3], rp: m[4]).html_safe },
    /group(\d+):(\d+)-(\d+)/ => ->(m) { I18n.t("game.display_group_game_name", group_no: m[1], playera: m[2], playerb: m[3]).html_safe },
    /group(\d+)/i => ->(m) { I18n.t("game.display_group_game_name_short", group_no: clean_key(m[1])).html_safe },
    # ... repeated for all patterns
  }.freeze

  def clean_key(key)
    key.to_str.gsub("/", "")
  end

  def self.display_ranking_key(ranking_key)
    return unless ranking_key.present?

    RANKING_KEY_PATTERNS.each do |pattern, translator|
      next unless (m = ranking_key.match(pattern))

      return translator.call(m)
    end

    nil
  end

  def display_gname
    Game.display_ranking_key(gname)
  end

  def self.fix_participation(game, opts = {})
    mapping = { "Gr." => :gname, "Ergebnis" => :result, "Aufnahme" => :innings, "HS" => :hs, "GD" => :gd,
                "Punkte" => :points }
    tournament = game.tournament
    begin
      if tournament.present?
        game_participition_ids = game.game_participition_ids
        game.game_participations.delete_all if opts[:touch_games]
        player_a = Player.joins(seedings: :tournament).where(tournaments: { id: tournament.id })
                         .where("players.lastname||', '||players.firstname = :name", name: game.data["Heim"]).first
        if player_a.present?
          gp_a = GameParticipition.where(game_id: game.id, player_id: player_a.id).first
          gp_a.updated_at = Time.now if gp_a.present? && opts(:touch_games)
          gp_a ||= GameParticipition.create(game_id: game.id, player_id: player_a.id)
          gp_a.assign_attributes(role: "Heim")
          gp_a.save
          game_participition_ids.delete(gp_a.id)
        end
        player_b = Player.joins(seedings: :tournament).where(tournaments: { id: tournament.id })
                         .where("players.lastname||', '||players.firstname = :name", name: game.data["Gast"]).first
        if player_b.present?
          gp_b = GameParticipition.where(game_id: game.id, player_id: player_b.id).first
          gp_b.updated_at = Time.now if gp_b.present? && opts(:touch_games)
          gp_b ||= GameParticipition.create(game_id: game.id, player_id: player_b.id)
          gp_b.assign_attributes(role: "Gast")
          gp_b.save
          game_participition_ids.delete(gp_b.id)
        end
        GameParticipition.where(id: game_participition_ids).destroy_all
        gp_a_results = {}
        gp_b_results = {}
        game.data.each do |k, v|
          if /:/.match?(v)
            heim, gast = v.split(":").map(&:strip).map { |str| str =~ /,/ ? str.tr(",", ".").to_f : str.to_i }
            gp_a_results[k] = heim
            gp_b_results[k] = gast
          elsif k == "Gr."
            gp_a_results[k] = v
            gp_b_results[k] = v
          end
        end
        if gp_a.present?
          remarks_a = gp_a.data || {}
          remarks_a["results"] = gp_a_results
          attrs = {}
          if gp_a.data["results"].present?
            attrs = attrs.merge(Array(gp_a.data["results"]).transform_keys { |k| mapping[k] }.symbolize_keys)
          end
          attrs = attrs.merge(data: remarks_a)
          gp_a.assign_attributes(attrs)
          gp_a.save
        end
        if gp_b.present?
          remarks_b = gp_b.data || {}
          remarks_b["results"] = gp_b_results
          attrs = {}
          if gp_b.data["results"].present?
            attrs = attrs.merge(Array(gp_b.data["results"]).transform_keys { |k| mapping[k] }.symbolize_keys)
          end
          attrs = attrs.merge(data: remarks_b)
          gp_b.assign_attributes(attrs)
          gp_b.save
        end
      else
        game.destroy
      end
    rescue StandardError
      game.destroy
    end
  end

  # Allow NULL values for tournament_id and gname (for training games)
  # But maintain uniqueness when values are present
  validates :seqno, uniqueness: { 
    scope: [:tournament_id, :gname], 
    message: "Duplicate game in group",
    allow_nil: true
  }
end
