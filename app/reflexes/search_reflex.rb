# frozen_string_literal: true

# Generalized search reflex for handling search fields with immediate
# response on any change of the inputs
class SearchReflex < ApplicationReflex
  include Rails.application.routes.url_helpers

  before_reflex do
    # session[:"s_#{params[:controller]}"] = params[:sSearch] if params.has_key?(:sSearch)
    # @sSearch = session[:"s_#{params[:controller]}"] if params[:action] == "index"
  end

  include Pagy::Backend
  DEBUG = true

  def perform
    Rails.application.routes.default_url_options[:host] = request.base_url
    model_name = params[:controller].camelize.singularize
    @model = model_name.constantize

    # Store search parameters
    session["#{model_name.underscore}_search"] ||= {}

    # Suchstring aus dem AUSLOESENDEN Element lesen, nicht aus der Form-Serialisierung.
    # data-reflex-serialize-form lieferte waehrend des Morphs zeitweise den
    # server-gerenderten Leerwert (value="", weil @sSearch nil ist) statt des getippten
    # Werts -> params[:sSearch] kam leer an und die Live-Suche filterte nicht
    # (Diagnose: .planning/debug/live-search-empty-ssearch.md).
    # Der SR-Client setzt attrs.value immer aus dem live .value-Property des Triggers
    # (stimulus_reflex/javascript/attributes.js:72) -> race-frei.
    #
    # Leerstring ist ein GUELTIGER Wert (Suchfeld geleert = Filter zuruecksetzen),
    # daher kein present?-Guard: der alte Guard liess einen geleerten Suchbegriff in
    # der Session stehen, die Liste blieb gefiltert.
    typed_search = element.value
    search_string = typed_search.nil? ? params[:sSearch].to_s : typed_search.to_s
    session["#{model_name.underscore}_search"][:sSearch] = search_string
    # Kanonischer Schluessel des HTTP-Pfads: ApplicationController und
    # SortableHelper#sortable lesen session[:"s_<controller>"]. Ohne ihn verlieren
    # Sortier-Links und der naechste HTTP-Request den Suchbegriff, sobald der
    # Controller nicht mehr per Page-Morph mitlaeuft (siehe Selector-Morph unten).
    session[:"s_#{params[:controller]}"] = search_string

    # Handle sorting parameters
    if params[:sort].present?
      session["#{model_name.underscore}_search"][:sort] = params[:sort]
      session["#{model_name.underscore}_search"][:direction] = params[:direction] || 'asc'
    end

    # Get search parameters from session
    search_params = session["#{model_name.underscore}_search"].symbolize_keys

    # Set @sSearch for FiltersHelper
    @sSearch = search_params[:sSearch]

    # Globaler Ausschnitt (Scope-Band): der Reflex laeuft ueber ActionCable und NICHT durch
    # ApplicationController#set_current_scope -> Current.scope waere sonst nil und die Live-Suche
    # ignorierte den Ausschnitt. Gleiche Ableitung wie im HTTP-Pfad (ScopeResolver).
    Current.scope = ScopeResolver.new(session_scope: session[:scope], user: current_user).fk_scope

    # Drill-down-Kontext (Ankunftskontext): der Reflex laeuft ueber ActionCable und NICHT durch
    # Scopable#set_current_scope -> Current.drill waere sonst nil und die Live-Suche im Drill
    # verlaere den Parent-Filter (zeigte alle Datensaetze). Gleiche Ableitung wie Scopable#drill_focus_params
    # (Allowlist Scopable::DRILL_FOCUS_KEYS gegen Column-Injection). apply_drill (SearchService) liest Current.drill.
    raw_drill = params[:drill]
    Current.drill =
      if raw_drill.respond_to?(:to_unsafe_h)
        raw_drill.to_unsafe_h
      elsif raw_drill.is_a?(Hash)
        raw_drill
      else
        {}
      end.stringify_keys.slice(*Scopable::DRILL_FOCUS_KEYS)

    # Perform search
    results = SearchService.call(@model.search_hash(search_params))

    # Paginate results
    pagy, records = pagy(results)
    records.load

    Rails.logger.info "Rendering table with #{records.size} records"

    # Send instance variables to view
    instance_variable_set("@#{model_name.underscore.pluralize}", records)
    instance_variable_set("@pagy", pagy)
    instance_variable_set("@search_params", search_params)

    # Render partial: das tatsaechlich von der Index-Seite gerenderte table_partial (Default _table),
    # damit die Live-Suche das richtige DOM-Ziel morpht (UAT-001; tournaments/index rendert tournaments_list).
    table_partial = element.dataset["table-partial"].presence || "#{model_name.underscore.pluralize}_table"

    # Selector-Morph statt Page-Morph. Der Page-Morph liess den Controller erneut
    # laufen; dessen before_action ueberschrieb @sSearch aus dem (leeren)
    # params[:sSearch] und verwarf damit das komplette Reflex-Ergebnis — die Suche
    # oben war faktisch wirkungslos. Der gezielte Morph macht den Reflex autoritativ
    # und rendert nur noch die Ergebnisliste statt bei jedem Tastendruck die ganze
    # Seite (der Page-Morph war zugleich das Performance-Thema aus der Diagnose).
    morph "#table_wrapper", render(partial: "shared/search_results_frame", locals: {
      records: records,
      table_partial: table_partial,
      search_string: @sSearch,
      table_locals: {pagy: @pagy, model_class: @model, records: records}
    })
  end
end
