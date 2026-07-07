# frozen_string_literal: true

class SearchService < ApplicationService
  include FiltersHelper
  def initialize(options = {})
    super()
    @model = options[:model]
    @sort = options[:sort]
    @direction = options[:direction]
    @sSearch = options[:search].to_s.gsub(/&/, "%26")
    @column_names = options[:column_names]
    @raw_sql = options[:raw_sql]
    @joins = options[:joins]
    @distinct = options[:distinct]
  end

  def call
    results = @model
    results = results.joins(@joins) if @joins
    results = results.sort_by_params(@sort, @direction)
    results = results.distinct if @distinct
    results = apply_scope(results)
    results = apply_drill(results)

    if @sSearch.present?
      results_no_query = results
      results = apply_filters(results, @column_names, @raw_sql)
    end
    results
  end

  private

  # Drill-down-Kontext (Current.drill, z.B. { "club_id" => id }): filtert den Parent-FK DIREKT
  # (where(fk => id)), getrennt vom Scope-Band. Bewusst OHNE die apply_scope-Facetten-Spezial-Logik
  # (club_id-Join), damit der Drill auch Modelle wie SeasonParticipation/LeagueTeam filtert. Defensiv:
  # nur vorhandene Spalten, praesente Werte.
  def apply_drill(results)
    drill = Current.drill
    return results if drill.blank?

    cols = @model.column_names
    drill.each do |column, value|
      col = column.to_s
      next if value.blank? || !cols.include?(col)
      results = results.where(col => value)
    end
    results
  end

  # Globaler Ausschnitt (Scope-Band): FK-Filter (region_id/season_id/...) aus Current.scope,
  # nur wo das Modell die Spalte fuehrt. Unabhaengig von der User-Suche (@sSearch).
  #
  # Region-Sonderregel (analog Version#for_region): global_context-Records (einer Region
  # zugeordnet, aber regionsuebergreifend gueltig — z.B. DBU-Ligen mit Mannschaften aus
  # mehreren Regionen) werden vom Region-Filter NIE ausgeschlossen.
  def apply_scope(results)
    scope = Current.scope
    return results if scope.blank?
    # Picker-/Einstiegs-Listen (Region) sind vom globalen Scope ausgenommen -> nie selbst filtern.
    return results if @model.respond_to?(:scope_exempt?) && @model.scope_exempt?

    cols = @model.column_names
    table = @model.table_name
    scope.each do |column, value|
      next if value.blank?
      col = column.to_s

      # Club: join-basiert, saison-gebunden. Fuer Modelle mit season_participations (Player) ist die
      # direkte players.club_id-Spalte unzuverlaessig -> ueber die Assoziation filtern (club_id +
      # season_id = Scope-Saison), distinct. Andere Modelle ohne die Assoziation ignorieren club_id.
      if col == "club_id"
        next unless @model.reflect_on_association(:season_participations)

        results = results.joins(:season_participations)
                         .where(season_participations: { club_id: value })
        season = scope["season_id"]
        if season.present? && SeasonParticipation.column_names.include?("season_id")
          results = results.where(season_participations: { season_id: season })
        end
        results = results.distinct
        next
      end

      next unless cols.include?(col)

      results = if col == "region_id" && cols.include?("global_context")
                  # Strikte Modelle (Location/Player/Club) zeigen ausschliesslich die eigene Region;
                  # global_context ist dort ein Sync-Retention-Marker, kein Anzeige-Praedikat und wird
                  # nie eingeblendet. Nicht-strikte Modelle (Ligen/Turniere) inkludieren global_context
                  # immer (regionsuebergreifend gueltige Records, z.B. DBU-Ligen).
                  strict = @model.respond_to?(:scope_region_strict?) && @model.scope_region_strict?
                  if strict
                    results.where("#{table}.region_id = :r", r: value)
                  else
                    results.where("#{table}.region_id = :r OR #{table}.global_context = TRUE", r: value)
                  end
                else
                  results.where(col => value)
                end
    end
    results
  end
end
