# frozen_string_literal: true

# Kapselt die GamePlan-Rekonstruktionslogik aus dem League-Modell.
# Verantwortlichkeiten:
#   - GamePlan aus vorhandenen Parties und PartyGames rekonstruieren
#   - GamePlans für alle Ligen einer Saison rekonstruieren
#   - GamePlans einer Saison löschen
#
# Verwendung:
#   League::GamePlanReconstructor.call(league: league, operation: :reconstruct)
#   League::GamePlanReconstructor.call(season: season, operation: :reconstruct_for_season)
#   League::GamePlanReconstructor.call(league: league, season: season, operation: :delete_for_season)
#
# ApplicationService gemäß D-06 des Extraktionsplans.
class League::GamePlanReconstructor < ApplicationService
  def initialize(kwargs = {})
    @league = kwargs[:league]
    @season = kwargs[:season]
    @operation = kwargs[:operation] || :reconstruct
    @opts = kwargs.except(:league, :season, :operation)
  end

  def call
    case @operation
    when :reconstruct then reconstruct
    when :reconstruct_for_season then reconstruct_for_season
    when :delete_for_season then delete_for_season
    else raise ArgumentError, "Unknown operation: #{@operation}"
    end
  end

  private

  # Reconstruct GamePlan from existing parties and party_games data
  def reconstruct
    return unless @league.discipline.present?

    Rails.logger.info "Reconstructing GamePlan for league: #{@league.name} (ID: #{@league.id})"

    # Start with default game parameters for the discipline type
    branch_name = @league.branch.name.downcase.to_sym
    game_plan = League::GAME_PARAMETER_DEFAULTS[branch_name].dup
    game_plan[:rows] = []

    # Track disciplines and their statistics
    disciplines = {}
    non_shootout_games = 0
    games_per_round = 0
    tables = 0
    game_seqno = 0

    # Get all parties with their party_games, ordered by day_seqno
    parties_with_games = @league.parties.includes(:party_games).order(:day_seqno, :id)

    # First, analyze one party to extract the structure (row headers)
    # This is more efficient since structure doesn't change within a season
    structure_analyzed = false

    parties_with_games.each do |party|
      next unless party.party_games.any?

      # Analyze structure from the first party with games
      unless structure_analyzed
        analyze_game_plan_structure(party, game_plan, disciplines)
        structure_analyzed = true
        game_seqno = game_plan[:rows].count { |row| row[:type] != "Neue Runde" && row[:type] != "Gesamtsumme" }
      end

      # Group party_games by discipline to identify rounds
      games_by_discipline = party.party_games.group_by(&:discipline)

      games_by_discipline.each do |discipline, games|
        next unless discipline.present?

        discipline_name = discipline.name
        disciplines[discipline_name] ||= {}

        # Analyze each game in this discipline for statistics only
        games.each do |party_game|
          game_seqno += 1
          games_per_round += 1

          # Extract game data for statistics
          game_data = party_game.data || {}
          result_data = game_data[:result] || game_data["result"] || {}

          # Extract result information
          result = result_data["Ergebnis:"] || result_data["Ergebnis"] || "0:0"
          points = result_data["Punkte:"] || result_data["Punkte"] || "0:0"
          balls = result_data["Bälle:"] || result_data["Bälle"] || nil
          innings = result_data["Aufn.:"] || result_data["Aufn."] || nil

          # Parse result and points
          result_values = result.split(/\s*:\s*/).map(&:to_i)
          point_values = points.split(/\s*:\s*/).map(&:to_i)

          # Update game points statistics
          if point_values.present?
            max_game_points = point_values.max
            min_game_points = point_values.min
            draw_game_points = (point_values[0] == point_values[1]) ? point_values[0] : 0

            # Update discipline statistics
            if disciplines[discipline_name][:game_points].blank?
              disciplines[discipline_name][:game_points] = {
                win: max_game_points,
                draw: draw_game_points,
                lost: min_game_points
              }
            else
              disciplines[discipline_name][:game_points][:win] = [disciplines[discipline_name][:game_points][:win].to_i, max_game_points].max
              disciplines[discipline_name][:game_points][:lost] = [disciplines[discipline_name][:game_points][:lost].to_i, min_game_points].min
              if draw_game_points > 0
                disciplines[discipline_name][:game_points][:draw] = draw_game_points
              end
            end
          end

          # Handle sets (for games that use sets)
          if result_values.present? && result_values.max > 1
            sets = result_values.max
            if disciplines[discipline_name][:sets].blank?
              disciplines[discipline_name][:sets] = sets
              disciplines[discipline_name][:sets_occurence] = 1
            elsif disciplines[discipline_name][:sets] == sets
              disciplines[discipline_name][:sets_occurence] += 1
            elsif disciplines[discipline_name][:sets] != sets
              # Different number of sets found - mark as inconsistent
              disciplines[discipline_name][:sets_no] = party.cc_id
            end
          end

          # Handle balls/score for disciplines that use them
          if balls.present?
            ball_values = balls.split(/\s*:\s*/).map(&:to_i)
            if disciplines[discipline_name][:score].blank? || disciplines[discipline_name][:score].to_i < ball_values.max
              disciplines[discipline_name][:score] = {round_name.to_s => ball_values.max}
            end
          end

          # Handle innings
          if innings.present?
            inning_values = innings.split(/\s*:\s*/).map(&:to_i)
            max_innings = inning_values.max
            if disciplines[discipline_name][:inning].blank? || disciplines[discipline_name][:inning].to_i < max_innings
              disciplines[discipline_name][:inning] = max_innings
              disciplines[discipline_name][:inning_occurence] = 1
            elsif disciplines[discipline_name][:inning] == max_innings
              disciplines[discipline_name][:inning_occurence] += 1
            end
          end

          # Handle partie points (Punkte)
          if point_values.present?
            if point_values[0] == point_values[1] && point_values[0] > 0
              disciplines[discipline_name][:ppu] = point_values[0]
            elsif point_values.max > 1
              disciplines[discipline_name][:ppg] = [disciplines[discipline_name][:ppg].to_i, point_values.max].max
              disciplines[discipline_name][:ppv] = [disciplines[discipline_name][:ppv].to_i, point_values.min].min
            end
          end

          # Track shootout vs non-shootout games
          if /shootout/i.match?(discipline_name)
            game_plan[:victory_to_nil] = [game_plan[:victory_to_nil].to_i, non_shootout_games].max
            non_shootout_games = 0
          else
            non_shootout_games += 1
          end
        end
      end

      # Analyze party-level data for match points
      party_data = party.data || {}
      party_points = party_data[:points] || party_data["points"]

      if party_points.present?
        point_values = party_points.split(":").map(&:strip).map(&:to_i).sort
        if point_values.present?
          game_plan[:match_points][:win] = [game_plan[:match_points][:win].to_i, point_values[1]].max
          game_plan[:match_points][:lost] = [game_plan[:match_points][:lost].to_i, point_values[0]].min

          # Check for shootout in this party
          shootout_games = party.party_games.joins(:discipline).where("disciplines.name ILIKE ?", "%shootout%")
          if shootout_games.any?
            shootout_result = shootout_games.first.data&.dig(:result, "Ergebnis:") || shootout_games.first.data&.dig("result", "Ergebnis:")
            if shootout_result.present? && shootout_result != "0:0"
              game_plan[:extra_shootout_match_points] = {
                win: point_values[1] - point_values[0],
                lost: 0
              }
              game_plan[:match_points][:draw] = point_values.min
            end
          end
        end
      end
    end

    # Update tables count
    tables = [tables, games_per_round].max
    game_plan[:tables] = tables

    # Clean up discipline statistics
    disciplines.each do |discipline_name, stats|
      # Remove inning if it appears less than 3 times
      if stats[:inning_occurence].present? && stats[:inning_occurence] < 3
        stats.delete(:inning)
      end
      stats.delete(:inning_occurence)

      # Remove sets if it appears less than 3 times
      if stats[:sets_occurence].present? && stats[:sets_occurence] < 3
        stats.delete(:sets)
      end
      stats.delete(:sets_occurence)
      stats.delete(:sets_no)

      # Merge discipline stats into game plan rows
      game_plan[:rows] = game_plan[:rows].map do |row|
        if row[:type] == discipline_name
          row.merge(stats).compact
        else
          row
        end
      end
    end

    # Sort the game plan
    game_plan = game_plan.sort.to_h

    # Create or update the GamePlan (shared across seasons)
    footprint = Digest::MD5.hexdigest(game_plan.inspect)
    gp_name = "#{@league.name} - #{@league.branch.name} - #{@league.organizer.shortname}"

    # Look for existing GamePlan with same name (shared across seasons)
    gp = GamePlan.find_by_name(gp_name)
    if gp.present?
      # Update existing GamePlan if data has changed
      gp.assign_attributes(footprint: footprint, data: game_plan)
      gp.data_will_change! if gp.changes["data"].present? && gp.changes["data"][0] != gp.changes["data"][1]
    else
      # Create new GamePlan
      gp = GamePlan.new(name: gp_name, footprint: footprint, data: game_plan)
    end

    if gp.changed?
      gp.region_id = @league.region_id
      gp.global_context = @league.global_context
      gp.save!
      Rails.logger.info "Updated GamePlan: #{gp_name} (ID: #{gp.id})"
    else
      Rails.logger.info "GamePlan unchanged: #{gp_name}"
    end

    # Update league's game_plan reference
    @league.game_plan = gp
    @league.save!

    Rails.logger.info "GamePlan reconstruction completed for league: #{@league.name}"
    gp
  rescue => e
    Rails.logger.error "Error reconstructing GamePlan for league #{@league.name} (ID: #{@league.id}): #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    nil
  end

  # Analyze the structure of a party to extract game plan rows
  def analyze_game_plan_structure(party, game_plan, disciplines)
    Rails.logger.info "Analyzing structure from party #{party.id}"

    # Group party_games by discipline and analyze the structure
    games_by_discipline = party.party_games.group_by(&:discipline)

    games_by_discipline.each do |discipline, games|
      next unless discipline.present?

      discipline_name = discipline.name
      disciplines[discipline_name] ||= {}

      # Create a row for this discipline
      row = {type: discipline_name}

      # Analyze the first game to extract structure information
      first_game = games.first
      if first_game.present?
        game_data = first_game.data || {}
        result_data = game_data[:result] || game_data["result"] || {}

        # Extract basic structure info
        result = result_data["Ergebnis:"] || result_data["Ergebnis"] || "0:0"
        points = result_data["Punkte:"] || result_data["Punkte"] || "0:0"

        # Parse for sets
        result_values = result.split(/\s*:\s*/).map(&:to_i)
        if result_values.present? && result_values.max > 1
          row[:sets] = result_values.max
        end

        # Parse for game points
        point_values = points.split(/\s*:\s*/).map(&:to_i)
        if point_values.present?
          row[:game_points] = {
            win: point_values.max,
            draw: (point_values[0] == point_values[1]) ? point_values[0] : 0,
            lost: point_values.min
          }
        end

        # Extract balls/score if present
        balls = result_data["Bälle:"] || result_data["Bälle"] || result_data["Punkte"] || result_data["Punkte:"]
        if balls.present?
          ball_values = balls.split(/\s*:\s*/).map(&:to_i)
          row[:score] = ball_values.max if ball_values.any?
        end

        # Extract innings if present
        innings = result_data["Aufn.:"] || result_data["Aufn."]
        if innings.present?
          inning_values = innings.split(/\s*:\s*/).map(&:to_i)
          row[:inning] = inning_values.max if inning_values.any?
        end

        # Handle partie points
        if point_values.present?
          if point_values[0] == point_values[1] && point_values[0] > 0
            row[:ppu] = point_values[0]
          elsif point_values.max > 1
            row[:ppg] = point_values.max
            row[:ppv] = point_values.min
          end
        end

        # Track shootout vs non-shootout
        if /shootout/i.match?(discipline_name)
          game_plan[:victory_to_nil] = 0 # Will be updated during full analysis
        end
      end

      game_plan[:rows] << row.compact
    end

    # Add "Gesamtsumme" row at the end
    game_plan[:rows] << {type: "Gesamtsumme"}
  end

  # Class method to reconstruct GamePlans for multiple leagues in a season
  def reconstruct_for_season
    leagues = League.where(season: @season)

    # Filter by region shortname if specified
    if @opts[:region_shortname].present?
      leagues = leagues
        .joins("INNER JOIN regions ON regions.id = leagues.organizer_id AND leagues.organizer_type = 'Region'")
        .where(regions: {shortname: @opts[:region_shortname]})
    end

    # Filter by discipline if specified
    if @opts[:discipline].present?
      discipline_name = @opts[:discipline].to_s.capitalize
      leagues = leagues.joins(:discipline).where(disciplines: {name: discipline_name})
    end

    Rails.logger.info "Starting GamePlan reconstruction for #{leagues.count} leagues in season #{@season.name}"
    if @opts[:region_shortname].present? || @opts[:discipline].present?
      Rails.logger.info "Filters: region=#{@opts[:region_shortname]}, discipline=#{@opts[:discipline]}"
    end

    results = {success: 0, failed: 0, errors: []}

    # Group leagues by their GamePlan name to handle shared GamePlans efficiently
    leagues_by_gameplan = leagues.group_by do |league|
      "#{league.name} - #{league.branch.name} - #{league.organizer.shortname}"
    end

    leagues_by_gameplan.each do |gameplan_name, leagues_group|
      Rails.logger.info "Processing GamePlan group: #{gameplan_name} (#{leagues_group.length} leagues)"

      # Use the first league in the group to reconstruct the GamePlan
      representative_league = leagues_group.first

      begin
        if representative_league.reconstruct_game_plan_from_existing_data
          # Link all leagues in the group to the same GamePlan
          game_plan = representative_league.game_plan
          leagues_group.each do |league|
            league.update_column(:game_plan_id, game_plan.id) unless league.game_plan_id == game_plan.id
          end
          results[:success] += leagues_group.length
        else
          results[:failed] += leagues_group.length
        end
      rescue => e
        results[:failed] += leagues_group.length
        results[:errors] << "GamePlan group #{gameplan_name}: #{e.message}"
        Rails.logger.error "Failed to reconstruct GamePlan for group #{gameplan_name}: #{e.message}"
      end
    end

    Rails.logger.info "GamePlan reconstruction completed. Success: #{results[:success]}, Failed: #{results[:failed]}"
    Rails.logger.info "Errors: #{results[:errors].join(", ")}" if results[:errors].any?

    results
  end

  # Delete existing GamePlans for a season (useful before reconstruction)
  def delete_for_season
    leagues = League.where(season: @season)

    # Filter by region shortname if specified
    if @opts[:region_shortname].present?
      leagues = leagues
        .joins("INNER JOIN regions ON regions.id = leagues.organizer_id AND leagues.organizer_type = 'Region'")
        .where(regions: {shortname: @opts[:region_shortname]})
    end

    # Filter by discipline if specified
    if @opts[:discipline].present?
      discipline_name = @opts[:discipline].to_s.capitalize
      leagues = leagues.joins(:discipline).where(disciplines: {name: discipline_name})
    end

    Rails.logger.info "Deleting GamePlans for #{leagues.count} leagues in season #{@season.name}"
    if @opts[:region_shortname].present? || @opts[:discipline].present?
      Rails.logger.info "Filters: region=#{@opts[:region_shortname]}, discipline=#{@opts[:discipline]}"
    end

    deleted_count = 0
    leagues.find_each do |league|
      if league.game_plan.present?
        game_plan_name = league.game_plan.name
        league.game_plan.destroy
        league.update_column(:game_plan_id, nil)
        deleted_count += 1
        Rails.logger.info "Deleted GamePlan: #{game_plan_name}"
      end
    end

    Rails.logger.info "Deleted #{deleted_count} GamePlans for season #{@season.name}"
    deleted_count
  end

  # Find leagues that should share the same GamePlan
  def find_leagues_with_same_gameplan(league)
    return [] unless league.organizer.present? && league.discipline.present?

    League.where(
      name: league.name,
      organizer: league.organizer,
      discipline: league.discipline
    ).where.not(id: league.id)
  end

  # Find or create shared GamePlan for leagues with same structure
  def find_or_create_shared_gameplan(league)
    return nil unless league.organizer.present? && league.discipline.present?

    # Look for existing GamePlan with same name (shared across seasons)
    gp_name = "#{league.name} - #{league.branch.name} - #{league.organizer.shortname}"
    GamePlan.find_by_name(gp_name)
  end
end
