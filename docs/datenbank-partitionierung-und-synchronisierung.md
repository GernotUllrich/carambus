---
---
title: Datenbank-Partitionierung und Synchronisierung
summary: 'Das System implementiert eine regionsbasierte Datenbank-Partitionierungsstrategie
  zur Optimierung der Datensynchronisierung zwischen lokalen Servern und dem zentralen
  API-Server. Dieser Ansatz stellt sicher, dass jeder lokale Server nur die für seine
  Region relevanten Daten verwaltet und gleichzeitig Zugriff auf notwendige globale
  Ereignisse hat. Zusätzlich werden regionsunabhängige Daten an alle lokalen Server
  synchronisiert.

  '
version:
published_at: !ruby/object:ActiveSupport::TimeWithZone
  utc: 2025-04-29 21:19:03.426133000 Z
  zone: !ruby/object:ActiveSupport::TimeZone
    name: Europe/Berlin
  time: 2025-04-29 23:19:03.426133000 Z
tags: []
metadata: {}
position: 0
id: 10
---

## Übersicht
Das System implementiert eine regionsbasierte Datenbank-Partitionierungsstrategie zur Optimierung der Datensynchronisierung zwischen lokalen Servern und dem zentralen API-Server. Dieser Ansatz stellt sicher, dass jeder lokale Server nur die für seine Region relevanten Daten verwaltet und gleichzeitig Zugriff auf notwendige globale Ereignisse hat. Zusätzlich werden regionsunabhängige Daten an alle lokalen Server synchronisiert.

## Hauptkomponenten

### 1. Regions-Tagging (RegionTaggable)
- Datensätze werden mit einem `region_id` markiert, um ihre regionale Zuordnung zu verfolgen
- Ein `global_context` Boolean-Flag kennzeichnet Datensätze, die an globalen Ereignissen teilnehmen
- Datensätze ohne regionale Abhängigkeiten (region_id ist NULL) werden an alle Server synchronisiert
- Implementiert als Concern in `app/models/concerns/region_taggable.rb`

### 2. Versionsverwaltung
- Nutzt PaperTrail für die Versionsverfolgung
- Versionen werden mit `region_id` markiert, um die regionale Relevanz zu verfolgen
- Versionen mit NULL region_id werden als global betrachtet und an alle Server gesendet

### 3. Synchronisierungslogik
- Lokale Server erhalten nur Daten mit `region_id` ihrer Region oder `global_context = true`
- Globale Ereignisse (DBU-Turniere, etc.) werden an alle Server synchronisiert
- Regionsunabhängige Daten (Konfigurationen, etc.) werden an alle Server gesendet

## Implementierung

### RegionTaggable Concern
```ruby
module RegionTaggable
  extend ActiveSupport::Concern

  included do
    after_save :update_region_tagging
    after_destroy :update_region_tagging
  end

  def find_associated_region_id
    # Berechnet die region_id basierend auf dem Modelltyp
  end

  def global_context?
    # Bestimmt, ob der Datensatz globalen Kontext hat
  end
end
```

### Versions-Scope
```ruby
scope :for_region, ->(region_id) {
  where("region_id IS NULL OR region_id = ?", region_id)
}
```

## Verwendung

### Rake Tasks
```bash
# Region-IDs für alle Modelle aktualisieren
rails region_taggings:update_all_region_ids

# Region-Tagging für alle Modelle aktualisieren
rails region_taggings:update_all

# Global Context für Datensätze setzen
rails region_taggings:set_global_context

# Region-Tagging verifizieren
rails region_taggings:verify
```

### Modelle mit RegionTaggable
- Region, Club, Tournament, League, Party
- Location, LeagueTeam, Game, PartyGame, GameParticipation
- Player, SeasonParticipation, Seeding

## Migration von altem System

Das System wurde von einem komplexen polymorphic `region_taggings` System zu einem einfachen `region_id` + `global_context` System migriert:

1. **Altes System**: `region_ids` Array mit polymorphic `region_taggings` Tabelle
2. **Neues System**: Einzelne `region_id` mit `global_context` Boolean

### Vorteile des neuen Systems
- Einfacher zu verstehen und zu warten
- Bessere Performance durch direkte Indizes
- Klarere Trennung zwischen regionalen und globalen Daten
- Weniger Komplexität in der Synchronisierungslogik
