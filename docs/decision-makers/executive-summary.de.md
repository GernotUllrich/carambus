# Executive Summary

Carambus auf einer Seite: was es kann, wie es aufgebaut ist, was ein Verein braucht und wie das Projekt
aufgestellt ist. Ausführlich: [Feature-Übersicht](features-overview.md) und
[Deployment-Optionen](deployment-options.md).

## Was Carambus kann

- **Turniere (Karambol):** Turnierpläne der Karambol-Turnierordnung (T-Pläne), Jeder-gegen-Jeden für jede
  Teilnehmerzahl, KO und Doppel-KO; Gruppenrangfolge nach der Turnierordnung, Stechen im KO; der Turnier-Monitor
  zeigt Gruppen, laufende Spiele, KO-Baum und Rangliste
- **Turnier-App** für die Turnierleitung, vom Vereinsserver mit ausgeliefert: KO- und Doppel-KO-Turniere (auch in
  Pool und Snooker), 3-Band-Mannschaftsmeisterschaft, Turnierpläne und Liga-Spieltage; sie legt die Spiele auf
  die Scoreboards und archiviert den Endstand auf dem Vereinsserver
  ([Turnier-App](features-overview.md#turnier-app))
- **Scoreboards** für Karambol, Pool und Snooker — auf einem Raspberry Pi im Kiosk-Modus am Tisch oder in jedem
  Browser; alle Anzeigen aktualisieren sich in Echtzeit
- **Liga:** Ligaspieltage mit dem Party-Monitor (Aufstellung, Tischzuordnung, Ergebnisbestätigung) und
  Ligatabellen
- **ClubCloud:** Spieler, Vereine, Turniere und Ligen kommen aus der DBU-ClubCloud; Turnierergebnisse gehen per
  Upload zurück
- **Im Vereinsheim:** Tischreservierung über den Google-Kalender des Vereins mit Vorheizen der Tische,
  Trainingsspiele am Scoreboard, YouTube-Live-Streaming mit Scoreboard-Overlay
- **Für Verbände:** Einzelmeisterschaften mit Meldeliste und Ergebnissen auch ohne ClubCloud, über den Region
  Server ([CC-loses Turniermanagement](../administrators/cc-less-tournament-management.md))

**Mit Bedingungen:**

- **KI-Suche:** übersetzt eine Frage in einen Listenfilter. Sie braucht einen eigenen Anthropic-API-Schlüssel
  (laufende Kosten); die Suchanfragen gehen an Anthropic.
- **ClubCloud-Assistent (MCP)** für Sportwarte: läuft in Claude Code auf dem Rechner des Sportwarts und braucht
  ein Konto auf dem Carambus-Server der Region
  ([Quickstart](../managers/clubcloud-mcp-cloud-quickstart.md)).

## So ist Carambus aufgebaut

Carambus ist ein Verbund aus mehreren Servern:

- Die **Authority** `api.carambus.de`, vom Betreiber von Carambus betrieben, liest die Daten aus der ClubCloud und
  hält die gemeinsamen Stammdaten: Spieler, Vereine, Turniere, Turnierpläne.
- Ein **Vereinsserver** im Spiellokal — in der Regel ein Raspberry Pi — holt diese Stammdaten stündlich von der
  Authority und kann sie nicht ändern. Was im Verein entsteht (lokale Turniere, Spiele, Trainingsergebnisse,
  Tischreservierungen), bleibt auf dem Vereinsserver.
- Für Landesverbände gibt es einen **Region Server** (z. B. `nbv.carambus.de`).

Der Spielbetrieb vor Ort läuft auch ohne Internet weiter. Ohne Verbindung fehlen neue Daten von der Authority, und
der Ergebnis-Upload in die ClubCloud geht erst wieder mit Verbindung. Mehr:
[Server-Architektur](../administrators/server-architecture.md).

## Was ein Verein braucht

- **Hardware:** Raspberry Pi 4 oder 5 (4 GB RAM empfohlen), microSD-Karte, Monitor oder Touch-Display; für jeden
  weiteren Tisch ein Anzeigegerät
- **Eine Person mit Linux- und SSH-Kenntnissen** und einem Mac- oder Linux-Rechner, von dem aus sie den Pi
  einrichtet (Ansible, Rake-Tasks). Gemessen: rund 1,5 Stunden, danach startet der Pi von selbst ins Scoreboard
- **Den Betreiber von Carambus:** Die Erstbefüllung der Datenbank und die Zugangsschlüssel des Servers kommen
  heute von ihm. Wie ein Verein beides künftig selbst erledigen kann, ist offen.
- **Die ClubCloud:** Spieler und Vereine müssen dort gepflegt sein; den Ergebnis-Upload macht die Turnierleitung
  mit ihrem ClubCloud-Zugang
- **Ein Mail-Konto** für den Versand — oder den bewussten Verzicht auf Mailversand

Ausführlich: [Voraussetzungen für den eigenen Betrieb](deployment-options.md#voraussetzungen).

## Technik

- Ruby on Rails 7.2 (7.2.2.2) auf Ruby 3.2.1, PostgreSQL, Redis; Oberfläche mit Hotwire (Turbo, Stimulus) und
  StimulusReflex/CableReady, Echtzeit über WebSockets
- **Stand der Wartung:** Ruby 3.2 bekommt seit Ende März 2026, Rails 7.2 seit August 2026 keine
  Sicherheitsupdates des Herstellers mehr. Der Umstieg auf neuere Versionen steht noch aus.

## Datenschutz und Sicherheit

- Kontaktdaten von Vereinsmitgliedern (E-Mail, Einwilligung) bleiben auf dem Vereinsserver; Mails an Mitglieder
  gehen nur mit Einwilligung raus.
- Spieler- und Vereinsdaten aus der ClubCloud verteilt die Authority an die Server der Region.
- Externe Dienste nur, wenn sie eingerichtet werden: Anthropic (KI-Suche), Google-Kalender (Tischreservierung),
  YouTube (Streaming).
- Passwörter werden mit bcrypt gespeichert, Zugangsdaten (ClubCloud-Passwörter, Stream-Schlüssel) verschlüsselt.
- Öffentlich erreichbare Server laufen über HTTPS; ein Vereinsserver im Lokal läuft ohne HTTPS auf Port 3131.
- Die Einrichtung per Ansible setzt eine Firewall (nur Web- und SSH-Port) und automatische Sicherheitsupdates
  des Betriebssystems.

## Lizenz und Kosten

- **MIT-Lizenz:** keine Lizenzgebühren, Quellcode frei verfügbar, auch kommerziell nutzbar
- Kosten entstehen für die Hardware und für optionale externe Dienste (etwa den Anthropic-Schlüssel der KI-Suche)

## Im Einsatz

- **Billardclub Wedel 61 e.V.:** Vereinsserver auf einem Raspberry Pi mit Touch-Display — Scoreboards,
  Vereinsturniere, Tischreservierung mit Heizungssteuerung
- Weitere Vereinsserver auf Raspberry Pis und der Region Server des NBV (`nbv.carambus.de`)

## Projekt und Kontakt

Carambus ist ein Einzelentwickler-Projekt und wird aktiv gepflegt ([Über das Projekt](../about.md)). Hilfe gibt
es auf Anfrage.

- **E-Mail:** gernot.ullrich@gmx.de
- **GitHub:** [GernotUllrich/carambus](https://github.com/GernotUllrich/carambus)
