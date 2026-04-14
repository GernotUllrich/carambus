# Turnierverwaltung

Diese Seite führt dich als Turnierleiter Schritt für Schritt durch ein aus der ClubCloud geladenes Karambol-Turnier — vom Eingang der Einladung bis zum Ergebnis-Upload.

<a id="scenario"></a>
## Szenario

Als Beispiel hast du als Turnierleiter deines Vereins vom NBV eine Einladung zur **NDM Freie Partie Klasse 1–3** per E-Mail als PDF erhalten. Dieses PDF dient im Normalfall als Start-Unterlage für das Turnier-Management. Das Turnier läuft an einem Samstag in deinem Spiellokal mit 5 gemeldeten Teilnehmern auf zwei Tischen. Diese Seite begleitet dich Schritt für Schritt vom Eingang der Einladung bis zur Abgabe der Ergebnisse an die ClubCloud.

Für abweichende Spezialfälle finden sich im Anhang spezialisierte Abläufe:

- **[Einladung fehlt](#appendix-no-invitation)** — Ablauf ohne PDF-Einladung
- **[Spieler fehlt](#appendix-missing-player)** — Umgang mit nicht-erschienenen gemeldeten Spielern
- **[Spieler wird nachgemeldet](#appendix-nachmeldung)** — On-site-Nachmeldung am Turniertag

<a id="walkthrough"></a>
## Durchführung Schritt für Schritt

Die folgende Anleitung orientiert sich am tatsächlichen Ablauf des Carambus-Wizards — so wie er in der Praxis funktioniert. Wo die Oberfläche ungewohnte Formulierungen oder unerwartetes Verhalten zeigt, findest du einen farbigen Hinweiskasten.

!!! info "Schritt-Nummerierung ist logisch, nicht UI-eins-zu-eins"
    Die im Folgenden nummerierten Schritte 1–14 sind eine **logisch-chronologische** Aufzählung. Die zugehörigen UI-Screens sind historisch gewachsen und zählen teilweise anders: Schritte 2–5 liegen alle auf der Wizard-Seite, Schritt 6 hat einen eigenen Mode-Selection-Screen, Schritte 7–8 sind dieselbe Parametrisierungsseite, ab Schritt 9 wechselt der Ablauf in den Turnier-Monitor und die Tisch-Scoreboards. Während des laufenden Spielbetriebs (Schritte 10–12) hat der Turnierleiter im Standardfall **keine aktive Rolle** — die Aktionen finden alle an den Scoreboards statt.

<a id="step-1-invitation"></a>
### Schritt 1: Die NBV-Einladung erhalten

Du erhältst vom Landessportwart per E-Mail eine PDF-Einladung zur NDM. Die Einladung enthält den offiziellen Turnierplan, die **Setzliste** (vom Landessportwart aus der Meldeliste sortiert) und die Startzeiten. Außerdem stehen in der Einladung die **Ausspielziele** für die Disziplin: das **Ballziel** (allgemein für alle Spieler bei Normalturnieren, oder individuell pro Spieler bei Vorgabeturnieren) und die **Aufnahmebegrenzung**. Diese Werte trägst du später in [Schritt 7](#step-7-start-form) in das Start-Formular ein.

Drei Begriffe solltest du auseinanderhalten — sie beschreiben dieselben Spieler zu unterschiedlichen Zeitpunkten und in unterschiedlichen Sortierungen:

- **Meldeliste** — die **ungeordnete** Liste der Spieler, die der Club-Sportwart (CSW) offiziell zum Turnier in der ClubCloud gemeldet hat. Sie ist bis zum Turnierstart in der ClubCloud verfügbar und gilt als die offizielle Anmeldebasis.
- **Setzliste** — die vom Landessportwart (LSW) aus der Meldeliste **sortierte** Version. Der LSW verknüpft die Meldeliste offline mit seinen selbstgepflegten Spieler-Rankings und hat die Freiheit, kleine Umsortierungen vorzunehmen. Das Ergebnis — eine sortierte Meldeliste — wird mit der Einladung verschickt.
- **Teilnehmerliste** — wer **tatsächlich** am Turniertag antritt. Sie wird vor Turnierbeginn aus der Setzliste mit den anwesenden Spielern abgeglichen. Die Sortierung folgt im Normalfall der Setzliste des LSW; wenn diese nicht verfügbar ist, kann der Turnierleiter sie editieren.

Im [Glossar](#glossary-wizard) findest du die Begriffe noch einmal mit ihrem zeitlichen Zusammenhang.

Du musst in diesem Schritt noch nichts im System klicken — öffne die Einladung, leg das PDF bereit, und öffne dann in Carambus die Turnier-Detailseite des NDM-Turniers.

<a id="step-2-load-clubcloud"></a>
### Schritt 2: Turnier aus ClubCloud laden (Wizard Schritt 1)

**Navigation zur Turnierseite:** Im Carambus-Hauptmenü öffnest du **Organisationen → Regionalverbände → NBV** und klickst dort auf den Link **„Aktuelle Turniere in der Saison 2025/2026"** (die Saison ist dynamisch). In der Turnierliste wählst du das passende Turnier aus (im Beispielszenario „NDM Freie Partie Klasse 1–3").

Auf der Turnier-Detailseite siehst du oben den Wizard-Fortschrittsbalken „Turnier-Setup". Schritt 1 „Meldeliste von ClubCloud laden" ist in der Regel bereits automatisch abgeschlossen — ein grüner Haken (GELADEN) zeigt an, dass Carambus die Meldeliste bereits synchronisiert hat.

**Achtung — Sync vor Meldeschluss:** Wenn der ClubCloud-Sync vor dem offiziellen Meldeschluss durchgelaufen ist, kann die Meldeliste in Carambus weniger Spieler enthalten als die spätere Einladung. Im Normalfall stimmen Einladung und ClubCloud-Meldeliste nach dem Meldeschluss überein, weil beide denselben Snapshot abbilden. Falls du den Verdacht hast, dass Spieler fehlen, prüfe das vor Turnierbeginn in [Schritt 4](#step-4-participants) und löse einen erneuten Sync nach dem Meldeschluss aus. Weitere Details findest du unter [Spieler fehlen in der ClubCloud-Meldeliste](#ts-player-not-in-cc).

![Wizard-Übersicht nach ClubCloud-Sync](images/tournament-wizard-overview.png){ loading=lazy }
*Abbildung: Turnier-Setup-Wizard nach erfolgreichem ClubCloud-Sync — die typische Standard-Darstellung, wenn der Sync vollständig durchgelaufen ist (Beispiel aus dem Phase-33-Audit, NDM Freie Partie Klasse 1–3). Den im Achtung-Block beschriebenen 1-Spieler-Fall illustriert dieses Bild **nicht** — er tritt nur bei unvollständigem Sync auf.*

<a id="step-3-seeding-list"></a>
### Schritt 3: Setzliste übernehmen oder erzeugen

Die **Setzliste** ist ein **Ergebnis**: Meldeliste plus Ordnung. Die Ordnung wird normalerweise vom Landessportwart in der Einladung vorgegeben (anhand seiner Spreadsheets mit den zusammengeführten Turnierergebnissen). Sie ist keine Quelle, die du irgendwoher „herunterladen" musst.

**Im Normalfall (mit Einladung):** Du lädst das PDF der Einladung in Wizard-Schritt 2 hoch. Carambus liest die Setzliste aus dem PDF. Per Mausklick kannst du die Setzliste in eine Teilnehmerliste verwandeln. Gelegentlich entstehen bei der Interpretation der Einladung (OCR) Fehler, sodass die Teilnehmerliste dann nicht mit der Setzliste der Einladung übereinstimmt. Das kannst du in [Schritt 4](#step-4-participants) korrigieren.

**Wenn die Einladung fehlt:** Du übernimmst die initiale Teilnehmerliste aus der ClubCloud-Meldeliste (orientiert am Meldestatus zum Meldeschluss) und ordnest sie anschließend in [Schritt 4](#step-4-participants) per Klick auf **„Nach Ranking sortieren"** anhand der in Carambus gepflegten [Rangliste](#glossary-system) — den vollständigen Ablauf findest du im Anhang [Einladung fehlt](#appendix-no-invitation).

Wenn der PDF-Upload technisch fehlschlägt (häufig bei bestimmten Druckvorlagen oder fehlender Internetverbindung), lies [Einladungs-PDF konnte nicht hochgeladen werden](#ts-invitation-upload).

<a id="step-4-participants"></a>
### Schritt 4: Teilnehmerliste prüfen und ergänzen (Wizard Schritt 3)

**Wie komme ich in die Teilnehmerliste-Bearbeitung?** Es gibt drei mögliche Einstiegspunkte, abhängig vom aktuellen Wizard-Zustand:

1. **Direkt aus Schritt 3** — nachdem du in Schritt 3 die Setzliste übernommen hast, leitet dich der Wizard automatisch in die Bearbeitung weiter
2. **Über den Button am unteren Ende der Turnierseite** — auch wenn Wizard-Schritt 3 noch nicht aktiv ist, ist der Zugang über diesen Bottom-Link möglich
3. **Über die Aktion „Einladung hochladen"** — auch wenn du keine Einladung hast, ist dieser Eingangspunkt nutzbar: im Einladungs-Hochladen-Formular findest du den Link **„→ Mit Meldeliste zu Schritt 3 (nach Rangliste sortiert)"**

Die Mehrfach-UX ist historisch gewachsen — alle drei Wege landen auf derselben Bearbeitungsseite.

In Wizard-Schritt 3 „Teilnehmerliste bearbeiten" siehst du die aktuell vorhandenen Teilnehmer. Fehlen Spieler, trag deren [DBU-Nummern](#glossary-system) komma-getrennt im Feld **„Spieler mit DBU-Nummer hinzufügen"** ein (Beispiel: `121308, 121291, 121341, 121332`) und klick anschließend auf den Link **„Spieler hinzufügen"**, um die Eingabe anzuwenden.

**Nur bei manueller Korrektur der Teilnehmerliste:** Wenn keine offizielle Setzliste aus der Einladung vorliegt oder du Spieler nachträglich ergänzt hast, klick oben auf **„Nach Ranking sortieren"**, um die Teilnehmerliste automatisch nach der aktuellen [Rangliste](#glossary-system) zu ordnen. **Wichtig:** Wenn eine Setzliste aus der Einladung vorhanden ist, hat deren Reihenfolge Priorität — die Setzliste des Landessportwarts darf nicht unbegründet überschrieben werden.

Wenn die Teilnehmerzahl einem vordefinierten [Turnierplan](#glossary-wizard) entspricht, erscheint unter der Teilnehmerliste ein gelb hervorgehobenes Panel **„Mögliche Turnierpläne für N Teilnehmer — automatisch vorgeschlagen: T04"**. Bei 5 Teilnehmern wird dir T04 vorgeschlagen (die Planbezeichnungen wie T04 stammen aus der offiziellen Karambol-Turnierordnung). Die endgültige Modusauswahl erfolgt erst in Schritt 6.

Die meisten Änderungen — Sortierung, in-place-Edits einzelner Felder — werden sofort gespeichert. **Ausnahme:** Für das Hinzufügen neuer Spieler per DBU-Nummer ist der Klick auf den Link **„Spieler hinzufügen"** erforderlich.

<a id="step-5-finish-seeding"></a>
### Schritt 5: Teilnehmerliste abschließen

**Wichtig zum Verständnis:** Die im Wizard angezeigten „Schritt 4" und „Schritt 5" sind **keine eigenen Wizard-Zustände**, sondern **Aktions-Links** auf der Teilnehmerliste-Seite:

- **„Schritt 4: Teilnehmerliste bearbeiten"** — Link zur weiteren Bearbeitung der Teilnehmerliste
- **„Schritt 5: Teilnehmerliste abschließen"** — Link, der den State-Übergang auslöst und in die Turniermodus-Auswahl führt

Zwischen den beiden gibt es im Wizard keinen separaten Zustand. Der Wizard-Fortschrittsbalken springt nach dem Abschließen direkt zur Modus-Auswahl, weil „Schritt 4" eben nur ein Aktions-Link war.

Wenn die Teilnehmerliste vollständig ist, klick auf den Link **„Teilnehmerliste abschließen"**. Damit wird die [Setzliste](#glossary-wizard) festgeschrieben und das Turnier geht in den nächsten Wizard-Zustand über („Schritt 5: Turniermodus festlegen").

!!! warning "Teilnehmerliste abschließen — was ist möglich, was nicht"
    Der Klick auf **Teilnehmerliste abschließen** ist normalerweise verbindlich:
    Du wechselst in die Turniermodus-Auswahl und kannst die Teilnehmerliste
    nicht über den normalen Wizard-Pfad mehr ändern. **Im Notfall** kannst du
    aber das gesamte Turnier-Setup über den Link **„Zurücksetzen des
    Turnier-Monitors"** am unteren Ende der Turnierseite zurücksetzen — das
    ist möglich, aber bei bereits laufendem Turnier mit Datenverlust
    verbunden (siehe [Schritt 12](#step-12-monitor) für die Details).
<!-- ref: F-09 -->

<a id="step-6-mode-selection"></a>
### Schritt 6: Turniermodus auswählen

Wizard-Schritt 5 öffnet eine separate Seite „Abschließende Auswahl des Austragungsmodus". Du siehst **eine oder mehrere Karten** mit den verfügbaren [Turnierplänen](#glossary-wizard) — die Auswahl hängt von der Teilnehmerzahl ab und enthält alle Pläne, die zur aktuellen Teilnehmerzahl passen, darunter ein dynamisch generierter Plan **`Default{n}`**, wobei `{n}` die aktuelle Teilnehmerzahl ist.

`Default{n}` ist ein **dynamisch generierter Jeder-gegen-Jeden-Plan**, dessen benötigte Tischanzahl aus der Teilnehmerzahl berechnet wird. Die T-Pläne (T04, T05, …) haben dagegen feste Spielstruktur und Tischanzahl aus der Karambol-Turnierordnung.

Bei 5 Teilnehmern lautet der Vorschlag z. B. **T04** (Standard für 5 Spieler aus der Sportordnung). Der **in der Einladung angegebene Turnierplan** ist im Normalfall der vom Landessportwart verbindlich vorgegebene — übernimm diesen Vorschlag.

Klick auf **„Weiter mit T04"** (oder dem vorgeschlagenen Plan). Die Auswahl wird **sofort und ohne Bestätigungsdialog** angewendet. Wenn du versehentlich den falschen Plan gewählt hast, lies [Falscher Turniermodus gewählt](#ts-wrong-mode).

![Modus-Auswahl mit T04-Vorschlag](images/tournament-wizard-mode-selection.png){ loading=lazy }
*Abbildung: Modus-Auswahl mit den drei Turnierplänen und automatischem Vorschlag T04 bei 5 Teilnehmern (Beispiel aus dem Phase-33-Audit).*

<a id="step-7-start-form"></a>
### Schritt 7: Start-Parameter und Tischzuordnung ausfüllen

!!! info "Schritte 7 und 8 leben auf derselben Seite"
    Nach der Modusauswahl öffnet sich **eine** Parametrisierungsseite, die
    sowohl die Start-Parameter als auch die Tischzuordnung enthält. Im Doc
    sind sie aus didaktischen Gründen zwei Schritte — im UI ist es eine
    Seite.

Oben siehst du eine Zusammenfassung des gewählten Modus, darunter den Abschnitt **„Zuordnung der Tische"** und ein Formular **„Turnier Parameter"** mit den Spielregeln.

!!! tip "Englische Feldbezeichnungen im Start-Formular"
    Einige Parameter im Start-Formular heißen derzeit auf Englisch oder sind
    unklar beschriftet (zum Beispiel *Tournament manager checks results before
    acceptance* oder *Assign games as tables become available*). Das
    [Glossar](#glossary) unten erklärt die wichtigsten Begriffe. Im Zweifel
    übernimm die Standardwerte und kontrolliere die Einstellungen
    **vor dem Start des Turniers**.
<!-- ref: F-14 -->

**Die wesentlichen Parameter, die du kennen musst:**

- **Tischzuordnung** (siehe Abschnitt unten in diesem Schritt) — welche **physikalischen Tische** in deinem Spiellokal die **logischen Tische** des Turnierplans abbilden
- **Ballziel** (`balls_goal`): Das Ziel in Bällen, das ein Spieler für den Partie-Gewinn erreichen muss. Für Freie Partie Klasse 1–3 steht der Wert in der Einladung (typischerweise **150 Bälle**, ggf. um 20 % reduziert). Maßgeblich ist die Karambol-Sportordnung.
- **Aufnahmebegrenzung** (`innings_goal`): Maximale Aufnahmenzahl pro Partie. Für Freie Partie Klasse 1–3 typischerweise **50 Aufnahmen** (ggf. um 20 % reduziert). **Leerfeld oder 0 = unbegrenzt** (im UI nicht eindeutig dokumentiert — bitte hier nachlesen).
- **Spielabschluss** durch Manager oder durch Spieler — wer bestätigt das Ergebnis am Scoreboard nach Partie-Ende
- **`auto_upload_to_cc`** (Checkbox „Ergebnisse automatisch in ClubCloud hochladen") — wenn aktiviert, wird jedes Einzelergebnis sofort nach Spielende an die ClubCloud übertragen. Voraussetzungen und Alternativen siehe Anhang [ClubCloud-Upload — zwei Wege](#appendix-cc-upload).
- **Timeout-Kontrolle** — Schiedsrichter-Timer pro Aufnahme (disziplinabhängig)
- **Nachstoß** — Regelvariante in bestimmten Karambol-Disziplinen (wenn der Anstoßende das Ballziel erreicht, hat der Gegner einen Nachstoß)

Manche Parameter erscheinen nur bei bestimmten Disziplinen — z. B. ist der Nachstoß-Schalter nur sichtbar, wenn die gewählte Disziplin diese Regel verwendet.

> **Hinweis zu „Bälle vor":** In der UI-Beschriftung taucht zusätzlich der Ausdruck „Bälle vor" auf — das ist eine **individuelle Vorgabe bei Vorgabe-/Handikap-Turnieren** (jeder Spieler bekommt einen anderen Wert), nicht zu verwechseln mit dem allgemeinen Ballziel.

<a id="step-8-tables"></a>
#### Tischzuordnung (Unter-Abschnitt von Schritt 7)

Der gewählte Turnierplan definiert **logische Tischnamen** (z. B. „Tisch 1" und „Tisch 2" bei T04). In diesem Abschnitt ordnest du jedem **logischen Tisch** einen **physikalischen Tisch** aus deinem Spiellokal zu. Wähle aus der Dropdown-Liste die zwei Tische in deinem Spiellokal aus. Für unser NDM-Szenario wählst du z. B. „BCW Tisch 1" und „BCW Tisch 2".

<!-- TODO: Beispiel-Lokal noch von BG Hamburg auf BCW (Billardclub Wuppertal) umstellen, sobald die SME-Screenshots aus dem BCW vorliegen. BG Hamburg ist als Beispiel hier ungeeignet, weil dort kein Carambus eingesetzt wird. -->

Die Zuordnung der einzelnen Spiele (Matches) zu den logischen Tischen erfolgt **automatisch** aus dem Turnierplan — der Turnierleiter muss nur die Verbindung logischer-Tisch → physikalischer-Tisch herstellen.

**Scoreboard-Verbindung:** Nach dem Turnierstart werden auf jedem physikalischen Tisch ein oder mehrere **Scoreboards** (Tisch-Monitore, Smartphones, Web-Clients) mit dem zugehörigen Tisch verbunden. Dazu wählt der Bediener am Scoreboard den passenden physikalischen Tisch aus. **Die Bindung logisch → physikalisch lässt sich nachträglich nicht ändern** — sie wird hier in [Schritt 7](#step-7-start-form) festgelegt. **Wohl aber die Scoreboard → physikalisch-Bindung:** Wenn z. B. am physikalischen Tisch 5 das Scoreboard ausfällt, kannst du an einem freien Scoreboard am Nachbartisch den physischen Tisch 5 auswählen — das Scoreboard bedient dann den ausgefallenen Tisch mit. Technisch geschieht die Vermittlung über den [TableMonitor](#glossary-system) des logischen Tischs.

<a id="step-9-start"></a>
### Schritt 9: Turnier starten

Wenn Tischzuordnung und Turnier-Parameter vollständig sind, klick unten auf **„Starte den Turnier Monitor"**.

!!! info "Der Start-Vorgang dauert einige Sekunden"
    Nach dem Klick auf **Starte den Turnier Monitor** sieht die Seite kurz
    unverändert aus. Das ist normal — der Wizard bereitet im Hintergrund
    die Tisch-Monitore vor. Der Button ist während des Vorgangs gesperrt,
    so dass ein versehentlicher Doppelklick nichts auslöst. Nach wenigen
    Sekunden öffnet sich der Turnier-Monitor automatisch.
<!-- ref: F-19 -->

**Erfolgreich gestartet?** Der zuverlässigste Check ist, an den **Tisch-Tafeln** nachzusehen: Wenn dort die korrekten Paarungen der ersten Runde erscheinen, ist der Start gelungen.

> **Wenn die Scoreboards noch nichts zeigen:** Es kann sein, dass die Scoreboards erst nach dem Turnierstart eingeschaltet werden, oder dass sie noch im allgemeinen Welcome-Modus stehen. In beiden Fällen kommst du am Scoreboard über **„Turniere"** zur Liste der laufenden Turniere — wähle das passende Turnier und dann den entsprechenden Tisch aus, um die Paarungen anzuzeigen.

<a id="step-10-warmup"></a>
### Schritt 10: Warmup-, Ausstoß- und Spielphase

Nachdem der Turnier-Monitor geöffnet ist, siehst du die Übersichtsseite „Turnier-Monitor · NDM Freie Partie Klasse 1–3". Jeder der zwei Tische zeigt einen Status-Badge **„warmup"** und die zugewiesenen Spielerpaare für Partie 1 (z. B. „Simon, Franzel / Smrcka, Martin" auf Tisch 1).

Eine Partie durchläuft am Scoreboard drei Phasen — **Warmup → Ausstoß → Spielphase**:

1. **Warmup:** Die Spieler **einspielen** sich (Fachterminus für „Tisch und Bälle ausprobieren bevor es zählt"). Die Einspielzeit wird **am Scoreboard** gestartet und beträgt typischerweise 5 Minuten (Parameter **Warmup**). Punkte zählen noch nicht.
2. **Ausstoßphase:** Vor der eigentlichen Spielphase wird am Scoreboard entschieden, **wer den Anstoß hat**. Das Ergebnis des Ausstoßes wird am Scoreboard eingegeben, und die Darstellung der Spieler (weiß/gelb) wird je nach Ausgang entsprechend vertauscht.
3. **Spielphase:** Erst danach läuft die eigentliche Partie — Punkte werden gezählt.

Im Turnier-Monitor siehst du im Abschnitt „Aktuelle Spiele Runde 1" die Matches der laufenden Runde mit den Spalten Tisch / Gruppe / Partie / Spieler. **Bei 5 Teilnehmern in Runde 1 laufen 2 Matches mit je 2 Spielern; der fünfte Spieler ist in dieser Runde spielfrei** (siehe [Freilos](#glossary-wizard) für die genaue Begriffsabgrenzung). Nicht 4 Matches — die Anzahl ergibt sich aus dem Turnierplan.

> **Hinweis:** In dieser Tabelle siehst du pro Zeile auch Buttons wie „Spielbeginn" — das ist ein Fallback-UI für den Notfall (Scoreboard-Ausfall mit manueller Übertragung von Papierprotokollen). Im Standardablauf brauchst du diese Buttons **nicht** zu klicken.

Als Turnierleiter musst du hier nichts aktiv tun — beobachte, ob alle Scoreboards verbunden sind (grüner Status), und warte auf den Startschuss durch die Spieler an den Scoreboards.

![Turnier-Monitor-Landingpage in der Warmup-Phase](images/tournament-monitor-landing.png){ loading=lazy }
*Abbildung: Turnier-Monitor direkt nach dem Start — beide Tische zeigen Status „warmup" und die Paarungen der ersten Runde (Beispiel aus dem Phase-33-Audit).*

<a id="step-11-release-match"></a>
### Schritt 11: Spielbetrieb läuft (Scoreboards steuern alles)

**Im Standardablauf hast du als Turnierleiter hier keine aktive Rolle.** Sobald der Warmup und die Ausstoßphase an einem Scoreboard zu Ende sind, startet die Spielphase automatisch — der Spielbeginn wird **am Scoreboard** ausgelöst, nicht im Turnier-Monitor.

Schritte 10, 11 und 12 sind in Wahrheit drei **Phasen** (Warmup/Ausstoß → Spielbetrieb → Abschluss), nicht drei „Aktionen des Turnierleiters". Während dieser Phasen läuft alles an den Scoreboards. Deine einzige Aufgabe ist Beobachtung und das Eingreifen bei Problemen — dafür siehe [Schritt 12](#step-12-monitor).

> **Sonderfall Manuelle Rundenwechsel-Kontrolle:** Wenn du im Start-Formular den Parameter „Tournament manager checks results before acceptance" aktiviert hast, wird der Rundenwechsel blockiert, bis du bei jedem Spielende auf „OK?" klickst. Diese Option ist inzwischen umstritten und wird voraussichtlich entfernt; im Standardfall lass sie deaktiviert.

<a id="step-12-monitor"></a>
### Schritt 12: Beobachten und bei Bedarf eingreifen

Während des Spielbetriebs übernehmen die Spieler die Punkteingabe direkt am Scoreboard. Der Turnier-Monitor aktualisiert sich in Echtzeit — du musst die Seite nicht neu laden.

**Was du in der Übersicht siehst:** die Spaltenwerte **Bälle** / **Aufnahme** / **HS** ([Höchstserie](#glossary-karambol)) / **GD** ([Generaldurchschnitt](#glossary-karambol)) in der Spiele-Tabelle.

**Bei Spielende — Protokolleditor:** Mit Einführung des Protokolleditors hat sich der Spielabschluss-Ablauf geändert. Bei Spielende erscheint am Scoreboard automatisch der **Protokolleditor**. Dort können die Spieler noch Änderungen am Spielprotokoll vornehmen (z. B. einen vergessenen Nachstoß nachtragen, eine falsch erfasste Aufnahme korrigieren). Erst nach Abschluss des Protokolleditors wird das Ergebnis endgültig erfasst und an den Turnier-Monitor übertragen. Die Tischkarte wechselt dann automatisch zur nächsten Partie der Runde; nach Abschluss aller Partien einer [Spielrunde](#glossary-karambol) schaltet der Monitor auf die nächste Runde.

**Beobachtung per Browser-Tab:** Vom Turnier-Monitor aus kannst du die einzelnen Tisch-Scoreboards in eigenen Browser-Tabs öffnen (Klick auf den jeweiligen Tisch-Link). Das ist die übliche Methode, um aus der Ferne den Spielstand mehrerer Tische gleichzeitig im Auge zu behalten und bei Bedarf einzugreifen.

**Häufige Fehlerquellen während des Spielbetriebs:**

- **Nachstoß vergessen am Scoreboard** — in Karambol-Disziplinen mit Nachstoß-Regel ist es eine wiederkehrende Quelle für falsche Endergebnisse. Wenn du das beobachtest, sprich die Spieler direkt an, bevor sie das Spielprotokoll bestätigen — siehe [Nachstoß am Scoreboard vergessen](#ts-nachstoss-forgotten).

!!! danger "Reset zerstört bei laufendem Turnier alle Daten"
    Der Link **„Zurücksetzen des Turnier-Monitors"** am unteren Ende der
    Turnierseite ist **jederzeit** verfügbar — auch während das Turnier
    läuft. Bei laufendem Turnier zerstört der Reset jedoch **alle bisher
    erfassten Spielergebnisse**. Eine Sicherheitsabfrage ist aktuell
    nicht eingebaut (geplant für eine Folge-Phase). Verwende den
    Reset während des Spielbetriebs nur, wenn du das Turnier wirklich
    abbrechen willst.
<!-- ref: F-36-32 -->

> **Sonderfall manuelle Kontrolle:** Wenn du im Start-Formular „Tournament manager checks results before acceptance" aktiviert hast, erscheint nach jedem Spiel ein Bestätigungs-Button für dich. Dieser Button ist Teil der Sonderbetriebsart aus [Schritt 11](#step-11-release-match) und wird voraussichtlich entfallen.

<a id="step-13-finalize"></a>
### Schritt 13: Turnier abschließen

Nach Abschluss aller Runden setzt der Turnier-Monitor das Turnier in den Abschlussstatus.

!!! warning "Endrangliste wird derzeit NICHT automatisch berechnet"
    Carambus liefert die einzelnen Spielergebnisse korrekt zurück, die
    **Berechnung der Turnier-Endrangliste** (Platzierungen, Stechen,
    Gleichstands-Kriterien) erfolgt aktuell **manuell in der ClubCloud**.
    Den manuellen Pflege-Workflow findest du im Anhang
    [Endrangliste in der ClubCloud pflegen](#appendix-rangliste-manual).
    Eine automatische Berechnung in Carambus ist als Folge-Feature für
    v7.1+ vorgesehen.
<!-- ref: F-36-34 -->

!!! danger "Shootout / Stechen — kritischer Fehler bei KO-Turnieren"
    Stichspiele bei KO-Turnieren werden in der aktuellen Carambus-Version
    **nicht unterstützt** — und das ist nicht nur ein fehlendes Feature,
    sondern ein **kritischer Fehler**: Bei KO darf es kein Unentschieden
    geben. Wenn nach der regulären Partie zwei Spieler denselben Stand
    haben, **geht Carambus aktuell automatisch mit dem Anstoßenden weiter**
    — also dem Spieler, der diese Partie eröffnet hat. Das ist nicht die
    korrekte Stechen-Regel und kann das Turnierergebnis verfälschen.

    **Workaround bis zum Fix:** Wenn ein Stechen nötig wird, führst du es
    **außerhalb von Carambus** durch (am Tisch auf Papier protokollieren)
    und trägst das Ergebnis manuell in der ClubCloud ein. Korrigiere den
    von Carambus automatisch durchgereichten „Sieg des Anstoßenden"
    entsprechend nach. Echter Shootout-Support ist als kritisches Feature
    für ein späteres Milestone (v7.1 oder v7.2) eingeplant.
<!-- ref: F-36-35 -->

<a id="step-14-upload"></a>
### Schritt 14: Ergebnisse in die ClubCloud übertragen

Wenn im Start-Formular (Schritt 7) die Option **„auto_upload_to_cc"** aktiviert war, überträgt Carambus jedes **Einzelergebnis sofort nach dem jeweiligen Spielende** an die ClubCloud — nicht erst beim Finalisieren. Voraussetzung: Die Teilnehmerliste muss in der ClubCloud bereits **finalisiert** sein. Die volle Erklärung beider Upload-Pfade und ihrer Voraussetzungen findest du im Anhang [ClubCloud-Upload — zwei Wege](#appendix-cc-upload).

Wenn der automatische Upload nicht aktiviert war oder die Voraussetzungen fehlen, läuft der Upload über den **CSV-Batch-Pfad**: Carambus stellt am Ende eine CSV-Datei mit allen Ergebnissen bereit, die manuell in die (finalisierte) ClubCloud-Teilnehmerliste eingespielt werden muss. Der Anhang [CSV-Upload in der ClubCloud](#appendix-cc-csv-upload) beschreibt den Weg im Detail.

> Eine „Übertragen nach ClubCloud"-Schaltfläche, wie sie in früheren Doc-Versionen erwähnt wurde, gibt es im aktuellen Carambus-UI nicht. Der manuelle Upload erfolgt ausschließlich über die ClubCloud-Admin-Oberfläche.

---

<a id="glossary"></a>
## Glossar

<a id="glossary-karambol"></a>
### Karambol-Begriffe

- **Freie Partie** — Die einfachste Karambol-Disziplin: Ein Punkt pro korrektem Karambolage (der gespielte Ball berührt beide anderen Bälle), keine Feldbeschränkung. Typische [Ballziele](#glossary-karambol) für NDM-Klassen liegen bei 50–150 Bällen. *Du konfigurierst diesen Wert im [Start-Formular, Schritt 7](#step-7-start-form).*

- **Cadre (35/2, 47/1, 47/2, 71/2)** — Karambol-Disziplinen mit Balken-Feldbeschränkung (Cadre = frz. Rahmen). Der erste Wert bezeichnet die Feldgröße in cm, der zweite die maximal erlaubten Bälle pro Feld. Cadre-Turniere verwenden dieselben Wizard-Schritte wie Freie Partie, aber mit anderen Standard-Bällezielen.

- **Dreiband** — [Karambol](#glossary-karambol)-Disziplin: Der gespielte Ball muss vor dem zweiten Objektball mindestens drei Banden berühren. Keine Feldbeschränkung. *Du siehst diese Disziplin in der Turnier-Detailseite.*

- **Einband** — Karambol-Disziplin: Der gespielte Ball muss mindestens eine Bande berühren, bevor er den zweiten Objektball trifft.

- **Anstoß / Anstoßender** — Den **Anstoß** macht zu Beginn der Partie nur der **Anstoßende** in seiner ersten Aufnahme — wer das ist, wird in der [Ausstoßphase](#step-10-warmup) am Scoreboard ermittelt. Im weiteren Verlauf der Partie spielen die Spieler abwechselnd, bis das Ballziel oder die Aufnahmebegrenzung erreicht ist.

- **Aufnahme** — Eine Aufnahme (auch: Inning) ist ein Spielzug — der Spieler stößt, bis er keinen Punkt erzielt oder das [Ballziel](#glossary-karambol) erreicht. Die [Aufnahmebegrenzung](#glossary-karambol) legt die maximale Aufnahmen-Anzahl pro Partie fest. *Du siehst diesen Begriff im [Start-Formular, Schritt 7](#step-7-start-form).*

- **Ballziel (`balls_goal`)** — Die Zahl der Punkte (Karambolagen), die ein Spieler erzielen muss, um eine Partie zu gewinnen. Im System-Code heißt das Feld `balls_goal`. Für Freie Partie Klasse 1–3 typischerweise **150 Bälle** (ggf. um 20 % reduziert). Maßgeblich ist die Karambol-Sportordnung. *Du konfigurierst diesen Wert im [Start-Formular, Schritt 7](#step-7-start-form).*

- **Aufnahmebegrenzung (`innings_goal`)** — Maximale Aufnahmenzahl pro Partie. Im System-Code heißt das Feld `innings_goal`. Für Freie Partie Klasse 1–3 typischerweise **50 Aufnahmen** (ggf. um 20 % reduziert). **Leerfeld oder 0 = unbegrenzt.** *Du konfigurierst diesen Wert im [Start-Formular, Schritt 7](#step-7-start-form).*

- **Bälle vor (Vorgabe-Wert)** — Eine **individuelle Vorgabe pro Spieler** in Vorgabe-/Handikap-Turnieren. Nicht zu verwechseln mit dem allgemeinen Ballziel — bei Vorgabeturnieren bekommt jeder Spieler einen anderen Wert.

- **Höchstserie (HS)** — Die längste Serie an aufeinanderfolgenden Karambolagen in einer Partie oder im gesamten Turnier. Wird im [Turnier-Monitor](#step-12-monitor) in Echtzeit angezeigt.

- **Generaldurchschnitt (GD)** — Erzielte Bälle geteilt durch die Anzahl der Aufnahmen. Maßstab für die Spielstärke über ein Turnier. Wird im [Turnier-Monitor](#step-12-monitor) angezeigt.

- **Spielrunde** — Eine vollständige Runde des Turniers, in der jeder Spieler (oder jedes Paar) einmal antritt. Ein T04-Turnierplan hat 5 Spielrunden. Nach jeder Runde aktualisiert der Turnier-Monitor automatisch die Tabelle.

- **Tisch-Warmup** — Die Phase nach dem [Turnier starten](#step-9-start), in der die Tische den Status `warmup` tragen und sich die Spieler einspielen können, ohne dass Punkte zählen. Die Einspielzeit wird am Scoreboard gestartet; danach geht der Tisch automatisch in den [Spielbetrieb](#step-11-release-match) über.

<a id="glossary-wizard"></a>
### Wizard-Begriffe

- **Meldeliste** — Die **ungeordnete** Liste der Spieler, die der **Club-Sportwart (CSW)** offiziell zum Turnier in der ClubCloud gemeldet hat. Sie ist die offizielle Anmeldebasis und steht bis zum Turnierstart in der ClubCloud. Eine Sortierung gibt es auf dieser Ebene noch nicht — die kommt erst durch den LSW in der Setzliste. Cross-ref Begriffshierarchie in [Schritt 1](#step-1-invitation).

- **Setzliste** — Die vom **Landessportwart (LSW)** aus der Meldeliste **sortierte** Version. Der LSW verknüpft die Meldeliste offline mit seinen selbstgepflegten Spieler-Rankings und hat die Freiheit, kleine Umsortierungen vorzunehmen. Das Ergebnis — eine sortierte Meldeliste — wird mit der **Einladung** an den Verein verschickt. Drei Herkunftsquellen sind möglich:
    1. **Offizielle Setzliste aus der Einladung** (Normalfall) — vom Landessportwart aus Meldeliste + eigenen Rankings erstellt
    2. **Carambus-interne Setzliste** (Notfall ohne Einladung) — aus den Carambus-eigenen [Ranglisten](#glossary-system) per „Nach Ranking sortieren" in [Schritt 4](#step-4-participants)
    3. **Nicht aus der ClubCloud direkt** — die ClubCloud führt nur die ungeordnete Meldeliste, keine Setzlisten

- **Teilnehmerliste** — Wer **tatsächlich** am Turniertag antritt. Wird kurz vor Turnierbeginn aus der Setzliste mit den anwesenden Spielern abgeglichen. Die Sortierung folgt im Normalfall der Setzliste des Landessportwarts; wenn diese nicht verfügbar ist, kann der Turnierleiter sie editieren. Die Finalisierung erfolgt in [Schritt 5](#step-5-finish-seeding).

- **Turniermodus / Austragungsmodus** — Die Spielform des Turniers (z. B. Jeder-gegen-Jeden, KO-System). Die Auswahl erfolgt in [Schritt 6](#step-6-mode-selection). Der Modus bestimmt den zugrunde liegenden Turnierplan (T04, T05, `Default{n}`) und damit Spielrunden-Zahl und Turniertage.

- **Turnierplan-Kürzel (T-Plan vs. Default-Plan)** — Carambus kennt zwei Arten von Turnierplänen:
    - **T-nn** (z. B. T04, T05) — vordefinierte Pläne aus der **Karambol-Turnierordnung** mit fester Spielstruktur und fester Tischanzahl. Sinnvoll für Standard-Spielerzahlen mit Jeder-gegen-Jeden.
    - **`Default{n}`** — ein **dynamisch generierter** Jeder-gegen-Jeden-Plan, wobei `{n}` die Teilnehmerzahl ist. Wird automatisch erstellt, wenn kein passender T-Plan existiert; die benötigte Tischanzahl wird aus der Teilnehmerzahl berechnet.

  *Du wählst den Plan in [Schritt 6](#step-6-mode-selection).*

- **Scoreboard** — Das berührungsempfindliche Eingabegerät an jedem Tisch (Tisch-Monitor, Smartphone oder Web-Client), über das die Spieler die Punkte live eingeben. Die **Bindung logisch → physikalisch** wird in [Schritt 7](#step-7-start-form) festgelegt und ist danach nicht mehr änderbar. Die **Bindung Scoreboard → physikalisch** ist hingegen flexibel: Am Scoreboard wählt der Bediener den passenden physikalischen Tisch aus, und die Bindung erfolgt über den [TableMonitor](#glossary-system) des entsprechenden logischen Tischs. So kann z. B. bei Ausfall eines Tisch-Monitors ein freies Scoreboard am Nachbartisch den ausgefallenen Tisch übernehmen.

<a id="glossary-system"></a>
### System-Begriffe

- **ClubCloud** — Die regionale Anmeldeplattform des DBU (Deutscher Billard-Union). ClubCloud ist die Quelle der Wahrheit für Spieler-Registrierungen und Meldelisten. Carambus synchronisiert die Meldeliste aus ClubCloud in [Schritt 2](#step-2-load-clubcloud). Weitere Informationen findest du in der [ClubCloud-Integration](clubcloud-integration.md).

- **AASM-Status** — Der interne Zustand des Turniers im System, verwaltet durch die AASM-Zustandsmaschine (Acts As State Machine). Mögliche Zustände umfassen `new_tournament`, `tournament_seeding_finished`, `tournament_started_waiting_for_monitors`, `tournament_started` und weitere. Wichtig: die im Wizard angezeigten „Schritte" entsprechen **nicht eins-zu-eins** den AASM-States — Schritte 4 und 5 sind beispielsweise Aktions-Links auf einer State-Seite, kein eigener Zustand (siehe [Schritt 5](#step-5-finish-seeding)). Die sichtbarere Darstellung des Status-Badges im Wizard ist ein offenes Verbesserungsfeld.

- **DBU-Nummer** — Die nationale Spieler-ID des Deutschen Billard-Union. Jeder lizenzierte Spieler hat eine eindeutige DBU-Nummer. In [Schritt 4](#step-4-participants) kannst du Spieler, die nicht in der ClubCloud-Meldeliste erscheinen, über ihre DBU-Nummer nachtragen (komma-getrennt im Eingabefeld).

- **Rangliste** — Eine **Carambus-interne** Spielerrangliste, die pro Spieler aus den **Carambus-eigenen Turnierergebnissen** fortgeschrieben wird (also nicht von der ClubCloud bezogen). Sie dient u. a. als Default-Sortierkriterium, wenn keine offizielle Setzliste aus der Einladung vorliegt. In [Schritt 4](#step-4-participants) kannst du mit „Nach Ranking sortieren" die Teilnehmerliste automatisch nach Ranglistenposition ordnen.

- **Logischer Tisch** — Eine TournamentPlan-interne Tisch-Identität (z. B. „Tisch 1", „Tisch 2" innerhalb von T04). Logische Tische werden beim Turnierstart in [Schritt 7](#step-7-start-form) auf physikalische Tische abgebildet. Der TournamentPlan referenziert ausschließlich logische Tischnamen — die einzelnen Spiele werden automatisch logischen Tischen zugeordnet.

- **Physikalischer Tisch** — Ein konkreter, nummerierter Spieltisch im Spiellokal (z. B. „BCW Tisch 1"). Aus Spielersicht existieren nur physikalische Tische — die Nummern stehen an den Tischen, und Wer-wo-spielt steht auf den Scoreboards und Tisch-Monitoren. Beim Turnierstart wird jeder logische Tisch einem physikalischen zugeordnet (siehe [Schritt 7](#step-7-start-form), Tischzuordnung).

- **TableMonitor** — Technischer Datensatz / „Automat", der die Abläufe an einem [logischen Tisch](#glossary-system) während eines Spiels steuert: Match-Zuweisungen, Ergebnis-Erfassung, Rundenwechsel. Aus Spielersicht: ein Bot, der entscheidet, welches Spiel auf welchem Tisch läuft. Jeder logische Tisch hat einen TableMonitor; alle Scoreboards, die sich mit dem zugehörigen physikalischen Tisch verbinden, bekommen die Match-Updates über diesen TableMonitor.

- **Turnier-Monitor** — Die übergeordnete Instanz, die alle [TableMonitors](#glossary-system) eines Turniers koordiniert. Der Turnier-Monitor ist sowohl der technische Koordinator als auch die Übersichtsseite, die der Turnierleiter ab [Schritt 9](#step-9-start) aufruft.

- **Trainingsmodus** — Betriebsart eines Scoreboards **außerhalb eines Turnier-Kontexts**, zur Abwicklung einzelner Spiele (Training, Freundschaftsspiele). Wird auch als **Fallback** verwendet, wenn ein laufendes Turnier nicht mehr in Carambus weitergeführt werden kann (siehe [Turnier nicht mehr änderbar](#ts-already-started)).

- **Freilos / spielfrei** — Zwei verwandte, aber **nicht identische** Konzepte:
    - **Spielfrei in einer Runde** — Wenn die Teilnehmerzahl ungerade ist (z. B. 5 Spieler, 2 Tische), kann ein Spieler in einer Spielrunde nicht antreten — er ist in dieser Runde **spielfrei**. Die Zuteilung erfolgt automatisch aus dem [Turnierplan](#glossary-wizard).
    - **Freilos im engeren Sinne** — Wenn in einer **angesetzten Spielpaarung** kein Gegner existiert (z. B. weil der gegnerische Spieler nicht erschienen ist oder zurückgezogen wurde), bekommt der verbleibende Spieler ein **Freilos** — er gewinnt das Spiel, ohne zu spielen.
    Hinweis: Ein nachträglicher Match-Abbruch (z. B. wenn ein Spieler während des Turniers ausfällt) wird in der aktuellen Carambus-Version **nicht sauber unterstützt** — siehe Folge-Phase v7.1+.

---

<a id="troubleshooting"></a>
## Problembehebung

<a id="ts-invitation-upload"></a>
### Einladungs-PDF konnte nicht hochgeladen werden

**Problem:** Der Upload-Dialog zeigt einen Fehler, dreht sich im Kreis (unendlicher Spinner) oder die PDF-Datei wird hochgeladen, aber die Setzliste bleibt leer.

**Mögliche Ursachen:**

- **Keine Internetverbindung** — Carambus läuft im Prinzip auch ohne Internetverbindung, der PDF-Upload zur Server-Verarbeitung benötigt sie aber kurzzeitig. Wenn der Upload-Dialog endlos dreht, prüf zuerst die Netzwerkverbindung des Clients.
- **Abweichendes Template** — Der PDF-Parser von Carambus erwartet das vom Landessportwart verwendete Standard-Template. Wenn das Template abweicht (gescanntes PDF ohne maschinenlesbaren Text, niedrige Auflösung, ungewöhnliches Seitenformat), kann der Parser die Setzliste nicht extrahieren. Im Normalbetrieb funktioniert der PDF-Upload zuverlässig, weil das Standard-Template wiederverwendet wird.

**Lösung:** Bei Internetproblemen warte einen Moment und versuch es erneut. Wenn das Template das Problem ist, wechsle auf die **ClubCloud-Meldeliste als Backup-Quelle**. Sie ist nicht weniger zuverlässig als der PDF-Upload — sie ist eine gleichwertige Alternative für den Sonderfall, dass der PDF-Parser scheitert. Den vollen Ablauf findest du im Anhang [Einladung fehlt](#appendix-no-invitation), der die Setzliste-Erzeugung aus den Carambus-Ranglisten beschreibt.

<a id="ts-player-not-in-cc"></a>
### Spieler fehlen in der ClubCloud-Meldeliste

**Problem:** Nach dem ClubCloud-Sync wurden weniger Spieler geladen als erwartet. Der Wizard zeigt „Weiter zu Schritt 3 mit diesen N Spielern" mit einem grünen Button, obwohl N zu niedrig ist.

**Ursache:** Im Normalbetrieb sollte das nicht vorkommen — die Einladung und die ClubCloud-Meldeliste stellen denselben Meldeschluss-Snapshot dar. Es gibt drei realistische Auslöser:

1. **Sync wurde vor dem Meldeschluss durchgeführt** — Carambus hat die ClubCloud-Daten zu früh übernommen und kennt Spätanmelder noch nicht. Lösung: Den Sync nach dem Meldeschluss erneut auslösen.
2. **Spieler wird am Turniertag nachgemeldet** — siehe [On-site-Nachmeldung](#appendix-nachmeldung).
3. **Spieler war von Anfang an nicht gemeldet** — sie tauchen daher korrekterweise nicht auf, und sind kein Carambus-Bug.

**Lösung:** Klär zuerst, welcher der drei Fälle vorliegt. Wenn ein echter Spieler fehlt, füg ihn in [Schritt 4](#step-4-participants) per DBU-Nummer hinzu.

<a id="ts-wrong-mode"></a>
### Falscher Turniermodus gewählt

**Problem:** Du hast in Schritt 6 auf eine Modus-Karte (z. B. T04, T05 oder `Default{n}`) geklickt und damit den falschen Plan aktiviert. Das Start-Formular hat sich bereits geöffnet.

**Ursache:** Die Modus-Auswahl wird in Carambus unmittelbar beim Klick angewendet — ohne Bestätigungsdialog (F-13).

**Lösung:** Solange das Turnier **noch nicht gestartet** ist (Schritt 9 noch nicht ausgeführt), benutz den Link **„Zurücksetzen des Turnier-Monitors"** am unteren Ende der Turnierseite, um das Setup zurückzusetzen, und geh dann erneut bis zur Modus-Auswahl. Ein separater Button zum nachträglichen Wechseln des Turniermodus existiert in der aktuellen Carambus-UI nicht.

!!! warning "Reset bei laufendem Turnier ist gefährlich"
    Wenn das Turnier bereits gestartet wurde (`tournament_started`), zerstört
    der Reset alle bereits erfassten Spielergebnisse. Verwende den
    Reset-Link in diesem Zustand nur, wenn du das Turnier wirklich
    abbrechen willst. Siehe [Turnier wurde bereits gestartet](#ts-already-started)
    für Alternativen.

<a id="ts-already-started"></a>
### Turnier wurde bereits gestartet — und etwas läuft schief

**Problem:** Du möchtest Teilnehmer, Turniermodus oder Start-Parameter ändern, oder ein gravierendes Problem ist während des laufenden Turniers aufgetreten. Der Wizard zeigt bereits den Turnier-Monitor und die Detailseite zeigt „Turnier läuft".

**Ursache:** Das AASM-Event `start_tournament!` (ausgelöst in [Schritt 9](#step-9-start)) wechselt das Turnier in einen Zustand, in dem die Parameter nicht mehr nachträglich änderbar sind. Das ist eine **bewusste Designentscheidung**, um Datenkonsistenz bei laufenden Scoreboards zu gewährleisten, und kein Bug.

**Realität:** Es gibt **keinen** technischen Recovery-Pfad — auch nicht für einen Datenbank-Admin oder Entwickler. Die zu ändernden Datenstrukturen sind zu komplex.

**Lösung im Notfall:**

1. **UNDO einzelner Spiele** ist möglich — direkt am betroffenen Scoreboard.
2. **Reset des gesamten Turniers** ist möglich, zerstört aber alle bereits erfassten Spielergebnisse (siehe [Schritt 12 Reset-Warnung](#step-12-monitor)).
3. **Wenn beides nicht in Frage kommt:** Wechsle auf die **herkömmliche Methode**: Spiele auf Papier protokollieren, Ergebnisse direkt in der ClubCloud erfassen. Die Scoreboards kannst du für die einzelnen Spiele im **[Trainingsmodus](#glossary-system)** weiterbenutzen (kein Turnier-Kontext, aber funktionierende Punkterfassung).

Eine Sicherheitsabfrage vor dem Reset bei laufendem Turnier sowie ein Parameter-Verifikationsdialog vor dem Start sind als Folge-Features für eine spätere Phase eingeplant — sie reduzieren das Risiko, dass dieser Notfall überhaupt eintritt.

<a id="ts-endrangliste-missing"></a>
### Endrangliste fehlt nach Turnierende (in der ClubCloud)

**Problem:** Das Turnier ist abgeschlossen, in der ClubCloud erscheint aber keine Endrangliste mit Platzierungen.

**Klarstellung:** Carambus **berechnet** die Turnier-Endrangliste automatisch und zeigt sie im **Turnier-Monitor** an (siehe Übersichtsseite: Platzierungen, Bälle, Aufnahmen, HS, GD pro Spieler) — auch am Scoreboard ist sie über **„Turniere → Turnier auswählen → Ergebnisse"** abrufbar. Sollte die berechnete Rangliste im Turnier-Monitor **nicht** sichtbar sein, ist das ein **echter Fehler** (fatal — bitte sofort an die Entwicklung melden).

**Tatsächliches Problem:** Was hier fehlt, ist die **Übertragung** der Carambus-Rangliste in die ClubCloud. Carambus generiert eine berechnete Tabelle, aber:

- Es gibt aktuell **keinen automatischen Upload** der Endrangliste in die ClubCloud (nur die Einzelergebnisse werden via `auto_upload_to_cc` übertragen).
- Ob Carambus eine **CSV der Endrangliste** generiert, muss noch verifiziert werden — möglicher Bug, TODO.
- In der ClubCloud existiert nur ein **manuelles Edit-Formular** für die Rangliste, kein Upload-Endpunkt.

**Lösung:** Die Endrangliste muss aktuell **manuell in der ClubCloud** gepflegt werden. Den Workflow findest du im Anhang [Endrangliste in der ClubCloud pflegen](#appendix-rangliste-manual). Die Werte für die Pflege liest du direkt aus dem Carambus-Turnier-Monitor ab (oder aus der Scoreboard-Ergebnisansicht).

**Folge-Feature (TODO):** Eine programmatische Übertragung der Endrangliste an die ClubCloud — über eine Emulation des CC-Edit-Formulars — ist als Folge-Feature für v7.1+ vorgesehen.

<a id="ts-csv-upload"></a>
### CSV-Upload in die ClubCloud funktioniert nicht

**Problem:** Du hast am Ende des Turniers eine CSV-Datei mit den Ergebnissen, aber die ClubCloud nimmt sie nicht an oder wirft Validierungsfehler.

**Ursache:** Der CSV-Upload setzt voraus, dass die **Teilnehmerliste in der ClubCloud finalisiert** ist — wenn dort ein Spieler fehlt, der im CSV vorkommt, scheitert der Import. Die Teilnehmerliste-Finalisierung über die CC-API ist in Carambus aktuell nicht implementiert; sie muss manuell durch einen Club-Sportwart in der ClubCloud-Admin-Oberfläche erfolgen.

**Lösung:** Den vollen Ablauf inkl. der nötigen Berechtigungen findest du im Anhang [CSV-Upload in der ClubCloud](#appendix-cc-csv-upload). Im Zweifel bitte den Club-Sportwart deines Vereins, die Teilnehmerliste in der ClubCloud zuerst zu finalisieren.

<a id="ts-player-withdraws"></a>
### Spieler zieht während des Turniers zurück

**Problem:** Ein Spieler kann während des Turniers nicht weiterspielen (Krankheit, Notfall, Rückzug).

**Ursache:** Carambus unterstützt einen sauberen **Match-Abbruch / Spieler-Rückzug während des laufenden Turniers** in der aktuellen Version **nicht**. Die Funktion **muss noch implementiert werden** — sie ist als mittelgroßes Folge-Feature für v7.1+ eingeplant.

**Lösung (Workaround):** Beende das laufende Spiel des Spielers am Scoreboard mit dem zuletzt erfassten Stand. Für die folgenden Runden behandle den ausgefallenen Spieler de-facto wie ein [Freilos](#glossary-system) — die Gegner bekommen die Partie ggf. außerhalb von Carambus zugeschrieben. Dokumentier den Vorgang manuell im Turnierprotokoll und in der ClubCloud.

<a id="ts-english-labels"></a>
### Englische Feldbezeichnungen im Start-Formular

**Problem:** Im Start-Formular (Schritt 7) erscheinen einige Parameter mit englischen oder unklaren Labels (z. B. *Tournament manager checks results before acceptance*, *Assign games as tables become available*).

**Ursache:** Fehlende oder defekte Einträge in den i18n-Dateien (`config/locales/de.yml`). Die Korrektur ist als UI-Feature für eine Folge-Phase eingeplant.

**Lösung (bis die i18n-Korrektur ausgerollt ist):** Nutz die folgende Übersetzungstabelle:

| Englisches Label | Deutsche Bedeutung |
|------------------|--------------------|
| Tournament manager checks results before acceptance | Manager bestätigt Ergebnisse vor Annahme (manuelle Rundenwechsel-Kontrolle) |
| Assign games as tables become available | Spiele zuweisen, sobald Tische frei werden |
| auto_upload_to_cc | Ergebnisse automatisch in ClubCloud hochladen |

Im Zweifel behalt die Standardwerte bei und verifizier die Werte vor dem Klick auf „Starte den Turnier Monitor".

<a id="ts-nachstoss-forgotten"></a>
### Nachstoß am Scoreboard vergessen

**Problem:** In einer Karambol-Disziplin mit Nachstoß-Regel ist die eigentliche Aufnahme abgeschlossen, der Nachstoß wurde aber noch nicht eingegeben.

**Ursache:** Bedienfehler am Scoreboard — die Nachstoß-Eingabe wird in der Praxis häufig vergessen oder zu spät erkannt.

**Lösung:** Der Spieler muss den **Nachstoß einfach noch eingeben** und damit das Spiel korrekt abschließen. Erst danach erscheint der Protokolleditor zur Bestätigung. **Achtung:** Solange der Nachstoß nicht eingegeben ist, **bleibt das Spiel offen — und damit ist der gesamte Turnierablauf blockiert** (kein Rundenwechsel, keine Folge-Partie auf diesem Tisch). Sprich also beim ersten Anzeichen die Spieler direkt an, damit sie den Nachstoß nachtragen, bevor das Protokoll bestätigt wird. Nach Protokollbestätigung gibt es keinen sauberen Korrekturpfad mehr — eine Nachtragung müsste dann außerhalb von Carambus dokumentiert und in die ClubCloud eingetragen werden.

<a id="ts-shootout-needed"></a>
### Stechen / Shootout nötig (KO-Turnier)

**Problem:** Bei einem KO-Turnier endet eine Partie unentschieden und es wäre ein Stechen erforderlich.

**Ursache (kritischer Fehler):** Stechen / Shootout wird in der aktuellen Carambus-Version **überhaupt nicht unterstützt** — und das ist nicht nur ein fehlendes Feature, sondern ein **kritischer Fehler bei KO-Turnieren**: Carambus geht bei Gleichstand automatisch mit dem **Anstoßenden** weiter, statt ein Stechen anzusetzen. Das verfälscht das Turnierergebnis. Echter Shootout-Support ist als kritisches Feature für ein späteres Milestone (v7.1 oder v7.2) eingeplant.

**Lösung (Workaround):** Führ das Stechen **außerhalb von Carambus** durch — am Tisch auf Papier protokollieren — und trag das Endergebnis manuell in die ClubCloud ein. Korrigier den von Carambus automatisch durchgereichten „Sieg des Anstoßenden" entsprechend nach. Der Carambus-Spielstand muss in solchen Fällen außerhalb des Systems abgewickelt werden.

---

<a id="appendix"></a>
## Anhang: Spezialfälle und vertiefende Abläufe

Die folgenden Abschnitte beschreiben vollständige Alternativ-Abläufe und vertiefende Themen, die nicht in den linearen Walkthrough passen. Sie werden aus den entsprechenden Schritten und Troubleshooting-Rezepten verlinkt.

<a id="appendix-no-invitation"></a>
### Einladung fehlt — Setzliste ohne PDF erzeugen

**Wann:** Wenn du ausnahmsweise kein offizielles NBV-Einladungs-PDF erhalten hast (z. B. Internetprobleme beim Empfang oder PDF-Upload, spontan organisiertes Vereinsturnier, internes Pokalturnier, vergessene Einladung des Sportwarts).

**Vorgehen:**

1. **Carambus öffnen** und das Turnier anlegen oder aus der ClubCloud synchronisieren wie in [Schritt 2](#step-2-load-clubcloud) beschrieben — auch ohne PDF läuft der ClubCloud-Sync, sofern das Turnier in der ClubCloud existiert.
2. **In Schritt 3 (Setzliste)** überspringst du den PDF-Upload-Pfad. Stattdessen übernimmst du die initiale Teilnehmerliste direkt aus der ClubCloud-Meldeliste — über den Link „→ Mit Meldeliste zu Schritt 3 (nach Rangliste sortiert)" im Einladungs-Hochladen-Formular (siehe [Schritt 4 Navigation](#step-4-participants), Eingangspunkt 3).
3. **In Schritt 4 (Teilnehmerliste)** klick auf **„Nach Ranking sortieren"**, um die Spieler nach den in Carambus gepflegten [Ranglisten](#glossary-system) zu ordnen. Diese Ordnung ersetzt die fehlende offizielle Setzliste.
4. **Manuell nachsortieren**, falls der Sportwart einen abweichenden Wunsch geäußert hat (z. B. titelverteidigender Spieler an Position 1).
5. **Abschließen** wie in [Schritt 5](#step-5-finish-seeding) — von dort läuft der Wizard normal weiter.

Hinweis: Diese Setzliste ist eine **Carambus-interne** und nicht offiziell. Bei NBV-relevanten Turnieren solltest du die Setzliste nachträglich von der zuständigen Sportwart-Person bestätigen lassen.

<a id="appendix-missing-player"></a>
### Spieler erscheint nicht zum Turnier

**Wann:** Ein in der Meldeliste aufgeführter Spieler erscheint nicht am Turniertag.

**Vorgehen:**

1. **Vor dem Turnierstart** (vor [Schritt 5 „Teilnehmerliste abschließen"](#step-5-finish-seeding)): Auf der Teilnehmerliste-Bearbeitungsseite ([Schritt 4](#step-4-participants)) findest du in der Spalte **„Teilnehmer"** für jede Zeile eine **Checkbox**. Entferne den Haken bei dem fehlenden Spieler — die Zeile wird damit aus der Teilnehmerliste herausgenommen. Prüf anschließend, ob die verbleibende Spielerzahl noch zum gewählten Turnierplan passt. Falls ein anderer Plan nötig wird, weist Carambus auf der Wizard-Seite einen neuen Vorschlag aus.
2. **Falls die Teilnehmerliste schon abgeschlossen ist**, aber das Turnier noch nicht gestartet wurde: Du kannst das Setup über **„Zurücksetzen des Turnier-Monitors"** zurücksetzen und die Teilnehmerliste neu zusammenstellen. **Achtung:** Vor Schritt 9 ist Reset risikolos, danach nicht — siehe [Schritt 12 Reset-Warnung](#step-12-monitor).
3. **Wenn das Turnier bereits gestartet ist und der Spieler in einer noch nicht gespielten Runde steht**, gibt es in der aktuellen Carambus-Version **keinen sauberen Pfad — diese Funktion muss noch implementiert werden**. Behandel den ausgefallenen Spieler bis dahin de facto wie ein [Freilos](#glossary-system) (im Sinne von „spielfrei in dieser Runde") — siehe [Spieler zieht während des Turniers zurück](#ts-player-withdraws).

**Vorbeugung:** Bestätig die Anwesenheit aller Spieler kurz vor [Schritt 5](#step-5-finish-seeding), nicht erst nach Turnierstart.

<a id="appendix-nachmeldung"></a>
### Spieler-Nachmeldung am Turniertag

**Wann:** Ein Spieler, der nicht in der ClubCloud-Meldeliste steht, möchte am Turniertag noch antreten.

**Vorgehen:**

1. **Klär zuerst die Berechtigung:** Hat der Spieler eine gültige DBU-Lizenz? Erlaubt die Turnierordnung On-site-Nachmeldungen? Hat der Sportwart zugestimmt? Im Zweifel: Anruf beim Landessportwart.
2. **Vor Turnierstart** ist Nachmeldung in Carambus einfach: In [Schritt 4](#step-4-participants) trägst du die DBU-Nummer des nachzumeldenden Spielers in das Feld **„Spieler mit DBU-Nummer hinzufügen"** ein und klickst auf **„Spieler hinzufügen"**. Anschließend „Nach Ranking sortieren" oder per Drag-and-Drop nachsortieren.
3. **Eintragung in der ClubCloud:** Damit die Nachmeldung in die offizielle Statistik einfließt und der Endergebnis-Upload funktioniert, muss der Spieler **auch in der ClubCloud-Melde- und Teilnehmerliste** ergänzt werden. Das kann nur ein **Club-Sportwart mit den entsprechenden Rechten** (siehe [Anhang ClubCloud-Upload](#appendix-cc-upload)). Wenn der Sportwart nicht vor Ort ist, musst du ihn anrufen oder die Nachmeldung später nachpflegen lassen.
4. **Nach Turnierstart** ist Nachmeldung in Carambus aktuell **nicht sauber unterstützt** — der einzige Workaround ist das Zurücksetzen des Turnier-Monitors mit allen Konsequenzen.

<a id="appendix-cc-upload"></a>
### ClubCloud-Upload — zwei Wege

> **Hinweis:** Dieser Anhang ist eine erste Fassung auf Basis der bereits bekannten SME-Informationen. Eine vollständige Fassung (inkl. Screenshots der CC-Admin-Oberfläche, exakter Pfade und typischer Fehlermeldungen) ist als PREP-04 in Phase 36c vorgesehen und wird hier später ergänzt.

Carambus kennt zwei Wege, um Turnier-Ergebnisse in die ClubCloud zurückzuspielen — beide haben dieselbe Voraussetzung, aber unterschiedliche Workflows.

**Gemeinsame Voraussetzung:** Die **Teilnehmerliste muss in der ClubCloud finalisiert sein**. Das bedeutet: Jeder Spieler, der im Turnier antritt (auch [Nachmeldungen](#appendix-nachmeldung)), muss in der CC-Teilnehmerliste eingetragen sein, bevor irgendein Ergebnis hochgeladen werden kann. Die Finalisierung der Teilnehmerliste über die CC-API ist in Carambus **aktuell nicht implementiert** — sie muss manuell durch einen **Club-Sportwart** in der ClubCloud-Admin-Oberfläche erfolgen. Diese Berechtigung haben in der Regel nicht alle Vereinsmitglieder, sondern nur ausgewählte Funktionäre.

**Pfad 1: Einzelübertragung pro Spiel** (`auto_upload_to_cc` aktiviert)

- Jedes einzelne Ergebnis wird **sofort nach Match-Ende** an die ClubCloud übertragen.
- Technisch erfolgt das durch Formular-Emulation in der ClubCloud-Admin-Schnittstelle.
- **Voraussetzung:** Wie oben — die Teilnehmerliste in der CC muss bereits finalisiert sein, **bevor** das erste Spiel endet.
- **Vorteil:** Ergebnisse sind in nahezu Echtzeit in der ClubCloud sichtbar (z. B. für Live-Berichte des Verbands).
- **Aktivieren:** Im Start-Formular ([Schritt 7](#step-7-start-form)) die Checkbox **„Ergebnisse automatisch in ClubCloud hochladen"** (`auto_upload_to_cc`) setzen.

**Pfad 2: CSV-Batch-Upload am Ende** (`auto_upload_to_cc` deaktiviert oder Pfad 1 nicht möglich)

- Alle Ergebnisse werden während des Turniers nur lokal in Carambus erfasst.
- Am Ende des Turniers stellt Carambus eine **CSV-Datei** mit allen Spielergebnissen bereit.
- Die CSV wird per E-Mail an den Turnierleiter geschickt (oder steht zum Download bereit).
- Der Turnierleiter leitet sie an den Club-Sportwart weiter, der sie in die (jetzt finalisierte) ClubCloud-Teilnehmerliste importiert — das Detail-Vorgehen siehe [CSV-Upload in der ClubCloud](#appendix-cc-csv-upload).
- **Vorteil gegenüber Pfad 1:** Der Sportwart kann die CC-Teilnehmerliste auch **nach** dem Turnier finalisieren — Pfad 2 ist robust gegen die Berechtigungs-Lücke.

**Best Practice — Pfad 1 reibungslos einrichten:** Der einfachste Weg, Pfad 1 (automatische Einzelübertragung) sicher zum Laufen zu bringen, ist die Vorbereitung **vor dem Turnierstart**. Sobald du als Turnierleiter die Einladung erhältst, sprich den Landessportwart oder einen anderen Berechtigten an, damit er die ClubCloud-Teilnehmerliste mit dem finalisierten Turnierplan abgleicht. Das kann z. B. bequem stattfinden, **während die Spiele der ersten Runde laufen** — dann läuft die automatische Übertragung der Einzelergebnisse während des Turniers reibungslos, und externe Beobachter können den Turnierverlauf in der ClubCloud live verfolgen.

**Berechtigungsproblem (offen):** Fehlende Spieler in der ClubCloud-Teilnehmerliste hinzufügen können nur **Club-Sportwarte**. Wenn keiner vor Ort ist, blockiert das Pfad 1 vollständig und Pfad 2 zumindest bis nach dem Turnier. **Diskussion im Vorstand geplant:** Carambus soll das Recht erhalten, bei Mismatch zwischen Carambus-Teilnehmerliste und ClubCloud die CC-Liste programmatisch abzugleichen — dann läuft Pfad 1 ohne menschliches Eingreifen. Eine alternative mögliche Lösung — die Hinterlegung von Club-Sportwart-Credentials in Carambus für genau diesen Delegations-Fall — ist als Folge-Feature für v7.1+ vorgesehen.

<a id="appendix-cc-csv-upload"></a>
### CSV-Upload in der ClubCloud (Pfad 2 im Detail)

> **Hinweis:** Dieser Anhang ist eine erste Fassung. Eine vollständige Schritt-für-Schritt-Anleitung mit Screenshots der CC-Admin-Oberfläche, exakten Menü-Pfaden und Liste der häufigsten Validierungsfehler ist als PREP-04 in Phase 36c vorgesehen. Bis dahin gilt:

**Wer:** Ein **Club-Sportwart** mit Schreibrechten auf die Teilnehmerliste und die Ergebnis-Tabelle in der ClubCloud.

**Voraussetzungen:** Die **Teilnehmerliste in der CC ist finalisiert** (siehe [ClubCloud-Upload — zwei Wege](#appendix-cc-upload)) und enthält jeden Spieler, der im CSV vorkommt — sonst scheitert der Import an einem Validierungsfehler.

**Wo in der ClubCloud:** In der ClubCloud-Admin-Oberfläche unter dem entsprechenden Turnier; die genaue Menü-Position variiert nach CC-Version. Bei Unsicherheit klär das mit dem Verbands-Sportwart.

**Häufige Fehlermeldungen (erste Liste, wird in PREP-04 ergänzt):**

- **„Spieler nicht gefunden"** — der Spieler ist im CSV, aber nicht in der CC-Teilnehmerliste. Lösung: Spieler in der CC-Teilnehmerliste ergänzen (Sportwart-Recht erforderlich) und CSV erneut importieren.
- **„Format fehlerhaft"** — die CSV entspricht nicht dem erwarteten CC-Format. Sehr selten, da Carambus die CSV in dem Format generiert, das der CC-Importer erwartet. Wenn doch: das genaue Format mit dem Verbands-Sportwart abstimmen.
- **„Doppelte Eintragung"** — ein Spieler wurde bereits per Pfad 1 (Einzelübertragung) hochgeladen und steht jetzt nochmal im CSV. Lösung: doppelten Eintrag in der CSV entfernen oder den Import explizit als „Update" konfigurieren.

<a id="appendix-rangliste-manual"></a>
### Endrangliste in der ClubCloud manuell pflegen

**Hintergrund:** Carambus **berechnet** die Turnier-Endrangliste mit allen disziplinabhängigen Sonderregeln bereits automatisch — sie steht im **Turnier-Monitor** (`TournamentMonitor#show`, Übersichtsseite mit Platzierungen, gewonnenen Partien, GD, HS pro Spieler) und ist auch am Scoreboard über **„Turniere → Turnier auswählen → Ergebnisse"** abrufbar. Was Carambus aktuell **nicht** kann: diese berechnete Rangliste programmatisch in die ClubCloud übertragen. Deshalb muss die Endrangliste **manuell aus Carambus in die ClubCloud kopiert** werden.

**Wer:** Der Turnierleiter oder ein Club-Sportwart mit Schreibrechten auf die Ergebnis-Tabelle.

**Wann:** Nach dem letzten Spiel, sobald alle Ergebnisse erfasst sind und der Carambus-Turnier-Monitor die finale Tabelle anzeigt.

**Vorgehen:**

1. **Lies die berechnete Endrangliste in Carambus ab** — entweder im Turnier-Monitor (`TournamentMonitor#show`) oder am Scoreboard über „Turniere → Turnier auswählen → Ergebnisse". Die Werte (Platz, Spieler, gewonnene Partien, GD, HS, etc.) sind dort bereits korrekt nach den disziplinabhängigen Regeln sortiert.
2. **Trag die finalen Platzierungen in die ClubCloud ein.** Die ClubCloud bietet aktuell nur ein manuelles **Edit-Formular** für die Rangliste — keinen Upload-Endpunkt. Die genaue Stelle in der CC-Admin-Oberfläche variiert nach CC-Version.
3. **Konsistenzprüfung:** Vergleich die Carambus-Einzelergebnisse mit den in der CC eingetragenen Werten — falls Pfad 1 (Einzelübertragung pro Spiel via `auto_upload_to_cc`) genutzt wurde, sollten Bälle/Aufnahmen pro Partie identisch sein. Die finale Platzierungstabelle muss in jedem Fall manuell übertragen werden.

**Sonderfall KO-Turniere mit Stechen:** Carambus berechnet bei Gleichstand in KO-Partien aktuell automatisch einen Sieg für den Anstoßenden, ohne ein Stechen anzusetzen — siehe [Stechen / Shootout nötig](#ts-shootout-needed). Die Endrangliste in der ClubCloud muss in solchen Fällen entsprechend dem **außerhalb von Carambus durchgeführten Stechen** manuell korrigiert werden.

**Hinweise (offene TODOs):**

- **CSV-Generierung der Endrangliste** — ob Carambus zusätzlich zur Anzeige im Turnier-Monitor auch eine CSV der Endrangliste exportiert, muss noch verifiziert werden (möglicher Bug oder bisher fehlende Funktion).
- **Programmatische Übertragung an die ClubCloud** — eine emulierte Bedienung des CC-Edit-Formulars (analog zur Einzelergebnis-Übertragung über `auto_upload_to_cc`) ist als Folge-Feature für v7.1+ vorgesehen. Wenn das Feature ausgerollt ist, entfällt dieser manuelle Anhang.

---

*Für weiterführende technische Details siehe die [Entwickler-Dokumentation](../developers/index.md).*
