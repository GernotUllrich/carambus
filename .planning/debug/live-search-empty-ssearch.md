# Live-Suche: `sSearch` kommt leer im SearchReflex an

**Erfasst:** 2026-08-14 · **Status:** offen, reproduziert auf Production (`api.carambus.de`)
**Einordnung:** vorbestehend — **nicht** durch die ActionCable-Arbeit vom 2026-08-14 verursacht (Beleg unten)

## Symptom

Die Sofortsuche filtert nicht. Erst `RETURN` liefert Ergebnisse.

Ursache dafür ist, dass beide Wege verschieden sind:

| Weg | Technik | Cable nötig |
|---|---|---|
| Tippen | `input->SearchReflex#perform` (StimulusReflex) | ja |
| RETURN | `<form action="/players" method="get" target="table_wrapper">` | nein |

`RETURN` funktioniert also auch dann, wenn der Reflex-Pfad defekt ist — deshalb wirkt es wie
„Suche geht, nur nicht sofort".

## Belegte Fakten (Production-Log)

Reflex feuert, rendert aber mit **leerem** Suchstring:

```
[ActionCable] [anonymous] Rendering table with 1 records
[ActionCable] [anonymous]   Parameters: {"sSearch"=>""}
[ActionCable] [anonymous] [d7821dae] 1/1 SearchReflex#perform -> body via Page Morph (morph)
```

Direkt danach dasselbe Feld per RETURN — korrekt befüllt:

```
Started GET "/players?sSearch=Gern"
  Parameters: {"sSearch"=>"Gern"}
```

## Warum es nicht an der ActionCable-Arbeit liegt

Gegenprobe am selben Tag, gegen dieselbe Production-Instanz:

- Ein zweiter Client (Browser-Pane, **nicht** eingeloggt) tippte `ZQXPRB`
- Server-Log: `[ActionCable] [anonymous] Parameters: {"page"=>"1", "sSearch"=>"ZQXPRB"}`
- Seite zeigte korrekt „Keine Ergebnisse gefunden für 'ZQXPRB'"

Beide Clients liefen über eine **anonyme** Verbindung und **dasselbe** JS-Bundle
(`application-02055b11…d191f0c89e4bbeebd6929d85799c7009.js`, Hash identisch verglichen).
Ein Client serialisiert korrekt, der andere nicht. Die Identitätsänderung in
`find_verified_user` kann das folglich nicht erklären — sie berührt die
Formular-Serialisierung nicht.

## Nächster Schritt

Im **betroffenen** Browser nach ein paar Tastenanschlägen ausführen:

```js
(() => { const i = document.querySelector('#sSearch'); const f = i?.closest('form');
  return { wert: i?.value, attribut: i?.getAttribute('value'),
           formEntries: f ? Array.from(new FormData(f).entries()) : null,
           anzahlSSearch: document.querySelectorAll('[name="sSearch"]').length,
           permanent: i?.dataset.reflexPermanent }; })()
```

`formEntries` zeigt exakt die serialisierten Paare.

## Hypothesen

1. **Doppeltes `name="sSearch"`** im Formular — bei Duplikaten gewinnt der letzte Wert;
   ein leeres zweites Feld würde den getippten überschreiben. Der eingeloggte Zustand
   rendert ggf. zusätzliche Elemente (`anzahlSSearch` im Snippet prüft das).
2. **`data-reflex-permanent="search"` + Page Morph**: Der Reflex macht
   `render partial:` — dessen Rückgabe verwirft StimulusReflex, es folgt ein
   **Page Morph** über `body` (siehe Logzeile). Wird das Input dabei doch ersetzt, fällt
   es auf `value="<%= @sSearch %>"` zurück; da `params[:sSearch]` leer ist, greift in
   `SearchReflex#perform` das `if params[:sSearch].present?` nicht, `@sSearch` bleibt nil
   und der Wert wird leer neu gerendert.
3. Browser-Extension, die Formularfelder anfasst.

## Nebenbefund

`SearchReflex#perform` endet mit `render partial: table_partial, …`, dessen Ergebnis
StimulusReflex ignoriert — daher der Page Morph über `body` statt eines gezielten
Selector Morph. Das rendert bei **jedem Tastendruck** die komplette Seite neu. Unabhängig
vom Bug ein Performance-Thema; ein `morph "#table_wrapper", render(partial: …)` wäre das
Naheliegende. Vor einer Änderung prüfen, ob der Page Morph absichtlich ist (er aktualisiert
auch Scope-Band und Filter-Popup).
