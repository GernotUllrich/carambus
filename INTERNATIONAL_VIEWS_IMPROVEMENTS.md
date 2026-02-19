# Verbesserungen für Internationale Turniere Views

**Datum:** 19. Februar 2026  
**Status:** In Arbeit

---

## 🎯 Identifizierte Probleme

### 1. Disziplin-Zuordnung beim Scraping
**Problem:** Alle internationalen Turniere bekommen aktuell `discipline_id: 10` ("Dreiband halb")

**Ursache:**
- UMB scrapt nicht die korrekte Disziplin aus den PDFs
- Hardcoded in `UmbScraper` oder falsche Mapping-Logik

**Lösung:**
- UMB-PDFs enthalten meist "3-Cushion" im Titel
- Mapping-Logik basierend auf Turniername erstellen
- Fallback auf "Dreiband halb" (discipline_id: 10)

### 2. Disziplin-Filter zu fein
**Problem:** 
```
10 | Cadre 57/2
11 | Einband halb
12 | Dreiband halb
31 | Dreiband groß
33 | Dreiband klein
34 | Freie Partie klein
35 | Cadre 35/2
36 | Cadre 52/2
37 | Einband klein
38 | Freie Partie groß
39 | Cadre 71/2
40 | Cadre 47/2
...
```

**Lösung:** Hierarchische Gruppierung

```
Karambol
├─ Dreiband (3-Cushion)
│  ├─ Match Billard (halb)  → discipline_id: 12
│  ├─ Groß                   → discipline_id: 31
│  └─ Klein                  → discipline_id: 33
├─ Einband (1-Cushion)
│  ├─ Halb                   → discipline_id: 11
│  ├─ Groß                   → discipline_id: 32
│  └─ Klein                  → discipline_id: 37
├─ Freie Partie (Straight Rail)
│  ├─ Klein                  → discipline_id: 34
│  └─ Groß                   → discipline_id: 38
└─ Cadre (Balkline)
   ├─ 35/2                   → discipline_id: 35
   ├─ 47/2                   → discipline_id: 40
   ├─ 52/2                   → discipline_id: 36
   ├─ 57/2                   → discipline_id: 10
   └─ 71/2                   → discipline_id: 39

Pool Billard
├─ 8-Ball
├─ 9-Ball
├─ 10-Ball
└─ 14/1

5-Pin Billards              → discipline_id: 26
Snooker                     → discipline_id: 24
```

###3. Fehlende tabellarische "Alle"-Ansicht
**Problem:** Nur Grid-View verfügbar

**Lösung:** 
- Toggle zwischen Grid und Table View
- Table View: Jahr/Monat gruppiert
- Sortierbar nach: Datum, Name, Typ, Ort

---

## 📋 Umsetzungsplan

### Phase 1: Disziplin-Mapping beim Scraping (HOCH Priorität)

**1.1 UmbScraper erweitern:**
```ruby
# app/services/umb_scraper.rb oder umb_scraper_v2.rb

def detect_discipline_from_tournament(tournament_data)
  title = tournament_data[:name].to_s.downcase
  
  case title
  when /3-?cushion|drei ?band|three ?cushion|3-bandes|3-?banden/i
    # Dreiband Match Billard (Standard für internationale Turniere)
    Discipline.find_by(name: 'Dreiband halb')&.id || 12
    
  when /5-?pin/i
    # 5-Pin Billards
    Discipline.find_by(name: '5-Pin Billards')&.id || 26
    
  when /1-?cushion|ein ?band|one ?cushion/i
    # Einband
    Discipline.find_by(name: 'Einband halb')&.id || 11
    
  when /straight ?rail|libre|freie ?partie/i
    # Freie Partie
    Discipline.find_by(name: 'Freie Partie klein')&.id || 34
    
  when /cadre|balkline|(\d+)\/(\d+)/i
    # Cadre - welches?
    Discipline.find_by(name: 'Cadre 47/2')&.id || 40
    
  else
    # Default: Dreiband halb (Standard für internationale 3-Cushion Turniere)
    12
  end
end
```

**1.2 Scraper anpassen:**
```ruby
# Beim Erstellen des Tournaments:
tournament = Tournament.new(
  type: 'InternationalTournament',
  title: data[:name],
  discipline_id: detect_discipline_from_tournament(data), # <-- NEU
  # ... rest
)
```

### Phase 2: Hierarchische Filter (MITTEL Priorität)

**2.1 Discipline Model erweitern:**
```ruby
# app/models/discipline.rb

# Gruppierungs-Konstante
DISCIPLINE_GROUPS = {
  'Karambol' => {
    'Dreiband (3-Cushion)' => [12, 31, 33], # halb, groß, klein
    'Einband (1-Cushion)' => [11, 32, 37],
    'Freie Partie' => [34, 38],
    'Cadre' => [35, 36, 39, 40, 10]
  },
  'Pool Billard' => {
    'Alle Pool' => [23] # Pool ist aktuell nur eine Disziplin
  },
  '5-Pin Billards' => {
    'Alle 5-Pin' => [26]
  },
  'Snooker' => {
    'Alle Snooker' => [24]
  }
}.freeze

def self.grouped_for_international
  DISCIPLINE_GROUPS.map do |category, subcategories|
    [
      category,
      subcategories.map do |subcat, ids|
        disciplines = where(id: ids).order(:name)
        [subcat, disciplines.map { |d| [d.name, d.id] }]
      end
    ]
  end
end
```

**2.2 Controller erweitern:**
```ruby
# app/controllers/international/tournaments_controller.rb

def index
  @tournaments = Tournament.international
                           .includes(:discipline, :international_source)
                           .order(date: :desc)
  
  # NEW: Hierarchische Disziplinen
  @discipline_groups = Discipline.grouped_for_international
  
  # Filter
  @tournaments = @tournaments.by_type(params[:type])
  @tournaments = @tournaments.where(discipline_id: params[:discipline_id]) if params[:discipline_id].present?
  @tournaments = @tournaments.in_year(params[:year])
  @tournaments = @tournaments.official_umb if params[:official_umb] == '1'
  
  # View Mode
  @view_mode = params[:view] || 'grid' # 'grid' oder 'table'
  
  # Pagination
  @pagy, @tournaments = pagy(@tournaments, items: (@view_mode == 'table' ? 50 : 20))
  
  @tournament_types = InternationalTournament::TOURNAMENT_TYPES
end
```

### Phase 3: Table View hinzufügen (MITTEL Priorität)

**3.1 Partial erstellen:**
```erb
<!-- app/views/international/tournaments/_table_view.html.erb -->
<div class="bg-white rounded-lg shadow-md overflow-hidden">
  <%
    # Gruppierung nach Jahr/Monat
    tournaments_by_month = tournaments.group_by { |t| [t.date.year, t.date.month] }
    tournaments_by_month = tournaments_by_month.sort.reverse
  %>
  
  <% tournaments_by_month.each do |(year, month), month_tournaments| %>
    <div class="border-b border-gray-200 last:border-b-0">
      <!-- Monats-Header -->
      <div class="bg-gray-50 px-6 py-3 sticky top-0 z-10">
        <h3 class="text-lg font-semibold text-gray-900">
          <%= Date.new(year, month, 1).strftime('%B %Y') %>
          <span class="ml-2 text-sm font-normal text-gray-500">
            (<%= month_tournaments.count %> tournaments)
          </span>
        </h3>
      </div>
      
      <!-- Monats-Tabelle -->
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Date</th>
            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Tournament</th>
            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Type</th>
            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Location</th>
            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Discipline</th>
            <th class="px-4 py-2 text-center text-xs font-medium text-gray-500 uppercase">Videos</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-100">
          <% month_tournaments.each do |tournament| %>
            <tr class="hover:bg-gray-50">
              <td class="px-4 py-3 text-sm text-gray-600 whitespace-nowrap">
                <%= tournament.date.strftime('%d.%m.%Y') %>
              </td>
              <td class="px-4 py-3">
                <%= link_to tournament.name, international_tournament_path(tournament), 
                    class: 'text-blue-600 hover:text-blue-800 font-medium' %>
                <% if tournament.official_umb? %>
                  <span class="ml-2 inline-flex items-center px-2 py-0.5 text-xs font-semibold bg-blue-100 text-blue-800 rounded">
                    UMB
                  </span>
                <% end %>
              </td>
              <td class="px-4 py-3 text-sm text-gray-600">
                <span class="<%= tournament_type_badge_class(tournament.tournament_type) %> px-2 py-1 rounded text-xs">
                  <%= tournament.tournament_type&.humanize || '-' %>
                </span>
              </td>
              <td class="px-4 py-3 text-sm text-gray-600">
                <%= tournament.location || '-' %>
              </td>
              <td class="px-4 py-3 text-sm text-gray-600">
                <%= tournament.discipline.name %>
              </td>
              <td class="px-4 py-3 text-sm text-gray-600 text-center">
                <% if tournament.videos.count > 0 %>
                  <span class="inline-flex items-center text-blue-600">
                    <svg class="w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
                      <path d="M2 6a2 2 0 012-2h6a2 2 0 012 2v8a2 2 0 01-2 2H4a2 2 0 01-2-2V6zm12.553 1.106A1 1 0 0014 8v4a1 1 0 00.553.894l2 1A1 1 0 0018 13V7a1 1 0 00-1.447-.894l-2 1z"/>
                    </svg>
                    <%= tournament.videos.count %>
                  </span>
                <% else %>
                  <span class="text-gray-400">-</span>
                <% end %>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
  <% end %>
</div>
```

**3.2 Index View erweitern:**
```erb
<!-- app/views/international/tournaments/index.html.erb -->

<!-- View Mode Toggle (nach Filters, vor Results) -->
<div class="flex justify-end mb-4">
  <div class="inline-flex rounded-md shadow-sm" role="group">
    <%= link_to international_tournaments_path(view: 'grid', **params.except(:view)), 
        class: "px-4 py-2 text-sm font-medium #{@view_mode == 'grid' ? 'bg-blue-600 text-white' : 'bg-white text-gray-700 hover:bg-gray-50'} border border-gray-300 rounded-l-lg" do %>
      <svg class="w-4 h-4 mr-2 inline" fill="currentColor" viewBox="0 0 20 20">
        <path d="M5 3a2 2 0 00-2 2v2a2 2 0 002 2h2a2 2 0 002-2V5a2 2 0 00-2-2H5zM5 11a2 2 0 00-2 2v2a2 2 0 002 2h2a2 2 0 002-2v-2a2 2 0 00-2-2H5zM11 5a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V5zM11 13a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z"/>
      </svg>
      Grid
    <% end %>
    <%= link_to international_tournaments_path(view: 'table', **params.except(:view)), 
        class: "px-4 py-2 text-sm font-medium #{@view_mode == 'table' ? 'bg-blue-600 text-white' : 'bg-white text-gray-700 hover:bg-gray-50'} border border-gray-300 rounded-r-lg" do %>
      <svg class="w-4 h-4 mr-2 inline" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M3 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1z" clip-rule="evenodd"/>
      </svg>
      Table
    <% end %>
  </div>
</div>

<!-- Tournament Results -->
<% if @tournaments.any? %>
  <% if @view_mode == 'table' %>
    <%= render 'table_view', tournaments: @tournaments %>
  <% else %>
    <%= render 'grid_view', tournaments: @tournaments %>
  <% end %>
  
  <!-- Pagination -->
  <div class="flex justify-center mt-8">
    <%== pagy_nav(@pagy) if @pagy.pages > 1 %>
  </div>
<% else %>
  <!-- Empty state -->
<% end %>
```

---

## 🔄 Reihenfolge der Umsetzung

1. **✅ JETZT:** Dokumentation erstellen (dieses Dokument)
2. **🔴 HOCH:** Disziplin-Mapping beim Scraping fixen
3. **🟡 MITTEL:** Table View implementieren
4. **🟡 MITTEL:** Hierarchische Disziplin-Filter
5. **🟢 NIEDRIG:** Weitere View-Verbesserungen (Sortierung, Export, etc.)

---

## 📝 Nächste Schritte

**Möchten Sie, dass ich:**
1. Das Disziplin-Mapping beim Scraping fixe?
2. Die Table View implementiere?
3. Die hierarchischen Filter erstelle?
4. Alles nacheinander mache?

**Bitte bestätigen Sie die Priorität oder geben Sie Feedback!**
