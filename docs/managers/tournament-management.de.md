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

Wizard-Schritt 5 öffnet eine separate Seite „Abschließende Auswahl des Austragungsmodus". Sie sehen **eine oder mehrere Karten** mit den verfügbaren [Turnierplänen](#glossary-wizard) — die Auswahl hängt von der Teilnehmerzahl ab und enthält nur Pläne, die zur aktuellen Teilnehmerzahl passen, plus den dynamisch generierten Plan **`Default{n}`**, wobei `{n}` die aktuelle Teilnehmerzahl ist.

`Default{n}` ist ein **dynamisch generierter Jeder-gegen-Jeden-Plan**, dessen benötigte Tischanzahl aus der Teilnehmerzahl berechnet wird. Die T-Pläne (T04, T05, …) haben dagegen feste Spielstruktur und Tischanzahl aus der Karambol-Turnierordnung.

Bei 5 Teilnehmern lautet der Vorschlag typischerweise **T04** (Standard für 5 Spieler aus der Sportordnung). Der **in der Einladung angegebene Turnierplan** ist im Normalfall der vom Landessportwart verbindlich vorgegebene — übernehmen Sie diesen Vorschlag.

Klicken Sie auf **„Weiter mit T04"** (oder dem vorgeschlagenen Plan). Die Auswahl wird **sofort und ohne Bestätigungsdialog** angewendet. Wenn Sie versehentlich den falschen Plan gewählt haben, lesen Sie [Falscher Turniermodus gewählt](#ts-wrong-mode).

![Modus-Auswahl mit T04-Vorschlag](images/tournament-wizard-mode-selection.png){ loading=lazy }
*Abbildung: Modus-Auswahl mit den drei Turnierplänen und automatischem Vorschlag T04 bei 5 Teilnehmern (Beispiel aus dem Phase-33-Audit).*

<a id="step-7-start-form"></a>
### Schritt 7: Start-Parameter und Tischzuordnung ausfüllen

!!! info "Schritte 7 und 8 leben auf derselben Seite"
    Nach der Modusauswahl öffnet sich **eine** Parametrisierungsseite, die
    sowohl die Start-Parameter als auch die Tischzuordnung enthält. Im Doc
    sind sie aus didaktischen Gründen zwei Schritte — im UI ist es eine
    Seite.

Oben sehen Sie eine Zusammenfassung des gewählten Modus, darunter den Abschnitt **„Zuordnung der Tische"** und ein Formular **„Turnier Parameter"** mit den Spielregeln.

!!! tip "Englische Feldbezeichnungen im Start-Formular"
    Einige Parameter im Start-Formular heißen derzeit auf Englisch oder sind
    unklar beschriftet (zum Beispiel *Tournament manager checks results before
    acceptance* oder *Assign games as tables become available*). Das
    [Glossar](#glossary) unten erklärt die wichtigsten Begriffe. Im Zweifel
    übernehmen Sie die Standardwerte und kontrollieren Sie die Einstellungen
    **vor dem Start des Turniers**.
<!-- ref: F-14 -->

**Die wesentlichen Parameter, die Sie kennen müssen:**

- **Tischzuordnung** (siehe Abschnitt unten in diesem Schritt) — welche **physikalischen Tische** in Ihrem Spiellokal die **logischen Tische** des Turnierplans abbilden
- **Ballziel** (`balls_goal`): Das Ziel in Bällen, das ein Spieler für den Partie-Gewinn erreichen muss. Für Freie Partie Klasse 1–3 steht der Wert in der Einladung (typischerweise **150 Bälle**, ggf. um 20 % reduziert). Maßgeblich ist die Karambol-Sportordnung.
- **Aufnahmebegrenzung** (`innings_goal`): Maximale Aufnahmenzahl pro Partie. Für Freie Partie Klasse 1–3 typischerweise **50 Aufnahmen** (ggf. um 20 % reduziert). **Leerfeld oder 0 = unbegrenzt** (im UI nicht eindeutig dokumentiert — bitte hier nachlesen).
- **Spielabschluss** durch Manager oder durch Spieler — wer bestätigt das Ergebnis am Scoreboard nach Partie-Ende
- **`auto_upload_to_cc`** (Checkbox „Ergebnisse automatisch in ClubCloud hochladen") — wenn aktiviert, wird jedes Einzelergebnis sofort nach Spielende an die ClubCloud übertragen. Voraussetzungen und Alternativen siehe Anhang [ClubCloud-Upload — zwei Wege](#appendix-cc-upload).
- **Timeout-Kontrolle** — Schiedsrichter-Timer pro Aufnahme (disziplinabhängig)
- **Nachstoß** — Regelvariante in bestimmten Karambol-Disziplinen (wenn der Aufschläger das Ballziel erreicht, hat der Gegner einen Nachstoß)

Manche Parameter erscheinen nur bei bestimmten Disziplinen — z. B. ist der Nachstoß-Schalter nur sichtbar, wenn die gewählte Disziplin diese Regel verwendet.

> **Hinweis zu „Bälle vor":** In der UI-Beschriftung taucht zusätzlich der Ausdruck „Bälle vor" auf — das ist eine **individuelle Vorgabe bei Vorgabe-/Handikap-Turnieren** (jeder Spieler bekommt einen anderen Wert), nicht zu verwechseln mit dem allgemeinen Ballziel.

<a id="step-8-tables"></a>
#### Tischzuordnung (Unter-Abschnitt von Schritt 7)

Der gewählte Turnierplan definiert **logische Tischnamen** (z. B. „Tisch 1" und „Tisch 2" bei T04). In diesem Abschnitt ordnen Sie jedem **logischen Tisch** einen **physikalischen Tisch** aus Ihrem Spiellokal zu. Wählen Sie aus der Dropdown-Liste die zwei Tische in Ihrem Spiellokal aus. Für unser NDM-Szenario wählen Sie z. B. „BG Hamburg Tisch 1" und „BG Hamburg Tisch 2".

Die Zuordnung der einzelnen Spiele (Matches) zu den logischen Tischen erfolgt **automatisch** aus dem Turnierplan — der Turnierleiter muss nur die Verbindung logischer-Tisch → physikalischer-Tisch herstellen.

**Scoreboard-Verbindung:** Nach dem Turnierstart werden auf jedem physikalischen Tisch ein oder mehrere **Scoreboards** (Tisch-Monitore, Smartphones, Web-Clients) mit dem zugehörigen Tisch verbunden. Dazu wählt der Bediener am Scoreboard den passenden physikalischen Tisch aus — die Verbindung ist **nicht fest vorgegeben** und kann bei Bedarf am Scoreboard neu gewählt werden. Technisch geschieht die Vermittlung über den [TableMonitor](#glossary-system) des logischen Tischs.

<a id="step-9-start"></a>
### Schritt 9: Turnier starten

Wenn Tischzuordnung und Turnier-Parameter vollständig sind, klicken Sie unten auf **„Starte den Turnier Monitor"**.

!!! info "Der Start-Vorgang dauert einige Sekunden"
    Nach dem Klick auf **Starte den Turnier Monitor** sieht die Seite kurz
    unverändert aus. Das ist normal — der Wizard bereitet im Hintergrund
    die Tisch-Monitore vor. Der Button ist während des Vorgangs gesperrt,
    so dass ein versehentlicher Doppelklick nichts auslöst. Nach wenigen
    Sekunden öffnet sich der Turnier-Monitor automatisch.
<!-- ref: F-19 -->

**Erfolgreich gestartet?** Der zuverlässigste Check ist, an den **Tisch-Tafeln** nachzusehen: Wenn dort die korrekten Paarungen der ersten Runde erscheinen, ist der Start gelungen.

<a id="step-10-warmup"></a>
### Schritt 10: Warmup-Phase beobachten

Nachdem der Turnier-Monitor geöffnet ist, sehen Sie die Übersichtsseite „Turnier-Monitor · NDM Freie Partie Klasse 1–3". Jeder der zwei Tische zeigt einen Status-Badge **„warmup"** und die zugewiesenen Spielerpaare für Partie 1 (z. B. „Simon, Franzel / Smrcka, Martin" auf Tisch 1).

In der Warmup-Phase können sich die Spieler **einspielen** (Fachterminus für „Tisch und Bälle ausprobieren bevor es zählt"). Die Einspielzeit wird **am Scoreboard** gestartet und beträgt typischerweise 5 Minuten (Parameter **Warmup**). Die Scoreboards sind bereits aktiv, aber Punkte zählen noch nicht.

Im Turnier-Monitor sehen Sie im Abschnitt „Aktuelle Spiele Runde 1" die Matches der laufenden Runde mit den Spalten Tisch / Gruppe / Partie / Spieler. **Bei 5 Teilnehmern in Runde 1 laufen 2 Matches mit je 2 Spielern; der fünfte Spieler hat in dieser Runde [Freilos](#glossary-wizard).** (Nicht 4 Matches — die Anzahl ergibt sich aus dem Turnierplan.)

> **Hinweis:** In dieser Tabelle sehen Sie pro Zeile auch Buttons wie „Spielbeginn" — das ist ein Fallback-UI für den Notfall (Scoreboard-Ausfall mit manueller Übertragung von Papierprotokollen). Im Standardablauf braucht der Turnierleiter diese Buttons **nicht** zu klicken.

Als Turnierleiter müssen Sie hier nichts aktiv tun — beobachten Sie, ob alle Scoreboards verbunden sind (grüner Status), und warten Sie auf den Startschuss durch die Spieler an den Scoreboards.

![Turnier-Monitor-Landingpage in der Warmup-Phase](images/tournament-monitor-landing.png){ loading=lazy }
*Abbildung: Turnier-Monitor direkt nach dem Start — beide Tische zeigen Status „warmup" und die Paarungen der ersten Runde (Beispiel aus dem Phase-33-Audit).*

<a id="step-11-release-match"></a>
### Schritt 11: Spielbetrieb läuft (Scoreboards steuern alles)

**Im Standardablauf hat der Turnierleiter hier keine aktive Rolle.** Sobald der Warmup an einem Scoreboard zu Ende ist, startet das jeweilige Spiel automatisch — der Spielbeginn wird **am Scoreboard** ausgelöst, nicht im Turnier-Monitor.

Schritte 10, 11 und 12 sind in Wahrheit drei **Phasen** (Warmup → Spielbetrieb → Abschluss), nicht drei „Aktionen des Turnierleiters". Während dieser Phasen läuft alles an den Scoreboards. Ihre einzige Aufgabe ist Beobachtung und das Eingreifen bei Problemen — dafür siehe [Schritt 12](#step-12-monitor).

> **Sonderfall Manuelle Rundenwechsel-Kontrolle:** Wenn Sie im Start-Formular den Parameter „Tournament manager checks results before acceptance" aktiviert haben, wird der Rundenwechsel blockiert, bis Sie bei jedem Spielende auf „OK?" klicken. Diese Option ist inzwischen umstritten und wird voraussichtlich entfernt; im Standardfall lassen Sie sie deaktiviert.

<a id="step-12-monitor"></a>
### Schritt 12: Beobachten und bei Bedarf eingreifen

Während des Spielbetriebs übernehmen die Spieler bzw. das Scoreboard-Personal die Punkteingabe. Der Turnier-Monitor aktualisiert sich in Echtzeit — Sie müssen die Seite nicht neu laden.

**Was Sie in der Übersicht sehen:** die Spaltenwerte **Bälle** / **Aufnahme** / **HS** ([Höchstserie](#glossary-karambol)) / **GD** ([Generaldurchschnitt](#glossary-karambol)) in der Spiele-Tabelle. Nach Partie-Ende wechselt die Tischkarte automatisch zur nächsten Partie der Runde; nach Abschluss aller Partien einer [Spielrunde](#glossary-karambol) schaltet der Monitor auf die nächste Runde.

**Beobachtung per Browser-Tab:** Vom Turnier-Monitor aus können Sie die einzelnen Tisch-Scoreboards in eigenen Browser-Tabs öffnen (Klick auf den jeweiligen Tisch-Link). Das ist die übliche Methode, um aus der Ferne den Spielstand mehrerer Tische gleichzeitig im Auge zu behalten und bei Bedarf einzugreifen.

**Häufige Fehlerquellen während des Spielbetriebs:**

- **Nachstoß vergessen am Scoreboard** — in Karambol-Disziplinen mit Nachstoß-Regel ist es eine wiederkehrende Quelle für falsche Endergebnisse. Wenn Sie das beobachten, sprechen Sie das Scoreboard-Personal direkt an, bevor der nächste Aufschlag passiert.

!!! danger "Reset zerstört bei laufendem Turnier alle Daten"
    Der Link **„Zurücksetzen des Turnier-Monitors"** am unteren Ende der
    Turnierseite ist **jederzeit** verfügbar — auch während das Turnier
    läuft. Bei laufendem Turnier zerstört der Reset jedoch **alle bisher
    erfassten Spielergebnisse**. Eine Sicherheitsabfrage ist aktuell
    nicht eingebaut (geplant für eine Folge-Phase). Verwenden Sie den
    Reset während des Spielbetriebs nur, wenn Sie das Turnier wirklich
    abbrechen wollen.
<!-- ref: F-36-32 -->

> **Sonderfall manuelle Kontrolle:** Wenn Sie im Start-Formular „Tournament manager checks results before acceptance" aktiviert haben, erscheint nach jedem Spiel ein Bestätigungs-Button für Sie. Dieser Button ist Teil der Sonderbetriebsart aus [Schritt 11](#step-11-release-match) und wird voraussichtlich entfallen.

<a id="step-13-finalize"></a>
### Schritt 13: Turnier abschließen

Nach Abschluss aller Runden setzt der Turnier-Monitor das Turnier in den Abschlussstatus.

!!! warning "Endrangliste wird derzeit NICHT automatisch berechnet"
    Carambus liefert die einzelnen Spielergebnisse korrekt zurück, die
    **Berechnung der Turnier-Endrangliste** (Platzierungen, Stechen,
    Gleichstands-Kriterien) erfolgt aktuell **manuell in der ClubCloud**.
    Den manuellen Pflege-Workflow finden Sie im Anhang
    [Endrangliste in der ClubCloud pflegen](#appendix-rangliste-manual).
    Eine automatische Berechnung in Carambus ist als Folge-Feature für
    v7.1+ vorgesehen.
<!-- ref: F-36-34 -->

!!! warning "Shootout / Stechen wird nicht unterstützt"
    Stichspiele bei KO-Turnieren werden in der aktuellen Carambus-Version
    **nicht unterstützt**. Wenn nach der regulären Partie ein Stechen nötig
    ist, müssen Sie das **außerhalb von Carambus** durchführen (am Tisch
    auf Papier protokollieren) und das Ergebnis manuell in der ClubCloud
    eintragen. Shootout-Support ist als kritisches Feature für ein
    späteres Milestone (v7.1 oder v7.2) eingeplant.
<!-- ref: F-36-35 -->

<a id="step-14-upload"></a>
### Schritt 14: Ergebnisse in die ClubCloud übertragen

Wenn im Start-Formular (Schritt 7) die Option **„auto_upload_to_cc"** aktiviert war, überträgt Carambus jedes **Einzelergebnis sofort nach dem jeweiligen Spielende** an die ClubCloud — nicht erst beim Finalisieren. Voraussetzung: Die Teilnehmerliste muss in der ClubCloud bereits **finalisiert** sein. Die volle Erklärung beider Upload-Pfade und ihrer Voraussetzungen finden Sie im Anhang [ClubCloud-Upload — zwei Wege](#appendix-cc-upload).

Wenn der automatische Upload nicht aktiviert war oder die Voraussetzungen fehlen, läuft der Upload über den **CSV-Batch-Pfad**: Carambus stellt am Ende eine CSV-Datei mit allen Ergebnissen bereit, die manuell in die (finalisierte) ClubCloud-Teilnehmerliste eingespielt werden muss. Der Anhang [CSV-Upload in der ClubCloud](#appendix-cc-csv-upload) beschreibt den Weg im Detail.

> Eine „Übertragen nach ClubCloud"-Schaltfläche, wie sie in früheren Doc-Versionen erwähnt wurde, gibt es im aktuellen Carambus-UI nicht. Der manuelle Upload erfolgt ausschließlich über die ClubCloud-Admin-Oberfläche.

---

<a id="glossary"></a>
## Glossar

<a id="glossary-karambol"></a>
### Karambol-Begriffe

- **Freie Partie** — Die einfachste Karambol-Disziplin: Ein Punkt pro korrektem Karambolage (der gespielte Ball berührt beide anderen Bälle), keine Feldbeschränkung. Typische [Ballziele](#glossary-karambol) für NDM-Klassen liegen bei 50–150 Bällen. *Sie konfigurieren diesen Wert im [Start-Formular, Schritt 7](#step-7-start-form).*

- **Cadre (35/2, 47/1, 47/2, 71/2)** — Karambol-Disziplinen mit Balken-Feldbeschränkung (Cadre = frz. Rahmen). Der erste Wert bezeichnet die Feldgröße in cm, der zweite die maximal erlaubten Bälle pro Feld. Cadre-Turniere verwenden dieselben Wizard-Schritte wie Freie Partie, aber mit anderen Standard-Bällezielen.

- **Dreiband** — [Karambol](#glossary-karambol)-Disziplin: Der gespielte Ball muss vor dem zweiten Objektball mindestens drei Banden berühren. Keine Feldbeschränkung. *Sie sehen diese Disziplin in der Turnier-Detailseite.*

- **Einband** — Karambol-Disziplin: Der gespielte Ball muss mindestens eine Bande berühren, bevor er den zweiten Objektball trifft.

- **Aufnahme** — Eine Aufnahme (auch: Inning) ist ein Spielzug — der Spieler schlägt an, bis er keinen Punkt erzielt oder das [Ballziel](#glossary-karambol) erreicht. Die [Aufnahmebegrenzung](#glossary-karambol) legt die maximale Aufnahmen-Anzahl pro Partie fest. *Sie sehen diesen Begriff im [Start-Formular, Schritt 7](#step-7-start-form).*

- **Ballziel (`balls_goal`)** — Die Zahl der Punkte (Karambolagen), die ein Spieler erzielen muss, um eine Partie zu gewinnen. Im System-Code heißt das Feld `balls_goal`. Für Freie Partie Klasse 1–3 typischerweise **150 Bälle** (ggf. um 20 % reduziert). Maßgeblich ist die Karambol-Sportordnung. *Sie konfigurieren diesen Wert im [Start-Formular, Schritt 7](#step-7-start-form).*

- **Aufnahmebegrenzung (`innings_goal`)** — Maximale Aufnahmenzahl pro Partie. Im System-Code heißt das Feld `innings_goal`. Für Freie Partie Klasse 1–3 typischerweise **50 Aufnahmen** (ggf. um 20 % reduziert). **Leerfeld oder 0 = unbegrenzt.** *Sie konfigurieren diesen Wert im [Start-Formular, Schritt 7](#step-7-start-form).*

- **Bälle vor (Vorgabe-Wert)** — Eine **individuelle Vorgabe pro Spieler** in Vorgabe-/Handikap-Turnieren. Nicht zu verwechseln mit dem allgemeinen Ballziel — bei Vorgabeturnieren bekommt jeder Spieler einen anderen Wert.

- **Höchstserie (HS)** — Die längste Serie an aufeinanderfolgenden Karambolagen in einer Partie oder im gesamten Turnier. Wird im [Turnier-Monitor](#step-12-monitor) in Echtzeit angezeigt.

- **Generaldurchschnitt (GD)** — Erzielte Bälle geteilt durch die Anzahl der Aufnahmen. Maßstab für die Spielstärke über ein Turnier. Wird im [Turnier-Monitor](#step-12-monitor) angezeigt.

- **Spielrunde** — Eine vollständige Runde des Turniers, in der jeder Spieler (oder jedes Paar) einmal antritt. Ein T04-Turnierplan hat 5 Spielrunden. Nach jeder Runde aktualisiert der Turnier-Monitor automatisch die Tabelle.

- **Tisch-Warmup** — Die Phase nach dem [Turnier starten](#step-9-start), in der die Tische den Status `warmup` tragen und sich die Spieler einspielen können, ohne dass Punkte zählen. Die Einspielzeit wird am Scoreboard gestartet; danach geht der Tisch automatisch in den [Spielbetrieb](#step-11-release-match) über.

<a id="glossary-wizard"></a>
### Wizard-Begriffe

- **Meldeliste** — **Snapshot der Setzliste nach dem Meldeschluss** — wer ist offiziell für das Turnier gemeldet. Kommt aus der ClubCloud und ist vorläufig: bis zum Turniertag kann sie sich noch ändern (Nachmeldungen, Abmeldungen). Cross-ref Begriffshierarchie in [Schritt 1](#step-1-invitation).

- **Setzliste** — Die **geordnete** Liste der Anmelder (Platz 1 = top-gesetzt, Platz N = unten). Drei Herkunftsquellen sind möglich:
    1. **Offizielle Setzliste aus der Einladung** (Normalfall) — vom Landessportwart aus seinen Spreadsheets erstellt
    2. **Carambus-interne Setzliste** (Notfall ohne Einladung) — aus den Carambus-eigenen [Ranglisten](#glossary-system) per „Nach Ranking sortieren" in [Schritt 4](#step-4-participants)
    3. **Nicht aus der ClubCloud** — die ClubCloud führt nur Meldelisten, keine Setzlisten

- **Teilnehmerliste** — Wer **tatsächlich** am Turniertag antritt. Wird kurz vor Turnierbeginn finalisiert. Resultiert aus der Meldeliste minus Nichterschienene plus eventuelle [Nachmeldungen](#appendix-nachmeldung). Die Finalisierung erfolgt in [Schritt 5](#step-5-finish-seeding).

- **Turniermodus / Austragungsmodus** — Die Spielform des Turniers (z. B. Jeder-gegen-Jeden, KO-System). Die Auswahl erfolgt in [Schritt 6](#step-6-mode-selection). Der Modus bestimmt den zugrunde liegenden Turnierplan (T04, T05, `Default{n}`) und damit Spielrunden-Zahl und Turniertage.

- **Turnierplan-Kürzel (T-Plan vs. Default-Plan)** — Carambus kennt zwei Arten von Turnierplänen:
    - **T-nn** (z. B. T04, T05) — vordefinierte Pläne aus der **Karambol-Turnierordnung** mit fester Spielstruktur und fester Tischanzahl. Sinnvoll für Standard-Spielerzahlen mit Jeder-gegen-Jeden.
    - **`Default{n}`** — ein **dynamisch generierter** Jeder-gegen-Jeden-Plan, wobei `{n}` die Teilnehmerzahl ist. Wird automatisch erstellt, wenn kein passender T-Plan existiert; die benötigte Tischanzahl wird aus der Teilnehmerzahl berechnet.

  *Sie wählen den Plan in [Schritt 6](#step-6-mode-selection).*

- **Scoreboard** — Das berührungsempfindliche Eingabegerät an jedem Tisch (Tisch-Monitor, Smartphone oder Web-Client), über das die Spieler oder ein Helfer die Punkte live eingeben. Die Scoreboard-Verbindung zum Tisch ist **nicht fest vorgegeben**: am Scoreboard wählt der Bediener den passenden physikalischen Tisch aus, und die Bindung erfolgt über den [TableMonitor](#glossary-system) des logischen Tischs. Die Verbindung kann bei Bedarf am Scoreboard neu gewählt werden (z. B. bei Ausfall eines Tisch-Monitors).

<a id="glossary-system"></a>
### System-Begriffe

- **ClubCloud** — Die regionale Anmeldeplattform des DBU (Deutscher Billard-Union). ClubCloud ist die Quelle der Wahrheit für Spieler-Registrierungen und Meldelisten. Carambus synchronisiert die Teilnehmerliste aus ClubCloud in [Schritt 2](#step-2-load-clubcloud). Weitere Informationen finden Sie in der [ClubCloud-Integration](clubcloud-integration.md).

- **AASM-Status** — Der interne Zustand des Turniers im System, verwaltet durch die AASM-Zustandsmaschine (Acts As State Machine). Mögliche Zustände umfassen `new_tournament`, `tournament_seeding_finished`, `tournament_started_waiting_for_monitors`, `tournament_started` und weitere. Wichtig: die im Wizard angezeigten „Schritte" entsprechen **nicht eins-zu-eins** den AASM-States — Schritte 4 und 5 sind beispielsweise Aktions-Links auf einer State-Seite, kein eigener Zustand (siehe [Schritt 5](#step-5-finish-seeding)). Die sichtbarere Darstellung des Status-Badges im Wizard ist ein offenes Verbesserungsfeld.

- **DBU-Nummer** — Die nationale Spieler-ID des Deutschen Billard-Union. Jeder lizenzierte Spieler hat eine eindeutige DBU-Nummer. In [Schritt 4](#step-4-participants) können Sie Spieler, die nicht in der ClubCloud-Meldeliste erscheinen, über ihre DBU-Nummer nachtragen (komma-getrennt im Eingabefeld).

- **Rangliste** — Eine **Carambus-interne** Spielerrangliste, die pro Spieler aus den **Carambus-eigenen Turnierergebnissen** fortgeschrieben wird (also nicht von der ClubCloud bezogen). Sie dient u. a. als Default-Sortierkriterium, wenn keine offizielle Setzliste aus der Einladung vorliegt. In [Schritt 4](#step-4-participants) können Sie mit „Nach Ranking sortieren" die Teilnehmerliste automatisch nach Ranglistenposition ordnen.

- **Logischer Tisch** — Eine TournamentPlan-interne Tisch-Identität (z. B. „Tisch 1", „Tisch 2" innerhalb von T04). Logische Tische werden beim Turnierstart in [Schritt 7](#step-7-start-form) auf physikalische Tische abgebildet. Der TournamentPlan referenziert ausschließlich logische Tischnamen — die einzelnen Spiele werden automatisch logischen Tischen zugeordnet.

- **Physikalischer Tisch** — Ein konkreter, nummerierter Spieltisch im Spiellokal (z. B. „BG Hamburg Tisch 1"). Aus Spielersicht existieren nur physikalische Tische — die Nummern stehen an den Tischen, und Wer-wo-spielt steht auf den Scoreboards und Tisch-Monitoren. Beim Turnierstart wird jeder logische Tisch einem physikalischen zugeordnet (siehe [Schritt 7](#step-7-start-form), Tischzuordnung).

- **TableMonitor** — Technischer Datensatz / „Automat", der die Abläufe an einem [logischen Tisch](#glossary-system) während eines Spiels steuert: Match-Zuweisungen, Ergebnis-Erfassung, Rundenwechsel. Aus Spielersicht: ein Bot, der entscheidet, welches Spiel auf welchem Tisch läuft. Jeder logische Tisch hat einen TableMonitor; alle Scoreboards, die sich mit dem zugehörigen physikalischen Tisch verbinden, bekommen die Match-Updates über diesen TableMonitor.

- **Turnier-Monitor** — Die übergeordnete Instanz, die alle [TableMonitors](#glossary-system) eines Turniers koordiniert. Der Turnier-Monitor ist sowohl der technische Koordinator als auch die Übersichtsseite, die der Turnierleiter ab [Schritt 9](#step-9-start) aufruft.

- **Trainingsmodus** — Betriebsart eines Scoreboards **außerhalb eines Turnier-Kontexts**, zur Abwicklung einzelner Spiele (Training, Freundschaftsspiele). Wird auch als **Fallback** verwendet, wenn ein laufendes Turnier nicht mehr in Carambus weitergeführt werden kann (siehe [Turnier nicht mehr änderbar](#ts-already-started)).

- **Freilos** — Wenn die Teilnehmerzahl ungerade ist (z. B. 5 Spieler, 2 Tische), kann ein Spieler in einer Spielrunde nicht antreten — er hat ein Freilos. Die Zuteilung erfolgt automatisch aus dem [Turnierplan](#glossary-wizard). Hinweis: Ein nachträglicher Match-Abbruch (z. B. wenn ein Spieler während des Turniers ausfällt) wird in der aktuellen Carambus-Version **nicht sauber unterstützt** — siehe Folge-Phase v7.1+.

---

<a id="troubleshooting"></a>
## Problembehebung

<a id="ts-invitation-upload"></a>
### Einladungs-PDF konnte nicht hochgeladen werden

**Problem:** Der Upload-Dialog zeigt einen Fehler, dreht sich im Kreis (unendlicher Spinner) oder die PDF-Datei wird hochgeladen, aber die Setzliste bleibt leer.

**Ursache:** Der PDF-Parser von Carambus erwartet das vom Landessportwart verwendete Standard-Template. Wenn das Template abweicht (gescanntes PDF ohne maschinenlesbaren Text, niedrige Auflösung, ungewöhnliches Seitenformat), kann der Parser die Setzliste nicht extrahieren. Im Normalbetrieb funktioniert der PDF-Upload zuverlässig, weil das Standard-Template wiederverwendet wird.

**Lösung:** Wechseln Sie auf die **ClubCloud-Meldeliste als Backup-Quelle**. Sie ist nicht weniger zuverlässig als der PDF-Upload — sie ist eine gleichwertige Alternative für den Sonderfall, dass der PDF-Parser scheitert. Den vollen Ablauf finden Sie im Anhang [Einladung fehlt](#appendix-no-invitation), der die Setzliste-Erzeugung aus den Carambus-Ranglisten beschreibt.

<a id="ts-player-not-in-cc"></a>
### Spieler fehlen in der ClubCloud-Meldeliste

**Problem:** Nach dem ClubCloud-Sync wurden weniger Spieler geladen als erwartet. Der Wizard zeigt „Weiter zu Schritt 3 mit diesen N Spielern" mit einem grünen Button, obwohl N zu niedrig ist.

**Ursache:** Im Normalbetrieb sollte das nicht vorkommen — die Einladung und die ClubCloud-Meldeliste stellen denselben Meldeschluss-Snapshot dar. Es gibt drei realistische Auslöser:

1. **Sync wurde vor dem Meldeschluss durchgeführt** — Carambus hat die ClubCloud-Daten zu früh übernommen und kennt Spätanmelder noch nicht. Lösung: Den Sync nach dem Meldeschluss erneut auslösen.
2. **Spieler wird am Turniertag nachgemeldet** — siehe [On-site-Nachmeldung](#appendix-nachmeldung).
3. **Spieler war von Anfang an nicht gemeldet** — sie tauchen daher korrekterweise nicht auf, und sind kein Carambus-Bug.

**Lösung:** Klären Sie zuerst, welcher der drei Fälle vorliegt. Wenn ein echter Spieler fehlt, fügen Sie ihn in [Schritt 4](#step-4-participants) per DBU-Nummer hinzu. Wenn die ClubCloud-Daten unvollständig sind, lassen Sie sie vom Club-Sportwart in der ClubCloud korrigieren und führen den Sync erneut aus.

<a id="ts-wrong-mode"></a>
### Falscher Turniermodus gewählt

**Problem:** Sie haben in Schritt 6 auf eine Modus-Karte (z. B. T04, T05 oder `Default{n}`) geklickt und damit den falschen Plan aktiviert. Das Start-Formular hat sich bereits geöffnet.

**Ursache:** Die Modus-Auswahl wird in Carambus unmittelbar beim Klick angewendet — ohne Bestätigungsdialog (F-13).

**Lösung:** Solange das Turnier **noch nicht gestartet** ist (Schritt 9 noch nicht ausgeführt), benutzen Sie den Link **„Zurücksetzen des Turnier-Monitors"** am unteren Ende der Turnierseite, um das Setup zurückzusetzen, und gehen Sie dann erneut bis zur Modus-Auswahl. Ein separater Button zum nachträglichen Wechseln des Turniermodus existiert in der aktuellen Carambus-UI nicht.

!!! warning "Reset bei laufendem Turnier ist gefährlich"
    Wenn das Turnier bereits gestartet wurde (`tournament_started`), zerstört
    der Reset alle bereits erfassten Spielergebnisse. Verwenden Sie den
    Reset-Link in diesem Zustand nur, wenn Sie das Turnier wirklich
    abbrechen wollen. Siehe [Turnier wurde bereits gestartet](#ts-already-started)
    für Alternativen.

<a id="ts-already-started"></a>
### Turnier wurde bereits gestartet — und etwas läuft schief

**Problem:** Sie möchten Teilnehmer, Turniermodus oder Start-Parameter ändern, oder ein gravierendes Problem ist während des laufenden Turniers aufgetreten. Der Wizard zeigt bereits den Turnier-Monitor und die Detailseite zeigt „Turnier läuft".

**Ursache:** Das AASM-Event `start_tournament!` (ausgelöst in [Schritt 9](#step-9-start)) wechselt das Turnier in einen Zustand, in dem die Parameter nicht mehr nachträglich änderbar sind. Das ist eine **bewusste Designentscheidung**, um Datenkonsistenz bei laufenden Scoreboards zu gewährleisten, und kein Bug.

**Realität:** Es gibt **keinen** technischen Recovery-Pfad — auch nicht für einen Datenbank-Admin oder Entwickler. Die zu ändernden Datenstrukturen sind zu komplex.

**Lösung im Notfall:**

1. **UNDO einzelner Spiele** ist möglich — direkt am betroffenen Scoreboard.
2. **Reset des gesamten Turniers** ist möglich, zerstört aber alle bereits erfassten Spielergebnisse (siehe [Schritt 12 Reset-Warnung](#step-12-monitor)).
3. **Wenn beides nicht in Frage kommt:** Wechseln Sie auf die **herkömmliche Methode**: Spiele auf Papier protokollieren, Ergebnisse direkt in der ClubCloud erfassen. Die Scoreboards können Sie für die einzelnen Spiele im **[Trainingsmodus](#glossary-system)** weiterbenutzen (kein Turnier-Kontext, aber funktionierende Punkterfassung).

Eine Sicherheitsabfrage vor dem Reset bei laufendem Turnier sowie ein Parameter-Verifikationsdialog vor dem Start sind als Folge-Features für eine spätere Phase eingeplant — sie reduzieren das Risiko, dass dieser Notfall überhaupt eintritt.

<a id="ts-endrangliste-missing"></a>
### Endrangliste fehlt nach Turnierende

**Problem:** Das Turnier ist abgeschlossen, aber Carambus zeigt keine berechnete Endrangliste mit Platzierungen.

**Ursache:** Carambus berechnet die **Turnier-Endrangliste derzeit nicht automatisch**. Diese Funktion ist als Folge-Feature für v7.1+ eingeplant.

**Lösung:** Pflegen Sie die Endrangliste **manuell in der ClubCloud**. Den Workflow finden Sie im Anhang [Endrangliste in der ClubCloud pflegen](#appendix-rangliste-manual).

<a id="ts-csv-upload"></a>
### CSV-Upload in die ClubCloud funktioniert nicht

**Problem:** Sie haben am Ende des Turniers eine CSV-Datei mit den Ergebnissen, aber die ClubCloud nimmt sie nicht an oder wirft Validierungsfehler.

**Ursache:** Der CSV-Upload setzt voraus, dass die **Teilnehmerliste in der ClubCloud finalisiert** ist — wenn dort ein Spieler fehlt, der im CSV vorkommt, scheitert der Import. Die Teilnehmerliste-Finalisierung über die CC-API ist in Carambus aktuell nicht implementiert; sie muss manuell durch einen Club-Sportwart in der ClubCloud-Admin-Oberfläche erfolgen.

**Lösung:** Den vollen Ablauf inkl. der nötigen Berechtigungen finden Sie im Anhang [CSV-Upload in der ClubCloud](#appendix-cc-csv-upload). Im Zweifel bitten Sie den Club-Sportwart Ihres Vereins, die Teilnehmerliste in der ClubCloud zuerst zu finalisieren.

<a id="ts-player-withdraws"></a>
### Spieler zieht während des Turniers zurück

**Problem:** Ein Spieler kann während des Turniers nicht weiterspielen (Krankheit, Notfall, Rückzug).

**Ursache:** Carambus unterstützt einen sauberen **Match-Abbruch / Spieler-Rückzug während des laufenden Turniers** in der aktuellen Version **nicht**. Die Funktion ist als mittelgroßes Folge-Feature für v7.1+ eingeplant.

**Lösung (Workaround):** Beenden Sie das laufende Spiel des Spielers am Scoreboard mit dem zuletzt erfassten Stand. Für die folgenden Runden behandeln Sie den ausgefallenen Spieler de-facto wie ein [Freilos](#glossary-system) — die Gegner bekommen die Partie ggf. außerhalb von Carambus zugeschrieben. Dokumentieren Sie den Vorgang manuell im Turnierprotokoll und in der ClubCloud.

<a id="ts-english-labels"></a>
### Englische Feldbezeichnungen im Start-Formular

**Problem:** Im Start-Formular (Schritt 7) erscheinen einige Parameter mit englischen oder unklaren Labels (z. B. *Tournament manager checks results before acceptance*, *Assign games as tables become available*).

**Ursache:** Fehlende oder defekte Einträge in den i18n-Dateien (`config/locales/de.yml`). Die Korrektur ist als UI-Feature für eine Folge-Phase eingeplant.

**Lösung (bis die i18n-Korrektur ausgerollt ist):** Nutzen Sie die folgende Übersetzungstabelle:

| Englisches Label | Deutsche Bedeutung |
|------------------|--------------------|
| Tournament manager checks results before acceptance | Manager bestätigt Ergebnisse vor Annahme (manuelle Rundenwechsel-Kontrolle) |
| Assign games as tables become available | Spiele zuweisen, sobald Tische frei werden |
| auto_upload_to_cc | Ergebnisse automatisch in ClubCloud hochladen |

Im Zweifel behalten Sie die Standardwerte bei und verifizieren Sie die Werte vor dem Klick auf „Starte den Turnier Monitor".

<a id="ts-nachstoss-forgotten"></a>
### Nachstoß am Scoreboard vergessen

**Problem:** In einer Karambol-Disziplin mit Nachstoß-Regel hat das Scoreboard das Spiel beendet, ohne dass der Nachstoß durchgeführt wurde.

**Ursache:** Bedienfehler am Scoreboard — die Nachstoß-Eingabe wird in der Praxis häufig vergessen.

**Lösung:** Wenn das Spiel im Scoreboard noch offen ist (vor Bestätigung „Endergebnis erfasst"), kann das Scoreboard-Personal den Nachstoß noch nachholen. Wenn das Ergebnis bereits bestätigt ist, gibt es **keinen sauberen Nachträglich-Korrigieren-Pfad** — protokollieren Sie die Korrektur manuell und tragen Sie den korrigierten Wert in die ClubCloud ein. Für die Zukunft: Beim nächsten Turnier das Scoreboard-Personal explizit auf die Nachstoß-Eingabe hinweisen.

<a id="ts-shootout-needed"></a>
### Stechen / Shootout nötig (KO-Turnier)

**Problem:** Bei einem KO-Turnier endet eine Partie unentschieden und es wäre ein Stechen erforderlich.

**Ursache:** Stechen / Shootout wird in der aktuellen Carambus-Version **überhaupt nicht unterstützt**. Diese Funktion ist als kritisches Feature für ein späteres Milestone (v7.1 oder v7.2) eingeplant.

**Lösung:** Führen Sie das Stechen **außerhalb von Carambus** durch — am Tisch auf Papier protokollieren — und tragen Sie das Endergebnis manuell in die ClubCloud ein. Der Carambus-Spielstand muss in solchen Fällen nicht weiter gepflegt werden, das Stechen ist außerhalb des Systems abgewickelt.

---

*Für weiterführende technische Details siehe die [Entwickler-Dokumentation](../developers/index.md).*
