# API Server: Scrape Upcoming Tournaments Feature

## Problem

Wenn ein Turnier kurzfristig auf ClubCloud hinzugefügt wird, muss der komplette
`reload_tournaments` für die gesamte Region durchgeführt werden. Das dauert mehrere Minuten.

## Lösung

Neuer Parameter für `Version.update_from_carambus_api`:
- `scrape_upcoming_tournaments: region_id`

Dieser scraped **nur** Turniere der nächsten 30 Tage (viel schneller).

## Implementierung

### 1. Auf dem API Server (carambus_api)

**File: `app/models/region.rb`**

```ruby
# Nach Zeile 881 (vor private) einfügen:

# Scraped nur anstehende Turniere (nächste N Tage)
# Schneller als kompletter scrape_tournaments_check
def scrape_upcoming_tournaments(days_ahead: 30)
  return unless public_cc_url_base.present?
  
  Rails.logger.info "===== scrape_upcoming ===== Scraping upcoming for #{shortname}"
  
  url = public_cc_url_base
  current_season = Season.current_season
  
  # Nur aktuelle Saison (next Season gibt es nicht immer)
  einzel_url = url + "sb_einzelergebnisse.php?p=#{cc_id}--#{current_season.name}-----1-1-100000-"
  
  begin
    uri = URI(einzel_url)
    einzel_html = Net::HTTP.get(uri)
    einzel_doc = Nokogiri::HTML(einzel_html)
    
    count = 0
    
    einzel_doc.css("article table.silver").andand[1].andand.css("tr").to_a[2..].to_a.each do |tr|
      begin
        # Datum parsen
        date_str = tr.css("td")[1]&.text
        next unless date_str.present?
        
        date = DateTime.parse(date_str) rescue next
        
        # Nur anstehende Turniere
        next unless date.between?(Date.today, Date.today + days_ahead.days)
        
        # Tournament-Link
        tournament_link = tr.css("a")[0]&.attributes&.[]("href")&.value
        next unless tournament_link.present?
        
        params = tournament_link.split("p=")[1]&.split("-")
        next unless params
        
        tournament_cc_id = params[3].to_i
        name = tr.css("a")[0].text.strip
        
        Rails.logger.info "===== scrape_upcoming ===== Found: #{name} (#{date.to_date})"
        
        # Scrape dieses spezifische Turnier
        # Nutze die bestehende scrape_tournaments_check Methode mit filter
        scrape_tournaments_check(current_season, tournament_cc_id: tournament_cc_id)
        
        count += 1
      rescue StandardError => e
        Rails.logger.error "===== scrape_upcoming ===== Error: #{e.message}"
      end
    end
    
    Rails.logger.info "===== scrape_upcoming ===== Finished: #{count} tournaments"
    count
  rescue StandardError => e
    Rails.logger.error "===== scrape_upcoming ===== Fatal: #{e.message}"
    0
  end
end
```

**File: `app/controllers/versions_controller.rb`**

```ruby
# In der get_updates Action, nach Zeile ~50:

if params[:scrape_upcoming_tournaments].present?
  region = Region.find(params[:scrape_upcoming_tournaments])
  days_ahead = params[:days_ahead]&.to_i || 30
  
  Rails.logger.info "API: Scraping upcoming tournaments for region #{region.shortname}"
  region.scrape_upcoming_tournaments(days_ahead: days_ahead)
end
```

### 2. Auf dem Location Server (carambus_bcw/master)

**Verwende die bestehende Version.update_from_carambus_api mit neuem Parameter:**

Bereits implementiert in der View:
```erb
<%= button_to 'Alle Turniere vom API Server aktualisieren', 
    reload_tournaments_region_path(tournament.organizer),
    method: :post %>
```

Das ruft auf Location Server:
```ruby
# RegionsController#reload_tournaments
def reload_tournaments
  Version.update_from_carambus_api(reload_tournaments: @region.id)
  redirect_to @region
end
```

### 3. Für "Upcoming Only" (zukünftige Optimierung)

Neue Action im RegionsController:

```ruby
def reload_upcoming_tournaments
  Version.update_from_carambus_api(
    scrape_upcoming_tournaments: @region.id,
    days_ahead: 30
  )
  redirect_back fallback_location: region_path(@region),
                notice: "Anstehende Turniere aktualisiert"
end
```

## Testing

**Auf dem API Server:**
```ruby
# Rails Console auf carambus_api
region = Region.find_by(shortname: 'NBV')
region.scrape_upcoming_tournaments(days_ahead: 60)
```

**Auf dem Location Server:**
```ruby
# Rails Console auf carambus_bcw
region = Region.find_by(shortname: 'NBV')
Version.update_from_carambus_api(
  scrape_upcoming_tournaments: region.id,
  days_ahead: 60
)
```

## Status

- [ ] API Server Änderungen (in carambus_api)
- [x] Location Server Button (in carambus_master/bcw)
- [x] View Integration
- [x] Dokumentation

## Nächste Schritte

1. Die Region#scrape_upcoming_tournaments Methode in carambus_api/app/models/region.rb implementieren
2. VersionsController in carambus_api erweitern
3. Testen
4. Deploy

