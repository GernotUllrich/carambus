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
  utc: 2025-04-28 04:45:27.155220000 Z
  zone: !ruby/object:ActiveSupport::TimeZone
    name: Europe/Berlin
  time: 2025-04-28 06:45:27.155220000 Z
tags: []
metadata: {}
position: 0
id: 10
---

# Datenbank-Partitionierung und Synchronisierung

## Übersicht
Das System implementiert eine regionsbasierte Datenbank-Partitionierungsstrategie zur Optimierung der Datensynchronisierung zwischen lokalen Servern und dem zentralen API-Server. Dieser Ansatz stellt sicher, dass jeder lokale Server nur die für seine Region relevanten Daten verwaltet und gleichzeitig Zugriff auf notwendige globale Ereignisse hat. Zusätzlich werden regionsunabhängige Daten an alle lokalen Server synchronisiert.

## Hauptkomponenten

### 1. Regions-Tagging (RegionTaggable)
- Datensätze werden mit einer `region_id`, bzw. global_context = true markiert, um ihre regionalen bzw. globalen (DBU - Deutsche Billard-Union) Zuordnungen zu verfolgen
- Datensätze ohne regionale Abhängigkeiten (region_id ist NUL) werden an alle Server synchronisiert
- Implementiert als Concern in `app/models/concerns/region_taggable.rb`

### 2. Versionsverwaltung
- Nutzt PaperTrail für die Versionsverfolgung
- Versionen werden mit `region_id` bzw. global_context = true markiert, um die regionale bzw. globale Relevanz zu verfolgen
- Versionen mit region_id NULL werden als global betrachtet und an alle Server gesendet
- Enthält Scopes und Methoden zum Filtern von Versionen nach Region

### 3. Synchronisierungsprozess
- Lokale Server holen Updates über `Version.update_from_carambus_api`
- API-Server filtert Versionen basierend auf regionaler Relevanz
- Nur für die anfragende Region relevante Versionen werden übertragen
- Globale Versionen (blobal_context = tue oder ohne regionale Abhängigkeiten) werden an alle Server übertragen

### 4. Datenbereinigung
- Einmalige Bereinigungsaufgabe zum Entfernen von Daten fremder Regionen
- Behält:
  - Daten der lokalen Region
  - DBU-Regionsdaten
  - Daten von Regionen mit Vereinen/Spielern in globalen Ereignissen
  - Alle regionsunabhängigen Daten

## Implementierungsdetails

### Versionsmodell
```ruby
scope :for_region, ->(region_id) {
  where("region_id IS NULL OR region_id = ? OR global_context = TRUE", region_id)
}

```

### API-Endpunkt
```ruby
def get_updates
  # ... existierender Code ...
  if params[:region_id].present?
    version_query = version_query.for_region(params[:region_id])
  end
  # ... restlicher Code ...
end
```

### Bereinigungsaufgabe
Die Bereinigungsaufgabe stellt sicher, dass jeder lokale Server nur mit relevanten Daten startet durch:
1. Identifizierung der zu behaltenden Regionen (lokal, DBU und Regionen mit globaler Ereignisbeteiligung)
2. Entfernen von Datensätzen, die nicht mit diesen Regionen verbunden sind
3. Aufrechterhaltung der Datenintegrität für globale Ereignisse
4. Beibehaltung aller regionsunabhängigen Daten

## Verwendung
1. Führen Sie die Bereinigungsaufgabe auf jedem lokalen Server aus:
   ```bash
   rake cleanup:remove_non_region_records
   ```
2. Konfigurieren Sie den lokalen Server mit seiner Regions-ID
3. Das System verwaltet die Datenrelevanz automatisch durch den Synchronisierungsprozess
