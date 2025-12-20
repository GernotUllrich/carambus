# Admin-Rollen und Berechtigungen

## Rollenmatrix

| Recht                | Player | Club Admin | System Admin |
|----------------------|--------|------------|--------------|
| Turniere erstellen   | Nein   | Ja         | Ja           |
| Benutzer verwalten   | Nein   | Nein       | Ja           |
| Systemeinstellungen  | Nein   | Nein       | Ja           |

## Rollenbeschreibungen

### Player (Spieler)
- **Berechtigungen**: Grundlegende Spielerfunktionen
- **Einschränkungen**: Kann keine administrativen Aktionen durchführen
- **Zugriff**: Nur auf eigene Spielerdaten und aktuelle Turniere

### Club Admin (Vereinsadministrator)
- **Berechtigungen**: Verwaltung von Vereinsdaten und Turnieren
- **Einschränkungen**: Kein Zugriff auf Systemebene
- **Verantwortlichkeiten**: 
  - Turniere erstellen und verwalten
  - Vereinsmitglieder verwalten
  - Lokale Einstellungen anpassen

### System Admin (Systemadministrator)
- **Berechtigungen**: Vollzugriff auf alle Systemfunktionen
- **Verantwortlichkeiten**:
  - Benutzerverwaltung auf Systemebene
  - Systemkonfiguration
  - Datenbankverwaltung
  - Backup und Wartung

## Berechtigungsverwaltung

### Rollen zuweisen
```bash
# Über die Admin-Oberfläche
Admin -> Users -> User auswählen -> Role ändern

# Über die Konsole (nur System Admin)
rails console
user = User.find_by(email: 'admin@example.com')
user.role = 'system_admin'
user.save!
```

### Berechtigungen prüfen
```ruby
# In der Anwendung
if current_user.can_create_tournaments?
  # Turnier erstellen erlauben
end

if current_user.is_system_admin?
  # Systemfunktionen anzeigen
end
```

## Sicherheitsrichtlinien

### Best Practices
- **Prinzip der minimalen Berechtigung**: Benutzer erhalten nur die Berechtigungen, die sie wirklich benötigen
- **Regelmäßige Überprüfung**: Admin-Rollen sollten regelmäßig überprüft werden
- **Audit-Log**: Alle administrativen Aktionen werden protokolliert

### Rollenänderungen
- Rollenänderungen müssen von einem System Admin durchgeführt werden
- Alle Änderungen werden im Audit-Log protokolliert
- Benachrichtigungen werden an betroffene Benutzer gesendet 