# Admin-Rollen und Berechtigungen

Was jemand in Carambus darf, hängt von drei Dingen ab: der **Rolle** des Benutzerkontos, den **Personas**
Sportwart oder Landessportwart und davon, ob er bei einem Turnier als **Turnierleiter** eingetragen ist. Die Rechte
addieren sich; ein Vereins-Admin mit Sportwart-Persona hat beides.

Ohne Anmeldung sieht jeder Besucher die öffentlichen Listen und Detailseiten: kommende und vergangene Turniere,
Spieler, Vereine und Ergebnisse. Die Rechte unten betreffen das Ändern.

## Rollen und Personas {#roles}

**Rolle**: jedes Konto hat genau eine.

| Rolle | Wert im System | Kurz |
|---|---|---|
| Spieler | `player` | Standard für neue Konten; pflegt das eigene Profil (auch den eigenen ClubCloud-Zugang) |
| Vereins-Admin | `club_admin` | Turniere, Turnier-Monitor, Stammdaten |
| System-Admin | `system_admin` | alles, dazu der Admin-Bereich (Benutzer, Rollen, Einstellungen) |

**Personas** kommen zur Rolle hinzu. Vergeben werden sie nur von einem System-Admin:

- **Sportwart**: gilt für die Turniere seines Wirkbereichs, also die ihm zugeordneten Spielorte und Disziplinen.
  Ist keine Disziplin zugeordnet, gelten alle; „Karambol“ umfasst die Unterdisziplinen (z. B. Cadre 35/2, Dreiband).
  Ohne zugeordneten Spielort gilt die Persona für kein Turnier. Bei **Liga-Spieltagen** zählt nur die Disziplin der
  Liga, der Spielort nicht.
- **Landessportwart**: wie Sportwart, aber für alle Spielorte.

**Turnierleiter** ist, wer bei einem Turnier als Turnierleiter eingetragen ist. Das Recht gilt für dieses Turnier.
Für Liga-Spieltage gibt es das Gegenstück: den **Begegnungsleiter**. Ihn setzt ein Sportwart oder Admin auf der
Seite des Spieltags ein; das Recht gilt für diesen Spieltag. In der Tabelle steht er in der Spalte „Turnierleiter“.

## Wer darf was {#matrix}

Spalten „Turnierleiter“ und „Sportwart“ meinen ein Konto mit der Rolle Spieler und dieser Persona bzw. Zuordnung.

| Aktion | Spieler | Turnierleiter | Sportwart | Vereins-Admin | System-Admin |
|---|---|---|---|---|---|
| Listen und Detailseiten ansehen | ja | ja | ja | ja | ja |
| Turnier anlegen (nur auf einem lokalen Server) | – | – | – | ja | ja |
| Turnier-Wizard auf der Turnierseite nutzen | – | – | – | ja | ja |
| Teilnehmerliste bearbeiten | – | ja | ja | ja | ja |
| Turnierleiter eines Turniers benennen | – | – | ja | ja | ja |
| Turnier-Monitor öffnen, Turnier zurücksetzen | – | – | – | ja | ja |
| Stammdaten bearbeiten (Vereine, Spieler, Ligen, Mannschaften, **Spielorte**, Tische, Disziplinen, Saisons, Turnierpläne …) | – | – | – | ja | ja |
| Spielorte anlegen, ändern, löschen, zusammenführen, mit Tischen bestücken | – | – | – | ja | ja |
| Begegnungsleiter eines Liga-Spieltags einsetzen oder entfernen | – | – | ja | ja | ja |
| Liga-Spieltag: PartyMonitor starten und bedienen (Aufstellung, Runden, Ergebnisse, Abschluss) | – | ja | ja | ja | ja |
| PartyMonitor zurücksetzen; PartyMonitor-Datensätze anlegen, ändern, löschen | – | – | – | ja | ja |
| Verein oder Liga aus der ClubCloud neu laden | – | ja | ja | ja | ja |
| ClubCloud-Schreibaktionen im Carambus-Assistenten | – | ja | ja | – | ja |
| Admin-Bereich: Benutzer, Rollen, Personas, Einstellungen, Kontaktdaten der Mitglieder | – | – | – | – | ja |

Wo ein Recht fehlt, ist der Knopf ausgegraut oder nicht zu sehen. Sportwarte ohne Admin-Rolle erledigen einen Teil
davon über den Carambus-Assistenten (siehe [ClubCloud-MCP Cloud-Quickstart](clubcloud-mcp-cloud-quickstart.md)).

## Was Carambus dabei nicht tut {#limits}

- **Kein Audit-Log.** Administrative Aktionen und Rollenänderungen werden nicht protokolliert. Protokolliert werden
  nur ClubCloud-Schreibaktionen, die über den Carambus-Assistenten laufen (wer, wann, welches Werkzeug).
- **Keine Benachrichtigung** bei einer Rollenänderung. Sagen Sie dem Betroffenen selbst Bescheid.
- **Keine Vereinsbindung.** Ein Vereins-Admin ist keinem Verein zugeordnet: Er kann die Stammdaten aller Vereine auf
  diesem Server bearbeiten. Datensätze, die vom zentralen Server kommen (etwa Vereine und Spieler aus der ClubCloud),
  sind auf einem lokalen Server schreibgeschützt.
- **Kein Admin-Bereich für Vereins-Admins.** Das Avatar-Menü zeigt ihnen zwar „Admin → Dashboard“, und nach der
  Anmeldung landen sie dort; der Admin-Bereich weist sie aber mit „System-Admin only“ ab. Die Server-Einstellungen
  (Kontext, Spielort, Verein, Schnellspiel-Vorlagen) ändert nur ein System-Admin; danach muss die Anwendung neu
  gestartet werden.
- **Keine Datensicherung über die Oberfläche.** Backups und Wartung gehören zum Serverbetrieb.

## Rolle und Personas vergeben {#assign}

Nur für System-Admins:

1. Avatar-Menü → **Admin** → **Dashboard**. Es öffnet sich die Benutzerliste.
2. Beim Benutzer **Bearbeiten**.
3. Feld **Role**: `player`, `club_admin` oder `system_admin`.
4. Im selben Formular: **Sportwart-Persona** (Sportwart oder Landessportwart), **Sportwart-Disziplinen**,
   **Sportwart-Spielorte** und **Verknüpfter Spieler**.
5. Speichern.

Den Turnierleiter eines Turniers setzen Admins im Bearbeiten-Formular des Turniers. Sportwarte benennen ihn über den
Carambus-Assistenten („mach Max Mustermann zum Turnierleiter des Cadre-Turniers“), weil der Bearbeiten-Knopf nur für
Admins aktiv ist. Der System-Admin pflegt die Zuordnungen außerdem im Admin-Bereich unter **User Tournaments**.

Mit Shell-Zugang zum Server geht es auch über die Rails-Konsole:

```ruby
user = User.find_by(email: "admin@example.com")
user.role = "system_admin"
user.save!
```

## Für Entwickler: Rechte im Code prüfen {#code}

```ruby
current_user.admin?          # true für club_admin ODER system_admin
current_user.system_admin?   # nur System-Admin
current_user.sportwart?      # Persona Sportwart oder Landessportwart

# Turnier-Rechte prüft Pundit:
policy(@tournament).manage_teilnehmerliste?   # Turnierleiter, Sportwart im Wirkbereich, Admin
policy(@tournament).assign_leiter?            # Sportwart im Wirkbereich, Admin
```

Die Knöpfe in den Listen folgen `current_user.admin?`. Die CanCanCan-Regeln in `app/models/ability.rb` werden nur an
wenigen Stellen ausgewertet; für Turniere sind sie nicht maßgeblich.
