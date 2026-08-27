class RankingsController < ApplicationController
  # Verlaufsdiagramm: ab welcher Saison und wie viele Spieler je Disziplin
  BTG_HISTORY_FIRST_SEASON = "2010/2011"
  BTG_HISTORY_PLAYER_COUNT = 20
  # Bundesweite Ansicht: weniger Spieler (der Median ist dort die Hauptaussage) und nur
  # Disziplinen, die in mindestens zwei Verbaenden gespielt werden -- sonst gibt es nichts
  # zu vergleichen.
  NATIONAL_PLAYER_COUNT = 10
  NATIONAL_MIN_REGIONS = 2
  # Dachverband (DBU) -- eigene Ebene, nicht mit den Landesverbaenden verrechnen.
  ROOF_SHORTNAMES = Region::SHORTNAMES_ROOF_ORGANIZATION

  def index
    @regions = Region.having_rankings
                    .includes(:country)
                    .order(:name)
  end

  def show
    @region = Region.find(params[:id])
    @current_season = Season.current_season

    # Die letzten 3 Saisons, chronologisch aufsteigend. Recency ueber den Saison-NAMEN
    # (id/ba_id sind durch internationales Scrapen verrutscht).
    @seasons = Season.recent_valid(3, up_to: @current_season)

    # 1. Aggregate discipline counts for games with a valid data["Disziplin"]
    counts_with_data = Game.joins(tournament: :discipline)
                           .where(tournaments: {
                             organizer_type: 'Region',
                             organizer_id: @region.id,
                             season_id: @seasons.pluck(:id)
                           })
                           .where.not(games: { data: nil }) # Ensure data is not nil
                           .where("games.data::jsonb ->> 'Disziplin' != ''") # Ensure Disziplin is not empty
                           .group("LOWER(TRIM(games.data::jsonb ->> 'Disziplin'))")
                           .order(Arel.sql('COUNT(*) DESC'))
                           .count

    # 2. Aggregate discipline counts for games without a valid data["Disziplin"]
    counts_without_data = Game.joins(tournament: :discipline)
                              .where(tournaments: {
                                organizer_type: 'Region',
                                organizer_id: @region.id,
                                season_id: @seasons.pluck(:id)
                              })
                              .where("games.data::jsonb ->> 'Disziplin' IS NULL OR TRIM(games.data::jsonb ->> 'Disziplin') = ''")
                              .group("LOWER(disciplines.name)")
                              .order(Arel.sql('COUNT(*) DESC'))
                              .count

    # 3. Merge the two counts, summing the counts for overlapping disciplines
    discipline_counts = counts_with_data.merge(counts_without_data) do |key, old_count, new_count|
      old_count + new_count
    end

    # Extract the discipline names from the counts
    discipline_names = discipline_counts.keys

    # Fetch Discipline records in bulk matching the normalized discipline names
    disciplines = Discipline.where("LOWER(name) IN (?)", discipline_names)
                            .index_by { |d| d.name.downcase.strip }

    # Sort disciplines based on counts descending
    @disciplines = discipline_counts.sort_by { |name, _count| -_count }
                                   .map { |name, _count| disciplines[name] }
                                   .compact

    # Fetch all player rankings for the region and seasons
    player_rankings = PlayerRanking.joins(:player)
                               .includes(player: { season_participations: :club})
                               .where(season_id: @seasons.pluck(:id))
                               .where(region_id: @region.id) # Filter by region
                               .to_a

    # Initialize @rankings_by_player by grouping rankings by player and discipline
    @rankings_by_player = player_rankings.group_by { |r| [r.player_id, r.discipline_id] }

    # Prefetch all players
    player_ids = @rankings_by_player.keys.map(&:first).uniq
    @players = Player.where(id: player_ids).includes(:season_participations).index_by(&:id)
    
    # Prefetch all season participations for the current season
    @latest_season_participations = SeasonParticipation.where(
      season: @current_season, 
      player_id: player_ids
    ).includes(:club).index_by(&:player_id)
    
    # Prefetch all clubs
    club_ids = @latest_season_participations.values.map(&:club_id).compact.uniq
    @clubs = Club.where(id: club_ids).index_by(&:id)

    # Precompute effective_gd for each player-discipline pair
    @effective_gd_by_player_discipline = {}
    @gd_values_by_player_discipline = {}
    
    @rankings_by_player.each do |(player_id, discipline_id), rankings|
      # Map seasons to GD values in chronological order
      gd_values = @seasons.map do |season|
        ranking = rankings.find { |r| r.season_id == season.id }
        [ranking&.gd, ranking&.btg]
      end
      
      # Calculate effective GD (current || previous || previous-1)
      effective_gd = gd_values[2]&.first || gd_values[1]&.first || gd_values[0]&.first
      
      @gd_values_by_player_discipline[[player_id, discipline_id]] = gd_values
      @effective_gd_by_player_discipline[[player_id, discipline_id]] = effective_gd
    end

    # Prepare sorted player data for each discipline
    @sorted_player_data_by_discipline = {}
    
    @disciplines.each do |discipline|
      player_data = @rankings_by_player.select { |(_pid, did), _| did == discipline.id }.map do |(player_id, discipline_id), rankings|
        player = @players[player_id]
        club = @latest_season_participations[player_id]&.club_id ? @clubs[@latest_season_participations[player_id].club_id] : nil
        effective_gd = @effective_gd_by_player_discipline[[player_id, discipline_id]]
        
        {
          player: player,
          club: club,
          rankings: rankings,
          gd_data: {
            gd_values: @gd_values_by_player_discipline[[player_id, discipline_id]],
            effective_gd: effective_gd
          }
        }
      end
      
      # Sort and filter player data
      sorted_data = player_data.reject { |r| r[:gd_data][:effective_gd].nil? }
                             .sort_by { |r| -r[:gd_data][:effective_gd] }
      
      @sorted_player_data_by_discipline[discipline.id] = sorted_data
    end

    # Pre-calculate game data for charts with optimizations to prevent browser hangs
    @chart_data = {}

    # Get only the necessary player and discipline combinations that appear in the rankings
    player_discipline_pairs = @rankings_by_player.keys

    # Use a more efficient query to get all needed game participations in one go
    player_ids = player_discipline_pairs.map(&:first).uniq

    # Fetch all relevant GameParticipations in a single query with limit to prevent memory issues
    game_participations = GameParticipation.joins(game: :tournament)
                                          .where(
                                            tournaments: {
                                              organizer_type: 'Region',
                                              organizer_id: @region.id,
                                              season_id: @seasons.pluck(:id)
                                            },
                                            player_id: player_ids
                                          )
                                          .includes(:player, game: { tournament: :discipline })
                                          .order('tournaments.date DESC')
    # .limit(10000) # Safety limit

    # Pre-group GameParticipations by [player_id, tournament_id] to optimize processing
    grouped_game_participations = game_participations.group_by { |gp| [gp.player_id, gp.game.tournament_id] }

    # Process only a reasonable number of tournaments per player to prevent browser hangs
    processed_count = 0
    max_tournaments_per_player = 25  # Limit number of tournaments per player

    grouped_game_participations.each do |(player_id, tournament_id), gps_in_tournament|
      # Skip after a reasonable number of data points
      processed_count += 1
      if processed_count > 1000
        Rails.logger.warn "Reached maximum tournament processing limit (1000). Some charts may be incomplete."
        break
      end

      # Define a local variable for tournament_date based on the tournament_id
      tournament_date = gps_in_tournament.first.game.tournament.date.iso8601

      # Extract disciplines present in this group
      disciplines_in_group = gps_in_tournament.map { |gp_inner| gp_inner.game.data["Disziplin"].to_s.downcase.strip }
                                           .uniq

      disciplines_in_group.each do |discipline_name|
        discipline = @disciplines.find { |d| d.name.downcase.strip == discipline_name }

        # Skip if discipline is not found
        unless discipline.present?
          next
        end

        # Use a string as the key
        key = "#{player_id},#{discipline.id}"

        # Skip if this player-discipline pair isn't in our rankings
        next unless player_discipline_pairs.include?([player_id, discipline.id])

        # Skip if we've already processed enough tournaments for this player-discipline
        if @chart_data[key] && @chart_data[key][:tournaments].size >= max_tournaments_per_player
          next
        end

        @chart_data[key] ||= { individual_games: [], tournaments: [] }

        # Select GameParticipations matching the player, tournament, and discipline
        gps_matching = gps_in_tournament.select do |gp_inner|
          gp_inner.game.data["Disziplin"].to_s.downcase.strip == discipline_name
        end

        # Calculate average_gd for the tournament, handling division by zero
        average_gd = gps_matching.present? ? gps_matching.map(&:gd).compact.sum.to_f / gps_matching.size : 0

        # Add individual game data (limit to avoid browser overload)
        if @chart_data[key][:individual_games].size < 200  # Limit individual games
          gps_matching.each do |gp|
            # Use tournament date instead of game date
            tournament = gp.game.tournament
            @chart_data[key][:individual_games] << [tournament.date.iso8601, gp.gd, tournament.id]
          end
        end

        # Add to tournaments array with the correct tournament_date and ID
        if @chart_data[key][:tournaments].size < max_tournaments_per_player
          @chart_data[key][:tournaments] << {
            id: gps_in_tournament.first.game.tournament_id,
            date: tournament_date,
            average: average_gd
          }
        end
      end
    end

    # Initialize missing @chart_data keys for all player-discipline combinations
    player_discipline_pairs.each do |key_array|
      player_id, discipline_id = key_array
      key = "#{player_id},#{discipline_id}"
      @chart_data[key] ||= { individual_games: [], tournaments: [] }
    end

    # Sort the data chronologically to ensure proper chart display
    @chart_data.each do |_key, data|
      begin
        # Sort individual games by date
        data[:individual_games].sort_by! { |date, _| date } if data[:individual_games].present?

        # Sort tournaments by date
        data[:tournaments].sort_by! { |t| t[:date] } if data[:tournaments].present?

        # Limit data size to prevent browser hangs
        data[:individual_games] = data[:individual_games].last(150) if data[:individual_games].size > 150
        data[:tournaments] = data[:tournaments].last(25) if data[:tournaments].size > 25
      rescue => e
        Rails.logger.error "Error sorting chart data: #{e.message}"
      end
    end

    # BTG-Verlauf der aktuell besten Spieler je Disziplin (Verlaufsdiagramm ueber der Tabelle)
    @btg_chart_by_discipline = build_btg_history(@region)
  end

  # Bundesweiter Vergleich: je Disziplin die besten Spieler Deutschlands, darueber der
  # Median Deutschlands als Bezugslinie, dazu die Mediane der einzelnen Landesverbaende.
  def germany
    @national_by_discipline = build_national_history
  end

  private

  # Baut je Disziplin den BTG-Verlauf der aktuell besten Spieler seit BTG_HISTORY_FIRST_SEASON.
  # "Aktuell" meint die juengste Saison, fuer die ueberhaupt Rankings vorliegen -- die laufende
  # Saison ist in der Regel noch leer (Rankings entstehen erst im Saisonverlauf).
  # Rueckgabe: { discipline_id => { seasons: [...], players: [{ id:, name:, values: [...] }] } }
  # values enthaelt je Saison den BTG oder nil; nil laesst die Linie im Diagramm unterbrechen.
  def build_btg_history(region)
    rows = PlayerRanking
      .joins(:season)
      .where(region_id: region.id)
      .where.not(btg: nil)
      .where("seasons.name >= ?", BTG_HISTORY_FIRST_SEASON)
      .pluck(:discipline_id, :player_id, "seasons.name", :btg)
    return {} if rows.empty?

    season_names = rows.map { |r| r[2] }.uniq.sort
    latest_season = season_names.last
    players_by_id = Player.where(id: rows.map { |r| r[1] }.uniq).index_by(&:id)

    rows.group_by(&:first).each_with_object({}) do |(discipline_id, discipline_rows), acc|
      top_ids = discipline_rows.select { |r| r[2] == latest_season }
                               .sort_by { |r| -r[3] }
                               .first(BTG_HISTORY_PLAYER_COUNT)
                               .map { |r| r[1] }
      next if top_ids.empty?

      rows_by_player = discipline_rows.group_by { |r| r[1] }
      acc[discipline_id] = {
        seasons: season_names,
        players: top_ids.map do |player_id|
          btg_by_season = rows_by_player[player_id].to_h { |r| [r[2], r[3]] }
          {
            id: player_id,
            name: players_by_id[player_id]&.fl_name || "##{player_id}",
            values: season_names.map { |name| btg_by_season[name]&.round(3) }
          }
        end
      }
    end
  end

  # No longer needed as we precompute this in the controller
  # def calculate_three_year_gd(player_id, discipline_id)
  #   rankings = @rankings_by_player[[player_id, discipline_id]] || []
  #
  #   # Map seasons to GD values in chronological order
  #   gd_values = @seasons.map do |season|
  #     ranking = rankings.find { |r| r.season_id == season.id }
  #     [ranking&.gd, ranking&.btg]
  #   end
  #
  #   # Calculate effective GD (current || previous || previous-1)
  #   effective_gd = gd_values[2]&.first || gd_values[1]&.first || gd_values[0]&.first
  #
  #   {
  #     gd_values: gd_values,
  #     effective_gd: effective_gd
  #   }
  # end
  # helper_method :calculate_three_year_gd

  # Median statt Mittelwert: ein Viertel der Rankings stammt aus einem einzigen Turnier,
  # ein Glueckstreffer wuerde einen Verband sonst nach oben ziehen.
  def median(values)
    return nil if values.blank?

    sorted = values.compact.sort
    return nil if sorted.empty?

    middle = sorted.size / 2
    sorted.size.odd? ? sorted[middle] : ((sorted[middle - 1] + sorted[middle]) / 2.0)
  end

  # Je Disziplin: Median Deutschland, Median je Landesverband und die besten Spieler
  # bundesweit -- alles ueber dieselben Saisons, damit die Linien vergleichbar liegen.
  # Rueckgabe: [{ id:, name:, seasons:, national_median:, regions: [...], players: [...] }]
  def build_national_history
    rows = PlayerRanking
      .joins(:season, :region)
      .where.not(btg: nil)
      .where("seasons.name >= ?", BTG_HISTORY_FIRST_SEASON)
      .pluck(:discipline_id, :player_id, "seasons.name", :btg, "regions.shortname")
    return [] if rows.empty?

    players_by_id = Player.where(id: rows.map { |r| r[1] }.uniq).index_by(&:id)
    disciplines_by_id = Discipline.where(id: rows.map(&:first).uniq).index_by(&:id)

    rows.group_by(&:first).filter_map do |discipline_id, discipline_rows|
      # Der Dachverband ist KEIN Landesverband: Bei der DBU spielen die Qualifizierten, nicht
      # der Querschnitt -- ihr Median liegt entsprechend hoeher (Dreiband klein 2025/26: 0,98
      # gegen 0,56-0,85 der Laender). Sie wuerde den Vergleich verzerren und faelschlich als
      # staerkster "Verband" erscheinen. Zudem sind Spieler doppelt gelistet (16 von 39), was
      # den Bundesmedian nach oben zoege. Deshalb: raus aus Median und Verbandsliste, dafuer
      # als eigene Bezugslinie "nationales Niveau".
      roof, regional = discipline_rows.partition { |r| ROOF_SHORTNAMES.include?(r[4]) }
      next if regional.map { |r| r[4] }.uniq.size < NATIONAL_MIN_REGIONS

      seasons = discipline_rows.map { |r| r[2] }.uniq.sort
      latest = seasons.last
      regional_by_season = regional.group_by { |r| r[2] }
      roof_by_season = roof.group_by { |r| r[2] }

      # uniq nach sort_by: ein Spieler nur einmal, mit seinem besten Wert
      top_rows = discipline_rows
        .select { |r| r[2] == latest }
        .sort_by { |r| -r[3] }
        .uniq { |r| r[1] }
        .first(NATIONAL_PLAYER_COUNT)
      next if top_rows.empty?

      rows_by_player = discipline_rows.group_by { |r| r[1] }

      {
        id: discipline_id,
        name: disciplines_by_id[discipline_id]&.name || "##{discipline_id}",
        seasons: seasons,
        national_median: seasons.map { |name| median(regional_by_season[name]&.map { |r| r[3] })&.round(3) },
        roof_median: roof.empty? ? nil : seasons.map { |name| median(roof_by_season[name]&.map { |r| r[3] })&.round(3) },
        roof_name: roof.first&.at(4),
        regions: regional.group_by { |r| r[4] }.map { |shortname, region_rows|
          per_season = region_rows.group_by { |r| r[2] }
          {
            name: shortname,
            values: seasons.map { |name| median(per_season[name]&.map { |r| r[3] })&.round(3) }
          }
        }.sort_by { |r| r[:name] },
        players: top_rows.map { |row|
          player_id = row[1]
          # Ein Spieler kann pro Saison zwei Werte haben (Landesverband + DBU). Fuer eine
          # Bestenliste zaehlt die bessere Leistung, sonst entstuenden Zacken aus dem Wechsel
          # zwischen den Ebenen.
          btg_by_season = rows_by_player[player_id]
            .group_by { |r| r[2] }
            .transform_values { |rs| rs.map { |r| r[3] }.compact.max }
          {
            id: player_id,
            name: players_by_id[player_id]&.fl_name || "##{player_id}",
            region: row[4],
            values: seasons.map { |name| btg_by_season[name]&.round(3) }
          }
        }
      }
    end.sort_by { |d| -d[:players].size }.tap { |result| label_players_with_home_region!(result) }
  end

  # Der Spitzenwert eines Top-Spielers stammt meist aus der DBU-Rangliste -- dann stuende dort
  # als Herkunft "DBU", was wie eine Vereinszugehoerigkeit gelesen wird und nichts aussagt.
  # Ersetzt wird deshalb nur dieses Label, und zwar ueber den Verein: Er liefert den
  # Heimatverband auch fuer Spieler, die in keiner Landesrangliste dieser Disziplin stehen
  # (7 von 7 gepruefte Faelle; ueber Ranglisten waeren es nur 3 gewesen).
  def label_players_with_home_region!(disciplines)
    roof_player_ids = disciplines.flat_map do |d|
      d[:players].select { |pl| ROOF_SHORTNAMES.include?(pl[:region]) }.map { |pl| pl[:id] }
    end.uniq
    return if roof_player_ids.empty?

    # order deterministisch, falls ein Spieler mehrere Teilnahmen pro Saison hat
    home_by_player = SeasonParticipation
      .where(player_id: roof_player_ids)
      .includes(club: :region)
      .order(season_id: :desc, id: :desc)
      .each_with_object({}) do |sp, acc|
        shortname = sp.club&.region&.shortname
        acc[sp.player_id] ||= shortname if shortname.present?
      end

    disciplines.each do |d|
      d[:players].each do |player|
        next unless ROOF_SHORTNAMES.include?(player[:region])

        player[:region] = home_by_player[player[:id]] || player[:region]
      end
    end
  end
end
