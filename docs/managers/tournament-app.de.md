# Turnier-App

Für Turnierleiter, die ein Turnier mit der Turnier-App führen, und für Vereins-Admins, die sie bereitstellen.

## Was die Turnier-App ist {#was}

Die Turnier-App ist Teil von Carambus. Sie läuft im Browser (Laptop oder Tablet) und kommt vom eigenen Carambus-Server
unter `/app/`. Sie führt Turniere neben dem [Turnier-Monitor](tournament-management.md) — Formen, die er nicht abdeckt
(die 3-Band-Mannschaftsmeisterschaft, KO-Turniere in Pool und Snooker), und Turniere, die gleichzeitig mit einem
anderen am selben Spielort laufen — und legt die Partien auf die Carambus-Scoreboards. Gespielt und erfasst wird am
Tisch wie gewohnt; die App holt die Ergebnisse vom Scoreboard ab. Welcher Weg für ein Turnier gilt, sagt die
Entscheidungshilfe [Turnier-Monitor oder Turnier-App?](tournament-management.md#monitor-or-app).

| Form | Wofür | Im Turnierbetrieb erprobt |
|------|-------|---------------------------|
| **TournamentPlan (T01–T24)** | Carambus-Turnierpläne mit Gruppen und Finalrunde; hängt sich an ein Carambus-Turnier an („attachen“) | ja — CEB-Ladies-Turnier, BC Wedel, 21.–23.08.2026 |
| **KO-System (Einzel)** | Einfach- und Doppel-KO nach den ClubCloud-Plänen, auch für 8-, 9-, 10-Ball, 14.1 endlos und Snooker | nein |
| **3-Band Mannschaftsmeisterschaft** | 4 Mannschaften × 4 Spieler | nein |
| **Liga-Spieltag** | Mannschaftsspieltag nach dem Spielplan der Liga, Ergebnis per Direkteingabe oder Scoreboard | nein |

Die Schnittstelle dahinter beschreibt die [External-Tournament-Bridge](external-tournament-bridge.md).

### Welcher Fall? {#fall}

| Dein Turnier | Weg in der App | Anleitung |
|--------------|----------------|-----------|
| Karambol-Turnier mit Carambus-Turnierplan (T01–T24), in Carambus als App-Turnier angelegt | „🔗 → Plan-Turnier attachen“ | [Plan-Turnier](#anlegen) — im Turnierbetrieb erprobt |
| Pool- oder Snooker-Turnier aus der ClubCloud (liegt in Carambus mit Meldeliste) | „🏆 → KO-Turnier anlegen“ | [KO-Turnier aus der ClubCloud](#ko-aus-clubcloud) — noch nicht erprobt |

Ob ein Turnier überhaupt in die App gehört, sagt die Entscheidungshilfe
[Turnier-Monitor oder Turnier-App?](tournament-management.md#monitor-or-app)

### Wo die Daten liegen {#daten}

- **Der Turnierstand** — Setzliste, erfasste Ergebnisse, Tabelle — liegt im Browser des Geräts, auf dem die App
  läuft. Carambus kennt Plan, Setzliste, die gebundenen Tische und die Partie, die gerade am Tisch liegt.
- **Das Ergebnisarchiv:** In den Formen Plan, KO und 3-Band-Mannschaft legt die App nach jedem Ergebnis den Endstand
  mit den Partien zusätzlich in Carambus ab; er erscheint auf der Turnierseite. Von Hand geht das jederzeit über
  „📦 Ergebnisse in Carambus ablegen“.
- **Zurück in die App** kommt aus dem Archiv nichts. Wer den Turnierstand im Browser verliert, braucht die
  [Sicherung](#fuehren).

## Voraussetzungen (Vereins-Admin) {#voraussetzungen}

1. **Auslieferung einschalten:** `serve_tournament_app: true` in `carambus_data/scenarios/<szenario>/config.yml`.
   Die App-Dateien gehen mit jedem Carambus-Deploy mit; der Schalter wirkt über die nginx-Konfiguration und die
   `carambus.yml`, die beide `rake "scenario:prepare_deploy[<szenario>]"` erzeugt. Ohne Schalter antwortet der Server
   auf `/app/` mit 404, und die Turnierseite zeigt den [Knopf](#link) nicht. Solange die `carambus.yml` eines Servers
   noch nicht neu erzeugt ist, fehlt der Knopf ebenfalls.
2. **Dienstkonto anlegen:** Die App meldet sich mit einem Dienstkonto an — einem Benutzer in der Datenbank des
   Servers, von dem sie kommt. Anlegen im Deploy-Verzeichnis dieses Servers:

    ```bash
    cd /var/www/<basename>/current
    RAILS_ENV=production bundle exec rake "service_accounts:create_carambus_app[<KÜRZEL>]"
    ```

    Das Kürzel bildet die Adresse `carambus-app-<kürzel>-bridge@carambus.de`, etwa das Kürzel des Vereinsservers
    oder der Region; diese Adresse gehört in den [Link](#link). Das Passwort wird nur einmal ausgegeben; sicher an die
    Turnierleiter weitergeben. Ein neues Passwort erzeugt
    derselbe Aufruf mit `ROTATE=1` davor; bisherige Anmeldungen werden damit ungültig. Details:
    [External-Tournament-Bridge, Schritt 1](external-tournament-bridge.md#schritt-1-service-account-anlegen-sportwart).

## Plan-Turnier anlegen (Vereins-Admin) {#anlegen}

Das Turnier gehört in Carambus, nicht in die App: Dort liegen Plan, Setzliste und Tischbindungen, deshalb können
mehrere Geräte daran arbeiten. Drei Angaben entscheiden:

- **`manual_assignment`** muss gesetzt sein, sonst führt Carambus den Plan selbst aus und kommt der App in die Quere.
- **Enddatum in der Zukunft** — sonst räumt der [nächtliche Lauf](#aufraeumen) das Turnier ab.
- **Region** und **Turnierplan** — ohne Region findet die App das Turnier nicht, ohne Plan kann sie es nicht übernehmen.

!!! warning "Über das Web-Formular geht es heute nicht"
    Das Formular unter „Neues Turnier“ speichert keine Region; die App findet ein so angelegtes Turnier nicht.
    Außerdem legt Carambus den Turnier-Monitor im Web erst mit „Starte den Turnier-Monitor“ an — und erzeugt dabei
    die Spiele des Plans, mit denen die App kollidiert. Bis das behoben ist, legt ein Admin das Turnier in der
    Rails-Konsole des Servers an.

In der Konsole (`cd /var/www/<basename>/current && RAILS_ENV=production bundle exec rails c`):

```ruby
region = Region.find_by!(shortname: "<REGION>")
t = Tournament.create!(
  title: "<Titel>", shortname: "<Kurzname>",
  date:     Time.zone.parse("<JJJJ-MM-TT HH:MM>"),
  end_date: Time.zone.parse("<JJJJ-MM-TT HH:MM>"),   # in der Zukunft: schützt vor dem nächtlichen Lauf
  organizer: region, region_id: region.id, season: Season.current_season,
  location_id: <Spielort-ID>, discipline_id: <Disziplin-ID>,
  tournament_plan: TournamentPlan.find_by!(name: "<z. B. T08>"),
  balls_goal: <Distanz>, innings_goal: <Aufnahmen>,
  manual_assignment: true,                           # die App führt den Plan, nicht Carambus
  data: {}
)

# Setzliste in Setzplatz-Reihenfolge
Player.find([<Spieler-IDs>]).each_with_index { |p, i| t.seedings.create!(player: p, position: i + 1) }

t.initialize_tournament_monitor
t.reload
t.games.destroy_all   # die Plan-Spiele, die beim Anlegen des Monitors entstehen — die App legt eigene an

puts "id=#{t.id} monitor=#{t.tournament_monitor&.id} seedings=#{t.seedings.count} games=#{t.games.count}"
```

Am Ende muss `games=0` stehen. Die Spiele entstehen später einzeln, wenn die App sie auf die Tische legt.

**Spieler, die es noch nicht gibt** (etwa Gäste ohne DBU-Nummer), findet Carambus über Vor- und Nachnamen. Mit
Nationalität angelegt, zeigen Scoreboard und App die Landesflagge:

```ruby
Player.create!(firstname: "<Vorname>", lastname: "<Nachname>",
               nationality: "BE",               # ISO-Ländercode, ergibt die Flagge
               international_player: true, region_id: region.id)
```

Wer schon in der Datenbank steht, wird wiederverwendet, nicht neu angelegt.

## Der Knopf und der Link {#link}

Auf der Turnierseite in Carambus öffnet **„In der Turnier-App öffnen“** die App in einem neuen Tab, mit Region und
Turnier eingetragen. Gibt es auf dem Server genau ein Dienstkonto der App, steht es schon im Anmeldefeld; nur das
Passwort fehlt. Den Knopf sehen Admins, der Turnierleiter des Turniers und Sportwarte, in deren Wirkbereich es liegt —
wenn der Server die App ausliefert ([Voraussetzungen](#voraussetzungen)). Er fehlt,

- wenn das Turnier keine Region hat — die App fände es nicht;
- solange der Turnier-Monitor das Turnier führt (dann ist die Wahl gefallen; ein App-Turnier trägt `manual_assignment`);
- bei Turnieren mit Ergebnissen aus der ClubCloud.

Ohne Knopf, bei mehreren Dienstkonten auf dem Server oder für ein anderes Gerät bringt derselbe Link den Turnierleiter
in die App:

```text
https://<carambus-server>/app/?cb_region=<REGION>&cb_email=<Dienstkonto>&cb_tournament_id=<Turnier-ID>
```

| Teil | Bedeutung |
|------|-----------|
| `/app/` | die App auf dem eigenen Carambus-Server; der Schrägstrich am Ende gehört dazu |
| `cb_region` | Region des Turniers |
| `cb_email` | das Dienstkonto. Fehlt es, steht ein anderes Konto im Anmeldefeld, und die Anmeldung scheitert |
| `cb_tournament_id` | die Turniernummer in Carambus — für ein anderes Turnier ändert sich nur sie |

Das Passwort steht nie im Link. Die Server-Adresse leitet die App aus der Browser-Adresse ab; `cb_base_url` braucht
es nur, wenn die App von einem anderen Server kommt als Carambus.

## Plan-Turnier führen {#fuehren}

1. Auf der Turnierseite **„In der Turnier-App öffnen“** (oder den [Link](#link)), Passwort des Dienstkontos eingeben.
2. Auf der Übersicht **„🔗 → Plan-Turnier attachen“** wählen — nicht „➕ Neues Turnier“: Das legte ein zweites
   Turnier an und belegte die Tische doppelt.
3. **„▶ Turnier laden“**: Die App holt Plan, Setzliste und Distanz aus Carambus und bindet die Tische an das Turnier.
4. Im Reiter „Spiele & Gruppen“ **„▶ Freie Tische belegen“**: Die erste Runde startet, die Partien erscheinen auf
   den Scoreboards.
5. Nach jedem Spiel **„📥 Ergebnis holen“**: Die App übernimmt das am Scoreboard erfasste Ergebnis und gibt den
   Tisch frei.
6. **Nach jeder Runde sichern:** Reiter „Endstand“, Karte „Sicherung“ → „💾 Sicherung speichern“ (Laptop) oder
   „📋 Sicherung kopieren“ und in eine Notiz einfügen (Tablet).

!!! warning "Warum die Sicherung Pflicht ist"
    Der Turnierstand lebt im Browser. Räumt der Browser seinen Speicher — Safari auf dem iPad tut das bei
    Speicherdruck ohne Vorwarnung —, ist er weg, und die App holt ihn nicht aus Carambus zurück. Die Sicherung ist
    die einzige Rückversicherung; sie dauert zehn Sekunden.

Im richtigen Zustand zeigt der Reiter „Setup“ **„🔗 Attached an Carambus-Turnier #&lt;Turnier-ID&gt;“**, und oben
rechts steht „Carambus: verbunden“.

## Übergabe an einen anderen Turnierleiter {#uebergabe}

Der Link allein bringt den Kollegen an Plan, Setzliste und Tische, nicht an die schon erfassten Ergebnisse. Zu einer
Übergabe gehören deshalb:

1. **der Link**, unverändert,
2. **das Passwort** — getrennt, nicht im selben Kanal,
3. **die Sicherung** als Datei oder kopierter Text.

Der Kollege spielt die Sicherung auf der Übersicht über **„Sicherung wiederherstellen“** ein, öffnet danach den
Link und meldet sich an. Dann öffnet er das wiederhergestellte Turnier — **nicht neu attachen**: Das leert die
erfassten Ergebnisse in der App. Meldet die App „Table not bound to this tournament“, hilft im Reiter „Setup“
„🔗 Tische neu binden“.

Mitlesen dürfen beliebig viele Geräte. Spiele starten sollte immer nur eines, sonst landen zwei Partien auf demselben
Tisch; wer führt, ist eine Absprache, keine Sperre im System.

## KO-Turnier aus der ClubCloud (Pool, Snooker) {#ko-aus-clubcloud}

Für ein Pool- oder Snooker-Turnier, das aus der ClubCloud in Carambus liegt, übernimmt die App die Meldeliste und legt
daraus ein **eigenes** KO-Turnier an. Das ClubCloud-Turnier in Carambus bleibt dabei unberührt; Tische, Partien und
Ergebnisarchiv hängen an dem Turnier, das die App anlegt. Diesen Weg gibt es im Code, im Turnierbetrieb ist er noch
nicht erprobt.

1. **Meldeliste prüfen:** Die App übernimmt die Meldeliste, die in Carambus liegt; der Knopf holt sie nicht neu. Wer
   den Carambus-Assistenten fragt („öffne das Turnier … in der Turnier-App“), bekommt den Link mit frisch aus der
   ClubCloud geholter Meldeliste.
2. **App öffnen:** auf der Turnierseite **„In der Turnier-App öffnen“** oder über den [Link](#link) mit der
   Turniernummer aus der Adresse der Turnierseite, `…/tournaments/<Turnier-ID>`.
3. **Anmelden.** Die Übersicht zeigt den Kasten „🔗 Aus dem Carambus-Chat vorbereitet“ mit Turniername, Disziplin und
   Spielerzahl.
4. **„🏆 → KO-Turnier anlegen“** — die Meldeliste wird zur Setzliste. Nicht „Plan-Turnier attachen“: Das gilt nur für
   Turniere mit Carambus-Turnierplan.
5. Im Reiter „Setup“: **„KO-Plan (ClubCloud)“** passend zur Teilnehmerzahl wählen (Einfach- oder Doppel-KO), die
   **Disziplin** (z. B. 9-Ball) und die Ausspielziele einstellen, **„📥 Tische aus Carambus laden“** und die Tische
   auswählen, dann **„🏁 Turnier anlegen & Bracket erzeugen“**.
6. Im Reiter „Spiele & Bracket“ je Partie einen Tisch wählen und **„▶ Starten“** — die Partie erscheint auf dem
   Scoreboard. Nach dem Spiel **„📥 Ergebnis holen“** (oder „✎ Ergebnis erfassen“ von Hand).

**Zeigt die Vorschau 0 Spieler**, fehlt in Carambus die Meldeliste: über den Assistenten frisch aus der ClubCloud holen
oder die Spieler im Setup über „📥 Clubs laden“ → Verein → Spieler wählen.

!!! warning "Grenzen des KO-Wegs"
    - **Keine Sicherung:** Das KO-Schema hat keinen Sicherungsknopf, der Turnierstand liegt nur im Browser. Nach jedem
      Ergebnis legt die App den Endstand im Ergebnisarchiv in Carambus ab.
    - **Nicht zurück in die ClubCloud:** Die App lädt nichts in die ClubCloud hoch. Im Reiter „Endstand“ exportiert
      sie die Endrangliste im ClubCloud-Format („📄 Rangliste (ClubCloud)“) und die Partien („📄 Spiele-CSV“); den
      Eintrag in der ClubCloud macht der Turnierleiter selbst.

## Nach dem Turnier — der nächtliche Lauf {#aufraeumen}

Jede Nacht um 0:01 Uhr räumt Carambus auf einem Vereinsserver hinter App-Turnieren auf:

- Es gibt die Tische frei und schließt den Turnier-Monitor — **nicht**, solange das Enddatum in der Zukunft liegt.
- Danach löscht es App-Turniere mit geschlossenem Monitor und verstrichenem Enddatum, samt Partien — **außer**
  Turnieren, deren Endstand im Ergebnisarchiv liegt.

Im Reiter „Endstand“ löscht **„🧹 Turnier in Carambus abräumen“** Turnier und Partien sofort, einschließlich des
abgelegten Endstands. Soll ein Turnier stehen bleiben, genügt ein Enddatum in der Zukunft (Admin: im Bearbeiten-Formular
des Turniers).

## Wenn etwas schiefgeht {#stoerungen}

**Die App zeigt kein Turnier mehr** — der Browser hat seinen Speicher geräumt. Sicherung über „Sicherung
wiederherstellen“ einspielen, die App über den Knopf oder den Link öffnen und anmelden (die Anmeldung gehört nicht zur
Sicherung),
das wiederhergestellte Turnier öffnen, nicht neu attachen. Ohne Sicherung stehen die bis dahin abgelegten Ergebnisse
im Ergebnisarchiv auf der Turnierseite; zurück in die App kommen sie nicht.

**Die Tische lassen sich nicht belegen** („Table already in use“) — an den Tischen hängt noch ein anderes Turnier,
meist ein Testlauf, bei dem „➕ Neues Turnier“ statt „attachen“ gedrückt wurde. Ein Admin sieht in der Konsole, was
dort hängt:

```ruby
TableMonitor.joins(:table).where(tables: {location_id: <Spielort-ID>})
  .where.not(tournament_monitor_id: nil)
  .pluck(:id, :tournament_monitor_id, "tables.name")
```

**Turnier auf Anfang zurücksetzen** (Admin, etwa nach einem Testlauf): Turnier, Setzliste und Plan bleiben, die
gespielten Partien und die Tischbindungen gehen weg.

```bash
cd /var/www/<basename>/current
DRY_RUN=1 RAILS_ENV=production bundle exec rake "external_tournament:reset_app_tournament[<Turnier-ID>]"
RAILS_ENV=production bundle exec rake "external_tournament:reset_app_tournament[<Turnier-ID>]"
```

Der Trockenlauf nennt die gebundenen Tische, die zu löschenden App-Spiele und ob darunter unbestätigte Ergebnisse
sind — am Scoreboard erfasst, von der App nie abgeholt. Die wären verloren. Danach in der App „🔄 Server-Stand neu
laden“.

**Das Turnier ist in Carambus verschwunden** — das Enddatum prüfen; es ist die einzige Bremse des nächtlichen Laufs.
