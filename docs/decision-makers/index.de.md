# Für Entscheider

Diese Seiten helfen Vorständen und Sportwarten eines Billardvereins oder Landesverbands bei der Frage, ob
Carambus zu ihnen passt. Sie nennen, was Carambus heute kann, wie es betrieben wird und was ein Verein dafür
braucht — auch dort, wo heute noch der Betreiber von Carambus mithelfen muss.

## Was Carambus ist

Carambus ist eine Web-Anwendung für den Spielbetrieb im Karambol-Billard, entstanden im Billardclub Wedel 61 e.V.
Sie führt Turniere nach den Turnierplänen der Karambol-Turnierordnung, zeigt Scoreboards an den Tischen,
begleitet Ligaspieltage und tauscht Daten mit der DBU-ClubCloud aus. Carambus ist Open Source (MIT-Lizenz).

## Passt Carambus zu uns?

**Carambus passt, wenn …**

- Ihr Verein **Karambol-Turniere** ausrichtet (Freie Partie, Cadre, Einband, Dreiband, Kegelbillard) — nach den
  T-Plänen der Turnierordnung, als Jeder-gegen-Jeden, KO oder Doppel-KO
- Sie **Scoreboards an den Tischen** wollen, die die Spieler selbst bedienen
- Ihre Spieler und Vereine in der **DBU-ClubCloud** gepflegt werden und die Ergebnisse dorthin zurückgehen sollen
- jemand im Verein einen Raspberry Pi per SSH einrichten kann — oder Sie die Einrichtung gemeinsam mit dem
  Betreiber von Carambus machen

**Carambus passt (noch) nicht, wenn …**

- Sie **Pool- oder Snooker-Turniere** durchführen wollen: Dafür gibt es Scoreboards für freie Partien und
  Ligaspieltage, aber keine Turniermodi
- Sie ein System suchen, das ohne den Betreiber von Carambus in Betrieb geht: Die Erstbefüllung der Datenbank und
  die Zugangsschlüssel des Servers kommen heute von ihm (siehe
  [Voraussetzungen für den eigenen Betrieb](deployment-options.md#voraussetzungen))
- Sie ein Online-Buchungssystem, eine App mit Offline-Modus oder Statistik-Auswertungen und Exporte erwarten —
  siehe [Was Carambus nicht kann](features-overview.md#nicht-enthalten)

## Die Seiten dieses Bereichs

| Seite | beantwortet |
|---|---|
| [Executive Summary](executive-summary.md) | Carambus auf einer Seite: Funktionen, Aufbau, Voraussetzungen, Projektlage |
| [Feature-Übersicht](features-overview.md) | Was Carambus kann — und was nicht |
| [Deployment-Optionen](deployment-options.md) | Wie ein Verein oder Verband Carambus betreibt und was er dafür braucht |

Für die technische Umsetzung: [Administrator-Übersicht](../administrators/index.md) und
[Raspberry-Pi-Quickstart](../administrators/raspberry-pi-quickstart.md).

## Nächste Schritte

1. Die [Executive Summary](executive-summary.md) lesen.
2. **Kontakt aufnehmen, bevor Sie Hardware kaufen:** Erstbefüllung und Zugangsschlüssel laufen heute über den
   Betreiber von Carambus.
3. Den Vereinsserver nach dem [Raspberry-Pi-Quickstart](../administrators/raspberry-pi-quickstart.md) einrichten.

## Kontakt {#kontakt}

- **E-Mail:** gernot.ullrich@gmx.de
- **GitHub:** [GernotUllrich/carambus](https://github.com/GernotUllrich/carambus)
- **Referenzverein:** [Billardclub Wedel 61 e.V.](http://www.billardclub-wedel.de/)
