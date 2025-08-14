# Datenverwaltung und ID-Bereiche

## ID-Bereiche

| Bereich          | Beschreibung                     | Bearbeitungsrechte |
|------------------|----------------------------------|--------------------|
| < 5.000.000      | Importierte ClubCloud-Daten      | Nur lesend         |
| 5.000.000 - ...  | Lokal erstellte Einträge         | Vollzugriff        |

**Wichtige Felder:**
- `source_url`: Original-URL in der ClubCloud
- `data`: Lokale Erweiterungen/Anpassungen

## Datenquellen

### ClubCloud-Daten (ID < 5.000.000)
- **Herkunft**: Automatischer Import aus ClubCloud
- **Bearbeitung**: Nur lesend, keine lokalen Änderungen möglich
- **Synchronisation**: Täglich um 20:00 Uhr
- **Verantwortlichkeit**: Zentrale ClubCloud-Verwaltung

### Lokale Daten (ID ≥ 5.000.000)
- **Herkunft**: Lokal erstellt oder angepasst
- **Bearbeitung**: Vollzugriff, alle Änderungen möglich
- **Synchronisation**: Bei Bedarf manuell
- **Verantwortlichkeit**: Lokale Administratoren

## Datenverwaltungsrichtlinien

### Importierte Daten
- **Nicht bearbeiten**: ClubCloud-Daten dürfen nicht lokal geändert werden
- **Erweitern**: Lokale Anpassungen nur über zusätzliche Felder
- **Validierung**: Alle Importe werden auf Konsistenz geprüft

### Lokale Daten
- **Vollzugriff**: Alle CRUD-Operationen erlaubt
- **Backup**: Regelmäßige Sicherung lokaler Daten
- **Versionierung**: Änderungen werden protokolliert

## Datenintegrität

### Konsistenzprüfung
```ruby
# Beispiel für Datenvalidierung
class Tournament < ApplicationRecord
  validate :check_data_consistency
  
  private
  
  def check_data_consistency
    if id < 5_000_000 && changed?
      errors.add(:base, "ClubCloud-Daten können nicht geändert werden")
    end
  end
end
```

### Synchronisationsprotokoll
- Alle Datenimporte werden protokolliert
- Fehlerhafte Importe werden markiert
- Wiederholungsversuche bei Fehlern

## Best Practices

### Für Entwickler
- **ID-Bereiche prüfen**: Vor jeder Datenänderung den ID-Bereich validieren
- **Quellendaten schützen**: ClubCloud-Daten niemals direkt bearbeiten
- **Lokale Erweiterungen**: Zusätzliche Felder für lokale Anpassungen verwenden

### Für Administratoren
- **Regelmäßige Backups**: Lokale Daten regelmäßig sichern
- **Import-Überwachung**: ClubCloud-Importe überwachen
- **Datenqualität**: Konsistenz der lokalen Daten prüfen 