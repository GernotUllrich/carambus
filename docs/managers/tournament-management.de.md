# Turnierverwaltung

Diese Seite führt Sie als Turnierleiter Schritt für Schritt durch ein aus der ClubCloud geladenes Karambol-Turnier — vom Eingang der Einladung bis zum Ergebnis-Upload.

<a id="scenario"></a>
## Szenario

Sie haben als Turnierleiter Ihres Vereins vom NBV eine Einladung zur **NDM Freie Partie Klasse 1–3** per E-Mail als PDF erhalten. Dieses PDF dient im Normalfall als Start-Unterlage für das Turnier-Management. Das Turnier läuft an einem Samstag in Ihrem Spiellokal mit 5 gemeldeten Teilnehmern auf zwei Tischen. Diese Seite begleitet Sie Schritt für Schritt vom Eingang der Einladung bis zur Abgabe der Ergebnisse an die ClubCloud.

Für abweichende Spezialfälle finden sich im Anhang spezialisierte Abläufe:

- **[Einladung fehlt](#appendix-no-invitation)** — Ablauf ohne PDF-Einladung
- **[Spieler fehlt](#appendix-missing-player)** — Umgang mit nicht-erschienenen gemeldeten Spielern
- **[Spieler wird nachgemeldet](#appendix-nachmeldung)** — On-site-Nachmeldung am Turniertag

<a id="walkthrough"></a>
## Durchführung Schritt für Schritt

Die folgende Anleitung orientiert sich am tatsächlichen Ablauf des Carambus-Wizards — so wie er in der Praxis funktioniert. Wo die Oberfläche ungewohnte Formulierungen oder unerwartetes Verhalten zeigt, finden Sie einen farbigen Hinweiskasten.

!!! info "Schritt-Nummerierung ist logisch, nicht UI-eins-zu-eins"
    Die im Folgenden nummerierten Schritte 1–14 sind eine **logisch-chronologische** Aufzählung. Die zugehörigen UI-Screens sind historisch gewachsen und zählen teilweise anders: Schritte 2–5 liegen alle auf der Wizard-Seite, Schritt 6 hat einen eigenen Mode-Selection-Screen, Schritte 7–8 sind dieselbe Parametrisierungsseite, ab Schritt 9 wechselt der Ablauf in den Turnier-Monitor und die Tisch-Scoreboards. Während des laufenden Spielbetriebs (Schritte 10–12) hat der Turnierleiter im Standardfall **keine aktive Rolle** — die Aktionen finden alle an den Scoreboards statt.

<a id="step-1-invitation"></a>
### Schritt 1: Die NBV-Einladung erhalten

Sie erhalten vom Landessportwart per E-Mail eine PDF-Einladung zur NDM. Die Einladung enthält den offiziellen Turnierplan, die **Meldeliste** (Setzliste-Snapshot nach dem Meldeschluss) und die Startzeiten. Außerdem stehen in der Einladung die **Ausspielziele** für die Disziplin: das **Ballziel** (allgemein für alle Spieler bei Normalturnieren, oder individuell pro Spieler bei Vorgabeturnieren) und die **Aufnahmebegrenzung**. Diese Werte tragen Sie später in [Schritt 7](#step-7-start-form) in das Start-Formular ein.

Drei Begriffe sollten Sie auseinanderhalten — sie beschreiben dieselben Spieler zu unterschiedlichen Zeitpunkten:

- **Setzliste** — geseedete/geordnete Liste der Anmelder, gepflegt während der Meldeperiode
- **Meldeliste** — Snapshot der Setzliste nach dem Meldeschluss (das, was in der Einladung steht)
- **Teilnehmerliste** — wer **tatsächlich** am Turniertag antritt (wird kurz vor Turnierbeginn finalisiert)

Im [Glossar](#glossary-wizard) finden Sie die Begriffe noch einmal mit ihrem zeitlichen Zusammenhang.

Sie müssen in diesem Schritt noch nichts im System klicken — öffnen Sie die Einladung, legen Sie das PDF bereit, und öffnen Sie dann in Carambus die Turnier-Detailseite des NDM-Turniers.

<a id="step-2-load-clubcloud"></a>
### Schritt 2: Turnier aus ClubCloud laden (Wizard Schritt 1)

**Navigation zur Turnierseite:** Im Carambus-Hauptmenü öffnen Sie **Organisationen → Regionalverbände → NBV** und klicken dort auf den Link **„Aktuelle Turniere in der Saison 2025/2026"** (die Saison ist dynamisch). In der Turnierliste wählen Sie das passende Turnier aus (im Beispielszenario „NDM Freie Partie Klasse 1–3").

Auf der Turnier-Detailseite sehen Sie oben den Wizard-Fortschrittsbalken „Turnier-Setup". Schritt 1 „Meldeliste von ClubCloud laden" ist in der Regel bereits automatisch abgeschlossen — ein grüner Haken (GELADEN) zeigt an, dass Carambus die Meldeliste bereits synchronisiert hat.

**Achtung:** Die ClubCloud liefert manchmal weniger Spieler als erwartet — in der Praxis wurden bei einem 5-Spieler-Turnier zunächst nur 1–2 Registrierungen übertragen. Der Wizard zeigt einen grünen „Weiter zu Schritt 3 mit diesen N Spielern"-Button, auch wenn N verdächtig niedrig ist. Prüfen Sie die Zahl sorgfältig, bevor Sie weitergehen. Wenn Spieler fehlen, beheben Sie das in [Schritt 4](#step-4-participants). Weitere Details finden Sie unter [Spieler nicht in der ClubCloud-Meldeliste](#ts-player-not-in-cc).

![Wizard-Übersicht nach ClubCloud-Sync](images/tournament-wizard-overview.png){ loading=lazy }
*Abbildung: Turnier-Setup-Wizard nach erfolgreichem ClubCloud-Sync — die typische Standard-Darstellung, wenn der Sync vollständig durchgelaufen ist (Beispiel aus dem Phase-33-Audit, NDM Freie Partie Klasse 1–3). Den im Achtung-Block beschriebenen 1-Spieler-Fall illustriert dieses Bild **nicht** — er tritt nur bei unvollständigem Sync auf.*

<a id="step-3-seeding-list"></a>
### Schritt 3: Setzliste übernehmen oder erzeugen

Die **Setzliste** ist ein **Ergebnis**: Meldeliste plus Ordnung. Die Ordnung wird normalerweise vom Landessportwart in der Einladung vorgegeben (anhand seiner Spreadsheets mit den zusammengeführten Turnierergebnissen). Sie ist keine Quelle, die Sie irgendwoher „herunterladen".

**Im Normalfall (mit Einladung):** Sie laden das PDF der Einladung in Wizard-Schritt 2 hoch. Carambus liest die Setzliste aus dem PDF und gleicht sie anschließend mit der ClubCloud-Meldeliste ab. Abweichungen werden Ihnen zur Klärung angezeigt.

**Wenn die Einladung fehlt:** Sie übernehmen die initiale Teilnehmerliste aus der ClubCloud-Meldeliste (orientiert am Meldestatus zum Meldeschluss) und ordnen sie anschließend in [Schritt 4](#step-4-participants) per Klick auf **„Nach Ranking sortieren"** anhand der in Carambus gepflegten [Rangliste](#glossary-system) — den vollständigen Ablauf finden Sie im Anhang [Einladung fehlt](#appendix-no-invitation).

Wenn das PDF-Upload technisch fehlschlägt (häufig bei bestimmten Druckvorlagen), lesen Sie [Einladungs-PDF konnte nicht hochgeladen werden](#ts-invitation-upload).

<a id="step-4-participants"></a>
### Schritt 4: Teilnehmerliste prüfen und ergänzen (Wizard Schritt 3)

**Wie komme ich in die Teilnehmerliste-Bearbeitung?** Es gibt drei mögliche Einstiegspunkte, abhängig vom aktuellen Wizard-Zustand:

1. **Direkt aus Schritt 3** — nachdem Sie in Schritt 3 die Setzliste übernommen haben, leitet Sie der Wizard automatisch in die Bearbeitung weiter
2. **Über den Button am unteren Ende der Turnierseite** — auch wenn Wizard-Schritt 3 noch nicht aktiv ist, ist der Zugang über diesen Bottom-Link möglich
3. **Über die Aktion „Einladung hochladen"** — auch wenn Sie keine Einladung haben, ist dieser Eingangspunkt nutzbar: im Einladungs-Hochladen-Formular finden Sie den Link **„→ Mit Meldeliste zu Schritt 3 (nach Rangliste sortiert)"**

Die Mehrfach-UX ist historisch gewachsen — alle drei Wege landen auf derselben Bearbeitungsseite.

In Wizard-Schritt 3 „Teilnehmerliste bearbeiten" sehen Sie die aktuell vorhandenen Teilnehmer. Fehlen Spieler, tragen Sie deren [DBU-Nummern](#glossary-system) komma-getrennt im Feld **„Spieler mit DBU-Nummer hinzufügen"** ein (Beispiel: `121308, 121291, 121341, 121332`) und klicken anschließend auf den Link **„Spieler hinzufügen"**, um die Eingabe anzuwenden.

Klicken Sie oben auf **„Nach Ranking sortieren"**, um die Teilnehmerliste automatisch nach der aktuellen [Rangliste](#glossary-system) zu ordnen — das ist für eine NDM Freie Partie fast immer die richtige Reihenfolge.

Sobald die Teilnehmerzahl einem vordefinierten [Turnierplan](#glossary-wizard) entspricht, erscheint unter der Teilnehmerliste ein gelb hervorgehobenes Panel **„Mögliche Turnierpläne für N Teilnehmer — automatisch vorgeschlagen: T04"**. Bei 5 Teilnehmern wird Ihnen T04 vorgeschlagen (die Planbezeichnungen wie T04 stammen aus der offiziellen Karambol-Turnierordnung). Das ist der beste Hinweis, dass die Teilnehmerzahl stimmt — wenn kein Plan vorgeschlagen wird, überprüfen Sie die Teilnehmerzahl. Die endgültige Modusauswahl erfolgt erst in Schritt 6.

Die meisten Änderungen — Sortierung, in-place-Edits einzelner Felder — werden sofort gespeichert. **Ausnahme:** Für das Hinzufügen neuer Spieler per DBU-Nummer ist der Klick auf den Link **„Spieler hinzufügen"** erforderlich.

<a id="step-5-finish-seeding"></a>
### Schritt 5: Teilnehmerliste abschließen

**Wichtig zum Verständnis:** Die im Wizard angezeigten „Schritt 4" und „Schritt 5" sind **keine eigenen Wizard-Zustände**, sondern **Aktions-Links** auf der Teilnehmerliste-Seite:

- **„Schritt 4: Teilnehmerliste bearbeiten"** — Link zur weiteren Bearbeitung der Teilnehmerliste
- **„Schritt 5: Teilnehmerliste abschließen"** — Link, der den State-Übergang auslöst und in die Turniermodus-Auswahl führt

Zwischen den beiden gibt es im Wizard keinen separaten Zustand. Der Wizard-Fortschrittsbalken springt nach dem Abschließen direkt zur Modus-Auswahl, weil „Schritt 4" eben nur ein Aktions-Link war.

Wenn die Teilnehmerliste vollständig ist, klicken Sie auf den Link **„Teilnehmerliste abschließen"**. Damit wird die [Setzliste](#glossary-wizard) festgeschrieben und das Turnier geht in den nächsten Wizard-Zustand über („Schritt 5: Turniermodus festlegen").

!!! warning "Teilnehmerliste abschließen — was ist möglich, was nicht"
    Der Klick auf **Teilnehmerliste abschließen** ist normalerweise verbindlich:
    Sie wechseln in die Turniermodus-Auswahl und können die Teilnehmerliste
    nicht über den normalen Wizard-Pfad mehr ändern. **Im Notfall** können Sie
    aber das gesamte Turnier-Setup über den Link **„Zurücksetzen des
    Turnier-Monitors"** am unteren Ende der Turnierseite zurücksetzen — das
    ist möglich, aber bei bereits laufendem Turnier mit Datenverlust
    verbunden (siehe [Schritt 12](#step-12-monitor) für die Details).
<!-- ref: F-09 -->

<a id="step-6-mode-selection"></a>
### Schritt 6: Turniermodus auswählen

Wizard-Schritt 5 öffnet eine separate Seite „Abschließende Auswahl des Austragungsmodus". Sie sehen drei Karten mit den verfügbaren [Turnierplänen](#glossary-wizard): typischerweise **T04**, **T05** und **DefaultS**. Jede Karte zeigt die Spielrunden-Zahl und Turniertage. Bei 5 Teilnehmern lautet der Vorschlag meist T04 (5 Spielrunden, 1 Turniertag, 2 Tische).

!!! tip "Welchen Turnierplan wählen?"
    Bei der Modus-Auswahl schlägt Carambus meist einen Plan automatisch vor
    (zum Beispiel **T04** bei 5 Teilnehmern). Übernehmen Sie den Vorschlag,
    wenn Sie nicht bewusst eine Alternative bevorzugen. Die Alternativen
    unterscheiden sich vor allem in der Zahl der Spielrunden und Turniertage
    — für eine typische NDM Freie Partie Klasse 1–3 ist der Vorschlag fast
    immer der richtige.
<!-- ref: F-12 -->

Klicken Sie auf **„Weiter mit T04"** (oder dem vorgeschlagenen Plan). Die Auswahl wird **sofort und ohne Bestätigungsdialog** angewendet. Wenn Sie versehentlich den falschen Plan gewählt haben, lesen Sie [Falscher Turniermodus gewählt](#ts-wrong-mode).

![Modus-Auswahl mit T04-Vorschlag](images/tournament-wizard-mode-selection.png){ loading=lazy }
*Abbildung: Modus-Auswahl mit den drei Turnierplänen und automatischem Vorschlag T04 bei 5 Teilnehmern (Beispiel aus dem Phase-33-Audit).*

<a id="step-7-start-form"></a>
### Schritt 7: Start-Parameter ausfüllen

Nach der Modusauswahl öffnet sich das Start-Formular. Oben sehen Sie eine Zusammenfassung des gewählten Modus, darunter den Abschnitt **„Zuordnung der Tische"** und ein Formular **„Turnier Parameter"** mit ca. 15 Feldern.

!!! tip "Englische Feldbezeichnungen im Start-Formular"
    Einige Parameter im Start-Formular heißen derzeit auf Englisch oder sind
    unklar beschriftet (zum Beispiel *Tournament manager checks results before
    acceptance* oder *Assign games as tables become available*). Das
    [Glossar](#glossary) unten erklärt die wichtigsten Begriffe. Im Zweifel
    übernehmen Sie die Standardwerte und kontrollieren Sie die Einstellungen
    nach dem Turnier.
<!-- ref: F-14 -->

Die wichtigsten Felder für eine NDM Freie Partie:

- **Bälle vor** / **Bälle-Ziel** ([innings_goal](#glossary-karambol)): Das Ziel in [Bällen](#glossary-karambol), das ein Spieler erreichen muss, um eine [Partie](#glossary-karambol) zu gewinnen. Für Freie Partie Klasse 1–3 liegen typische Werte zwischen 50 und 150 Bällen — prüfen Sie die Einladung.
- **Aufnahmebegrenzung** ([Aufnahme](#glossary-karambol)): Maximale Zahl der Aufnahmen pro Partie. 0 = unbegrenzt.
- **Tournament manager checks results before acceptance**: Wenn aktiviert, müssen Sie jedes Ergebnis manuell bestätigen, bevor es gezählt wird. Für kleine Turniere mit verlässlichen Scoreboard-Helfern können Sie das deaktivieren.

Füllen Sie die Felder aus und gehen Sie direkt zu [Schritt 8](#step-8-tables) für die Tischzuordnung.

<a id="step-8-tables"></a>
### Schritt 8: Tische zuordnen

Im Abschnitt **„Zuordnung der Tische"** weisen Sie den Turnier-Spielrunden die physischen Tische zu. Wählen Sie aus der Dropdown-Liste die zwei Tische in Ihrem Spiellokal aus. Die Tischnamen entsprechen den in Carambus angelegten Tisch-Datensätzen. Für unser NDM-Szenario wählen Sie Tisch 1 und Tisch 2.

Die Zuordnung ist unkritisch — Sie können im Turnier-Monitor nachträglich keine Tische mehr tauschen, aber die Scoreboard-Verbindung funktioniert unabhängig von dieser Zuordnung (die Scoreboards verbinden sich nach dem Start automatisch mit dem zugewiesenen Tisch).

<a id="step-9-start"></a>
### Schritt 9: Turnier starten

Wenn Tischzuordnung und Turnier-Parameter vollständig sind, klicken Sie unten auf **„Starte den Turnier Monitor"**.

!!! warning "Warten, nicht erneut klicken"
    Nach dem Klick auf **Starte den Turnier Monitor** sieht die Seite mehrere
    Sekunden lang unverändert aus. Das ist normal — der Wizard bereitet im
    Hintergrund die Tisch-Monitore vor. **Klicken Sie den Button nicht erneut**
    und navigieren Sie nicht zurück. Nach wenigen Sekunden öffnet sich der
    Turnier-Monitor automatisch.
<!-- ref: F-19 -->

Im Hintergrund löst Carambus das AASM-Event `start_tournament!` aus (Übergang nach `tournament_started_waiting_for_monitors`), initialisiert alle TableMonitors und leitet Sie dann automatisch zur Turnier-Monitor-Seite weiter. Wenn sich die Seite nach 30 Sekunden nicht ändert, prüfen Sie, ob Redis und der ActionCable-Dienst laufen.

<a id="step-10-warmup"></a>
### Schritt 10: Warmup-Phase beobachten

Nachdem der Turnier-Monitor geöffnet ist, sehen Sie die Übersichtsseite „Turnier-Monitor · NDM Freie Partie Klasse 1–3". Jeder der zwei Tische zeigt einen Status-Badge **„warmup"** und die zugewiesenen Spielerpaare für Partie 1 (z. B. „Simon, Franzel / Smrcka, Martin" auf Tisch 1).

In der Warmup-Phase können die Spieler die Tische und Bälle ausprobieren. Die Scoreboards sind bereits aktiv, aber die Punkte zählen noch nicht. Im Abschnitt „Aktuelle Spiele Runde 1" sehen Sie alle 4 Matches der ersten Runde mit den Spalten Tisch / Gruppe / Partie / Spieler und einem **„Spielbeginn"**-Button pro Zeile.

Sie müssen hier nichts aktiv tun — beobachten Sie, ob alle Scoreboards verbunden sind (grüner Status), und warten Sie auf den Startschuss des Turniers.

![Turnier-Monitor-Landingpage in der Warmup-Phase](images/tournament-monitor-landing.png){ loading=lazy }
*Abbildung: Turnier-Monitor direkt nach dem Start — beide Tische zeigen Status „warmup" und die Paarungen der ersten Runde (Beispiel aus dem Phase-33-Audit).*

<a id="step-11-release-match"></a>
### Schritt 11: Spielbeginn freigeben

Wenn der Warmup abgeschlossen ist und alle Spieler bereit sind, klicken Sie für jede Partie in der Tabelle „Aktuelle Spiele Runde 1" auf den Button **„Spielbeginn"**. Dieser Klick startet die Zeitmessung und aktiviert die Ball-Eingabe am [Scoreboard](#glossary-wizard).

In unserem Szenario mit 5 Teilnehmern und 2 Tischen laufen in Runde 1 gleichzeitig 2 Partien — klicken Sie also nacheinander auf zwei „Spielbeginn"-Buttons. Der fünfte Spieler sitzt in Runde 1 aus (Freilos, abhängig vom gewählten Turnierplan).

<a id="step-12-monitor"></a>
### Schritt 12: Ergebnisse verfolgen

Nach dem Spielbeginn übernehmen die Spieler die Scoreboard-Eingabe. Der Turnier-Monitor aktualisiert sich in Echtzeit über ActionCable — Sie müssen die Seite nicht neu laden.

Beobachten Sie die Spaltenwerte **Bälle** / **Aufnahme** / **HS** ([Höchstserie](#glossary-karambol)) / **GD** ([Generaldurchschnitt](#glossary-karambol)) in der Spiele-Tabelle. Wenn eine Partie abgeschlossen ist, wechselt die Tischkarte automatisch zur nächsten Partie in der Runde. Nach Abschluss aller Partien einer [Spielrunde](#glossary-karambol) schaltet der Monitor auf Runde 2, und die nächste Paarung erscheint.

Als Turnierleiter greifen Sie normalerweise nicht aktiv ein — außer wenn ein Spieler ein Ergebnis anfechtet oder ein Scoreboard-Problem vorliegt. Wenn Sie „Tournament manager checks results before acceptance" aktiviert haben, erscheint nach jedem Spiel ein Bestätigungs-Button für Sie.

<a id="step-13-finalize"></a>
### Schritt 13: Turnier finalisieren

Nach Abschluss aller Runden erscheint im Turnier-Monitor eine Schaltfläche zum Finalisieren des Turniers. Klicken Sie darauf, um die Endrangliste zu berechnen und das Turnier in den Abschlussstatus zu setzen.

Falls Platzierungen noch angepasst werden müssen (z. B. wegen eines Steches oder einer manuellen Korrektur), lesen Sie die Details in der [Einzelturnier-Verwaltung](single-tournament.md), die den Platzierungs-Workflow ausführlich beschreibt.

Nach dem Finalisieren ist das Turnier abgeschlossen — Änderungen an Ergebnissen sind nur noch über Admin-Eingriff möglich.

<a id="step-14-upload"></a>
### Schritt 14: Ergebnis-Upload nach ClubCloud

Wenn im Start-Formular (Schritt 7) die Option **„auto_upload_to_cc"** aktiviert war, überträgt Carambus die Ergebnisse beim Finalisieren automatisch zurück an die ClubCloud. Sie sehen anschließend eine Bestätigung, dass der Upload erfolgreich war.

Wenn der automatische Upload deaktiviert ist oder fehlschlägt, können Sie den Upload manuell auf der Turnier-Detailseite anstoßen (Schaltfläche „Ergebnisse nach ClubCloud übertragen"). Prüfen Sie in der ClubCloud, ob die Ergebnisse angekommen sind — normalerweise sind sie innerhalb weniger Minuten sichtbar.

---

<a id="glossary"></a>
## Glossar

<a id="glossary-karambol"></a>
### Karambol-Begriffe

- **Freie Partie** — Die einfachste Karambol-Disziplin: Ein Punkt pro korrektem Karambolage (der gespielte Ball berührt beide anderen Bälle), keine Feldbeschränkung. Typische [Bälle-Ziele](#glossary-karambol) für NDM-Klassen liegen bei 50–150 Bällen. *Sie konfigurieren diesen Wert im [Start-Formular, Schritt 7](#step-7-start-form).*

- **Cadre (35/2, 47/1, 47/2, 71/2)** — Karambol-Disziplinen mit Balken-Feldbeschränkung (Cadre = frz. Rahmen). Der erste Wert bezeichnet die Feldgröße in cm, der zweite die maximal erlaubten Bälle pro Feld. Cadre-Turniere verwenden dieselben Wizard-Schritte wie Freie Partie, aber mit anderen Standard-Bällezielen.

- **Dreiband** — [Karambol](#glossary-karambol)-Disziplin: Der gespielte Ball muss vor dem zweiten Objektball mindestens drei Banden berühren. Keine Feldbeschränkung. *Sie sehen diese Disziplin in der Turnier-Detailseite.*

- **Einband** — Karambol-Disziplin: Der gespielte Ball muss mindestens eine Bande berühren, bevor er den zweiten Objektball trifft.

- **Aufnahme** — Eine Aufnahme (auch: Inning) ist ein Spielzug — der Spieler schlägt an, bis er keinen Punkt erzielt oder das [Bälle-Ziel](#glossary-karambol) erreicht. Die **Aufnahmebegrenzung** im Start-Formular legt die maximale Aufnahmen-Anzahl pro Partie fest (0 = unbegrenzt). *Sie sehen diesen Begriff im [Start-Formular, Schritt 7](#step-7-start-form).*

- **Bälle-Ziel (innings_goal)** — Die Zahl der Punkte (Karambolagen), die ein Spieler erzielen muss, um eine Partie zu gewinnen. Im System-Code heißt das Feld `innings_goal` (englisch) — im Start-Formular erscheint es als „Bälle vor". *Sie konfigurieren diesen Wert im [Start-Formular, Schritt 7](#step-7-start-form). Weitere Erklärung zu den englischen Feldbezeichnungen im [dortigen Hinweiskasten](#step-7-start-form).*

- **Höchstserie (HS)** — Die längste Serie an aufeinanderfolgenden Karambolagen in einer Partie oder im gesamten Turnier. Wird im [Turnier-Monitor](#step-12-monitor) in Echtzeit angezeigt.

- **Generaldurchschnitt (GD)** — Erzielte Bälle geteilt durch die Anzahl der Aufnahmen. Maßstab für die Spielstärke über ein Turnier. Wird im [Turnier-Monitor](#step-12-monitor) angezeigt.

- **Spielrunde** — Eine vollständige Runde des Turniers, in der jeder Spieler (oder jedes Paar) einmal antritt. Ein T04-Turnierplan hat 5 Spielrunden. Nach jeder Runde aktualisiert der Turnier-Monitor automatisch die Tabelle.

- **Tisch-Warmup** — Die Phase nach dem [Turnier starten](#step-9-start), in der die Tische den Status `warmup` tragen und Spieler die Bälle und den Tisch ausprobieren können, ohne dass Punkte zählen. Endet, wenn Sie [Spielbeginn freigeben](#step-11-release-match).

<a id="glossary-wizard"></a>
### Wizard-Begriffe

- **Setzliste** — Die geordnete Teilnehmerliste mit Setzposition (Platz 1 = gesetzt, Platz N = ungesetzt). Wird in [Schritt 3](#step-3-seeding-list) aus der Einladung oder der ClubCloud übernommen und in [Schritt 4](#step-4-participants) ergänzt. Das Abschließen der Setzliste in [Schritt 5](#step-5-finish-seeding) ist irreversibel.

- **Turniermodus / Austragungsmodus** — Die Spielform des Turniers (z. B. Jeder-gegen-Jeden, KO-System). Die Auswahl erfolgt in [Schritt 6](#step-6-mode-selection). Der Modus bestimmt den zugrunde liegenden Turnierplan (T04, T05, DefaultS) und damit Spielrunden-Zahl und Turniertage.

- **Turnierplan-Kürzel (T04, T05, Default5)** — Interne Bezeichnungen für vordefinierte Turnierpläne. **T** steht für Turnierplan, die Zahl für den Plancode. T04 und T05 sind die gängigen Pläne für 5-Spieler-Turniere im Jeder-gegen-Jeden-Format — sie unterscheiden sich hauptsächlich in der Zahl der Spielrunden. DefaultS ist ein flexibleres Format. *Sie wählen den Plan in [Schritt 6](#step-6-mode-selection).*

- **Scoreboard** — Das berührungsempfindliche Eingabegerät an jedem Tisch, über das die Spieler oder ein Helfer die Punkte live eingeben. Die Scoreboards verbinden sich nach dem [Turnier starten](#step-9-start) automatisch mit dem Turnier-Monitor. Ohne aktive Scoreboard-Verbindung können keine Punkte erfasst werden.

<a id="glossary-system"></a>
### System-Begriffe

- **ClubCloud** — Die regionale Anmeldeplattform des DBU (Deutscher Billard-Union). ClubCloud ist die Quelle der Wahrheit für Spieler-Registrierungen und Meldelisten. Carambus synchronisiert die Teilnehmerliste aus ClubCloud in [Schritt 2](#step-2-load-clubcloud). Weitere Informationen finden Sie in der [ClubCloud-Integration](clubcloud-integration.md).

- **AASM-Status** — Der interne Zustand des Turniers im System, verwaltet durch die AASM-Zustandsmaschine (Acts As State Machine). Mögliche Zustände umfassen `new_tournament`, `tournament_seeding_finished`, `tournament_started_waiting_for_monitors`, `tournament_started` und weitere. Die Wizard-Schrittanzeige spiegelt diesen Status wider — Schritt 4 erledigt = `tournament_seeding_finished`, Turnier gestartet = `tournament_started`. *Phase 36 wird dieses Status-Badge im Wizard sichtbarer machen.*

- **DBU-Nummer** — Die nationale Spieler-ID des Deutschen Billard-Union. Jeder lizenzierte Spieler hat eine eindeutige DBU-Nummer. In [Schritt 4](#step-4-participants) können Sie Spieler, die nicht in der ClubCloud-Meldeliste erscheinen, über ihre DBU-Nummer nachtragen (komma-getrennt im Eingabefeld).

- **Rangliste** — Die regionale Spielerrangliste, die von der ClubCloud-Datenbank bezogen wird. In [Schritt 4](#step-4-participants) können Sie mit „Nach Ranking sortieren" die Teilnehmerliste automatisch nach Ranglistenposition ordnen — das entspricht der offiziellen Setzliste für die meisten NBV-Turniere.

---

<a id="troubleshooting"></a>
## Problembehebung

<a id="ts-invitation-upload"></a>
### Einladungs-PDF konnte nicht hochgeladen werden

**Problem:** Der Upload-Dialog in Schritt 3 zeigt einen Fehler, dreht sich im Kreis (unendlicher Spinner) oder die PDF-Datei wird hochgeladen, aber die Setzliste bleibt leer.

**Ursache:** Der PDF-Parser von Carambus kann bestimmte NBV- und DBU-Druckvorlagen nicht zuverlässig auslesen — besonders wenn die PDF-Datei gescannt (kein maschinenlesbarer Text), zu niedrig aufgelöst oder mit einem nicht-standardisierten Seitenformat erstellt wurde. OCR-Fehler sind häufig bei Einladungen, die als Bild-Scan vorliegen.

**Lösung:** Nutzen Sie direkt die **ClubCloud-Meldeliste als Quelle** — das ist die „Alternative" in Schritt 3. Klicken Sie auf „ClubCloud-Meldeliste verwenden", um die Teilnehmer direkt aus dem ClubCloud-Sync zu übernehmen. Ergänzen Sie anschließend in [Schritt 4](#step-4-participants) ggf. fehlende Spieler über ihre DBU-Nummer. Die ClubCloud-Route ist für reine NBV-Turniere in der Praxis zuverlässiger als der PDF-Upload.

<a id="ts-player-not-in-cc"></a>
### Spieler nicht in der ClubCloud-Meldeliste

**Problem:** Nach dem ClubCloud-Sync in Schritt 2 wurden weniger Spieler geladen als erwartet. Der Wizard zeigt „Weiter zu Schritt 3 mit diesen N Spielern" mit einem grünen Button, obwohl N zu niedrig ist (z. B. 1 statt 5).

**Ursache:** Die ClubCloud-Synchronisation liefert manchmal unvollständige Ergebnisse — ein bekanntes Verhalten (F-03/F-04), das auftreten kann, wenn Anmeldungen in ClubCloud noch nicht vollständig bestätigt sind, oder wenn die Sync-Verbindung eine teilweise Antwort liefert. Der grüne Button wirkt irreführend vollständig, obwohl die Datenlage unvollständig ist.

**Lösung:** Klicken Sie **nicht** auf „Weiter" wenn die Spielerzahl zu niedrig ist. Navigieren Sie stattdessen zu **[Schritt 4](#step-4-participants)** und fügen Sie die fehlenden Spieler über das Feld „Spieler mit DBU-Nummer hinzufügen" manuell nach (mehrere DBU-Nummern komma-getrennt). Die Einladungs-PDF enthält typischerweise alle DBU-Nummern der angemeldeten Spieler.

<a id="ts-wrong-mode"></a>
### Falscher Turniermodus gewählt

**Problem:** Sie haben in Schritt 6 auf eine der drei Modus-Karten (T04, T05, DefaultS) geklickt und damit den falschen Plan aktiviert. Das Start-Formular hat sich bereits geöffnet.

**Ursache:** Die Modus-Auswahl wird in Carambus unmittelbar beim Klick angewendet — ohne Bestätigungsdialog (F-13). Es gibt keinen „Zurück"-Button, der den Modus sicher rückgängig macht.

**Lösung:** Wenn das Turnier **noch nicht gestartet** ist (Schritt 9 noch nicht ausgeführt), navigieren Sie zur Wizard-Übersicht (Turnier-Detailseite) und wählen Sie über die Schaltfläche „Modus ändern" einen anderen Plan. Wenn **`start_tournament!` bereits ausgelöst** wurde, ist der Modus nicht mehr über die normale Oberfläche änderbar — lesen Sie dann [Turnier wurde bereits gestartet](#ts-already-started). Browser-Back ist in diesem Zustand riskant und sollte vermieden werden.

<a id="ts-already-started"></a>
### Turnier wurde bereits gestartet

**Problem:** Sie möchten Teilnehmer, Turniermodus oder Start-Parameter ändern, aber der Wizard zeigt bereits den Turnier-Monitor und die Detailseite zeigt „Turnier läuft".

**Ursache:** Das AASM-Event `start_tournament!` (ausgelöst in [Schritt 9](#step-9-start)) ist irreversibel — es gibt in der aktuellen Version (v7.0 Scope) **keinen Undo-Pfad** für gestartete Turniere (F-19, Tier 3 Finding). Das ist eine bewusste Designentscheidung, um Datenkonsistenz bei laufenden Scoreboards zu gewährleisten.

**Lösung:** Wenden Sie sich an einen **Carambus-Admin mit Datenbankzugang**. Eine typische Recovery-Methode ist: das laufende Turnier als fehlerhaft markieren, eine neue Turnier-Instanz mit korrekten Parametern anlegen und ggf. bereits eingetragene Ergebnisse manuell übertragen. Diese Operation ist nicht für Vereinsfunktionäre gedacht und sollte durch sorgfältiges Prüfen in [Schritt 5](#step-5-finish-seeding) (Teilnehmerliste) und [Schritt 6](#step-6-mode-selection) (Turniermodus) vermieden werden. Der Hinweiskasten in [Schritt 9](#step-9-start) weist ausdrücklich darauf hin, nicht erneut zu klicken oder zurückzunavigieren.

---

<a id="architecture"></a>
## Mehr zur Technik

Carambus ist ein verteiltes System aus mehreren Web-Diensten: Ein zentraler API-Server veröffentlicht Turniere und Spielerdaten (z. B. NBV-Turniere über carambus.net); regionale und vereinseigene Carambus-Server synchronisieren diese Daten und übernehmen die Turnierleitung vor Ort. Globale Datensätze — also Turniere, die vom API-Server synchronisiert wurden — sind für Identitätsfelder (Titel, Datum, Veranstalter) schreibgeschützt (LocalProtector); Ihre lokale Instanz verwaltet den Wizard-Status, die Teilnehmerliste und die Spielergebnisse.

Für die Durchführung eines Turniers nach dieser Anleitung müssen Sie das Innenleben nicht verstehen. Wenn Sie die obigen Schritte befolgt haben, wissen Sie alles, was Sie für einen reibungslosen Turniertag brauchen. Für weiterführende technische Details — Datenbankstruktur, ActionCable-Konfiguration, Deployment — lesen Sie die [Entwickler-Dokumentation](../developers/index.md).
