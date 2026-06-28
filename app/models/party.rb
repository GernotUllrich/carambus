# == Schema Information
#
# Table name: parties
#
#  id                             :bigint           not null, primary key
#  allow_follow_up                :boolean          default(TRUE), not null
#  color_remains_with_set         :boolean          default(TRUE), not null
#  continuous_placements          :boolean          default(FALSE), not null
#  data                           :text
#  date                           :datetime
#  day_seqno                      :integer
#  fixed_display_left             :string
#  group                          :string
#  kickoff_switches_with          :string
#  manual_assignment              :boolean
#  party_no                       :integer
#  register_at                    :date
#  remarks                        :text
#  reported_at                    :datetime
#  reported_by                    :string
#  round                          :string
#  section                        :string
#  sets_to_play                   :integer          default(1), not null
#  sets_to_win                    :integer          default(1), not null
#  source_url                     :string
#  status                         :integer
#  sync_date                      :datetime
#  team_size                      :integer          default(1), not null
#  time                           :datetime
#  time_out_stoke_preparation_sec :integer          default(45)
#  time_out_warm_up_first_min     :integer          default(5)
#  time_out_warm_up_follow_up_min :integer          default(3)
#  timeout                        :integer          default(0), not null
#  timeouts                       :integer
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  ba_id                          :integer
#  cc_id                          :integer
#  host_league_team_id            :integer
#  league_id                      :integer
#  league_team_a_id               :integer
#  league_team_b_id               :integer
#  location_id                    :integer
#  no_show_team_id                :integer
#  reported_by_player_id          :integer
#
class Party < ApplicationRecord
  include LocalProtector
  include SourceHandler
  include RegionTaggable
  include Searchable

  self.ignored_columns = ["region_ids"]

  belongs_to :league, class_name: "League", foreign_key: :league_id
  has_many :games, as: :tournament, class_name: "Game", dependent: :destroy
  belongs_to :league_team_a, class_name: "LeagueTeam", foreign_key: :league_team_a_id, optional: true
  belongs_to :league_team_b, class_name: "LeagueTeam", foreign_key: :league_team_b_id, optional: true
  belongs_to :host_league_team, class_name: "LeagueTeam", foreign_key: :host_league_team_id, optional: true
  belongs_to :location, optional: true
  belongs_to :no_show_team, class_name: "LeagueTeam", foreign_key: :no_show_team_id, optional: true

  has_one :party_monitor, dependent: :nullify
  has_one :party_cc, dependent: :destroy
  has_many :party_games, -> { order("seqno") }
  has_many :seedings, -> { order(position: :asc) }, as: :tournament, dependent: :destroy

  serialize :data, coder: JSON, type: Hash
  serialize :remarks, coder: YAML, type: Hash

  REFLECTIONS = %w[versions
                   league
                   games
                   league_team_a
                   league_team_b
                   host_league_team
                   location
                   no_show_team
                   party_cc
                   party_games]

  COLUMN_NAMES = {
    # IDs (versteckt, nur für Backend-Filterung)
    "id" => "parties.id",
    "league_id" => "parties.league_id",
    "season_id" => "seasons.id",
    "region_id" => "regions.id",

    # Referenzen (Dropdown/Select)
    "League" => "leagues.name",
    "Season" => "seasons.name",
    "Region" => "regions.shortname",

    # Eigene Felder
    "Date" => "parties.date::date",
  }.freeze

  # Searchable concern provides search_hash
  def self.text_search_sql
    "(leagues.name ilike :search)
     or (leagues.shortname ilike :search)
     or (regions.shortname ilike :search)
     or (seasons.name ilike :search)"
  end

  def self.search_joins
    [
      :league,
      'LEFT OUTER JOIN "regions" ON ("regions"."id" = "leagues"."organizer_id" AND "leagues"."organizer_type" = \'Region\')',
      'LEFT OUTER JOIN "seasons" ON "seasons"."id" = "leagues"."season_id"'
    ]
  end

  def self.search_distinct?
    false
  end

  def self.cascading_filters
    {
      'season_id' => ['league_id'],
      'region_id' => []
    }
  end

  def self.field_examples(field_name)
    case field_name
    when 'League'
      { description: "Liga auswählen", examples: [] }
    when 'Season'
      { description: "Saison auswählen", examples: [] }
    when 'Region'
      { description: "Region/Veranstalter auswählen", examples: [] }
    when 'Date'
      { description: "Spieltag-Datum", examples: ["2024-01-15", "> 2024-01-01"] }
    else
      super
    end
  end

  # Plan 46.5-03: Phantom-Duplikat-Cleanup. Entfernt LEERE Dubletten (0 party_games UND kein
  # Ziffern-Ergebnis) je natürlichem Schlüssel (league_id + day_seqno + teams) — bewusst OHNE
  # round_name, denn die Alt-Phantome (alte Scraper-Logik) haben round_name=nil, echte Parties
  # aber gesetzt; mit round_name würden sie nicht als Dubletten desselben Spieltags erkannt.
  # (day_seqno + teams identifiziert den Spieltag eindeutig.) Behält IMMER mindestens eine Party
  # je Termin und NIE eine gespielte (party_games/Ergebnis). Default dry_run (nur Report).
  # Authority-seitig — LocalProtector blockt global-Record-Deletes auf Local-Servern. Idempotent.
  # MEMORY-SAFE: verarbeitet PRO LIGA (nicht alle ~15k Parties + ~100k party_games auf einmal —
  # das OOM't auf der Produktions-Authority). Pro Liga sind es nur hunderte Records.
  def self.cleanup_phantom_duplicates(scope: Party.all, dry_run: true)
    report = {groups_with_dupes: 0, deleted: 0, deleted_ids: [], kept: 0, dry_run: dry_run}
    # WICHTIG: data wird teils mit Symbol-Key {result: …} gespeichert (Ergebnis-Nachtrag/Create),
    # teils mit String-Key. p.data["result"] allein verfehlt Symbol-Einträge → eine Party MIT echtem
    # Ergebnis (Symbol-Key) aber ohne party_games würde sonst als Phantom gelöscht (DATENVERLUST).
    # Daher BEIDE Keys prüfen (wie League::StandingsCalculator).
    phantom = ->(p) { p.party_games.empty? && (p.data["result"] || p.data[:result]).to_s !~ /\d/ }
    scope.distinct.pluck(:league_id).compact.each do |lid|
      # Nur diese Liga laden (Schlüssel innerhalb der Liga = day_seqno + teams).
      scope.where(league_id: lid).includes(:party_games)
        .group_by { |p| [p.day_seqno, p.league_team_a_id, p.league_team_b_id] }
        .each do |_key, parties|
        next if parties.size <= 1
        reals = parties.reject { |p| phantom.call(p) }
        to_delete = if reals.any?
          parties.select { |p| phantom.call(p) } # echte/gespielte bleiben ALLE
        else
          parties - [parties.min_by(&:id)] # nur Phantome: genau eine (niedrigste id) behalten
        end
        next if to_delete.empty?
        report[:groups_with_dupes] += 1
        report[:kept] += parties.size - to_delete.size
        report[:deleted] += to_delete.size
        to_delete.each do |p|
          report[:deleted_ids] << p.id
          p.destroy unless dry_run
        end
      end
    end
    report
  end

  def kickoff_switches_with
    read_attribute(:kickoff_switches_with).presence || "set"
  end

  # Spielbare Row-Typen eines Spieltags (identisch zur Filterliste in
  # party_monitor_reflex#start_round + #close_party).
  GAME_ROW_TYPES = ["14/1e", "10-Ball", "8-Ball", "9-Ball", "10-Ball Doppel", "9-Ball Doppel",
    "Shootout (4er Team)"].freeze

  # Aktuelles Mannschaftsergebnis [points_team_a, points_team_b] aus den gespielten Partien.
  #
  # Quelle = game.data["ba_results"] (autoritative gespielte Werte; GameParticipation.points
  # bleibt bei manual_assignment-Parties nil, vgl. D-17-06-B). Konvention Sets1/Ergebnis1 = team_a
  # (links), wie PartyMonitor::ResultProcessor#update_game_participations (kein Swap).
  # game_points je Spiel aus der Row (Default win=1/draw=0/lost=0 — manche Parties tragen keine
  # game_points-Config; Phase-47-01-Befund). Ungespielte/leere Games + Nicht-Spiel-Rows zählen 0.
  def intermediate_result
    rows = party_monitor&.data&.dig("rows")
    return [0, 0] if rows.blank?

    points_l = 0
    points_r = 0
    rows.each do |row|
      next unless GAME_ROW_TYPES.include?(row["type"])

      gname = "#{row["seqno"]}-#{row["type"]}"
      game = games.find_by(gname: gname)
      next if game.nil? || game.ended_at.blank?

      ba = game.data["ba_results"]
      next if ba.blank?

      gp = HashWithIndifferentAccess.new(row["game_points"].presence || {})
      win = (gp["win"] || 1).to_i
      draw = (gp["draw"] || 0).to_i
      lost = (gp["lost"] || 0).to_i

      if row["sets"].to_i > 1
        a = ba["Sets1"].to_i
        b = ba["Sets2"].to_i
      else
        a = ba["Ergebnis1"].to_i
        b = ba["Ergebnis2"].to_i
      end

      if a > b
        points_l += win
        points_r += lost
      elsif b > a
        points_l += lost
        points_r += win
      else
        points_l += draw
        points_r += draw
      end
    end
    [points_l, points_r]
  end

  # Schreibt das Endergebnis EINER Liga-Einzelpartie direkt nach game.data["ba_results"]
  # + ended_at (Direct-to-Game, Phase 48 / D-48-1) — OHNE TableMonitor/evaluate_result.
  # Konvention Index1 = team_a (links, kein Swap), kompatibel zu #intermediate_result und
  # party_monitors/_game_row.html.erb. sc1/sc2 = Satz-/Punkteergebnis team_a/team_b;
  # in1/in2 = Aufnahmen, br1/br2 = Höchstserie (i.d.R. nur 14.1 endlos).
  # Leere Eingabe (sc1 UND sc2 blank) => Game wird übersprungen (kein ended_at, nil-Return).
  def record_game_result!(row:, sc1:, sc2:, in1: nil, in2: nil, br1: nil, br2: nil)
    return if sc1.to_s.strip.blank? && sc2.to_s.strip.blank?

    gname = "#{row["seqno"]}-#{row["type"]}"
    game = games.find_by(gname: gname)
    return if game.nil?

    player_a = Player.find_by(id: Array(row["player_a"]).first)
    player_b = Player.find_by(id: Array(row["player_b"]).first)

    ba = {
      "Spieler1" => player_a&.ba_id,
      "Spieler2" => player_b&.ba_id,
      "Ergebnis1" => sc1.to_i,
      "Ergebnis2" => sc2.to_i
    }
    if row["sets"].to_i > 1
      ba["Sets1"] = sc1.to_i
      ba["Sets2"] = sc2.to_i
    end
    ba["Aufnahmen1"] = in1.to_i if in1.to_s.strip.present?
    ba["Aufnahmen2"] = in2.to_i if in2.to_s.strip.present?
    ba["Höchstserie1"] = br1.to_i if br1.to_s.strip.present?
    ba["Höchstserie2"] = br2.to_i if br2.to_s.strip.present?

    game.deep_merge_data!("ba_results" => ba)
    game.update!(ended_at: Time.now)
    game
  end

  # Erzeugt (find-or-create per gname) das Game EINER Spielzeile OHNE TableMonitor-Bindung
  # (Phase 48-03 / K-1). Extrahiert aus party_monitor_reflex#start_round, damit der
  # Direkteingabe-Pfad (48-04-Endpoint) Games anlegen kann, ohne dass ein Scoreboard läuft —
  # sonst liefe ein Ergebnis-Push ins Leere (record_game_result! setzt das Game voraus).
  # Der Live-start_round-Pfad ruft dieselbe Naht und führt DANACH do_placement aus.
  # row = HashWithIndifferentAccess-fähige Spielzeile (type/seqno/sets/score/innings/first_break/
  # next_break/player_a/player_b); t_no = Tisch-Nr (nur Anzeige in data, keine TableMonitor-Bindung).
  def build_game_for_row!(row, r_no, t_no = nil)
    row = row.with_indifferent_access
    gname = "#{row[:seqno]}-#{row[:type]}"
    row_type = (row[:type] == "14/1e") ? "14.1 endlos" : row[:type]
    score_value = row[:score]
    score_value = score_value.scan(/\d+/).last.to_i if score_value.is_a?(String)
    score_value = score_value.to_i if score_value.present?

    essential_game_options = {
      gname: gname,
      started_at: Time.now,
      round_no: r_no,
      seqno: row[:seqno]
    }
    additional_options = {
      free_game_form: "pool",
      kickoff_switches_with: (row[:next_break] unless row_type == "14.1 endlos").presence || "set",
      table_no: t_no,
      player_a_id: row[:player_a],
      player_b_id: row[:player_b],
      discipline_a: row_type,
      discipline_b: row_type,
      sets_to_win: row[:sets].to_i,
      points_choice: score_value,
      balls_goal_a: score_value,
      balls_goal_b: score_value,
      innings_goal: row[:innings].to_i,
      first_break_choice: row[:first_break]
    }
    game = games.where(gname: gname).first || games.new(essential_game_options)
    game.assign_attributes(data: additional_options)
    game.save!
    game
  end

  # Stellt sicher, dass ein PartyMonitor existiert und sein data aus league.game_plan.data
  # geseedet ist (Phase 48-03 / K-3). Idempotent: vorhandene Runden-/Ergebnis-Daten (rows)
  # werden NICHT überschrieben. Muster: parties_controller#party_monitor + gather_parameters-Seed.
  def ensure_party_monitor!
    pm = party_monitor || create_party_monitor
    if pm.data["rows"].blank? && league&.game_plan&.data.present?
      pm.data = league.game_plan.data
      pm.save
    end
    pm
  end

  def name
    "#{league_team_a.name} - #{league_team_b.name}"
  end

  def title
    name
  end

  def party_nr
    unless party_no.present?
      first_cc_id = league.parties.order(:cc_id).first.cc_id
      self.unprotected = true
      self.party_no = cc_id - first_cc_id + 1
      save!
      self.unprotected = false
    end
    party_no.to_i
  end

  def player_controlled?
    false
  end

  def handicap_tournier?
    false
  end

  def manual_assignment
    true
  end

  def cc_link
    "#{league.organizer.public_cc_url_base}sb_spielbericht.php?p=#{league.organizer.cc_id}--#{league.season.name}-#{league.cc_id}-#{league.cc_id2.presence || "0"}-#{cc_id}"
  end

  def get_non_show_team
    return league_team_b.id if no_show_team_id == league_team_a.id
    league_team_a.id
  end
end
