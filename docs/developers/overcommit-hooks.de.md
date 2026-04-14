# Overcommit Git-Hooks — MkDocsBuild

Dieses Projekt nutzt [overcommit](https://github.com/sds/overcommit), um einen einzigen, eng umrissenen Pre-Commit-Hook zu verwalten: **MkDocsBuild**. Der Hook verhindert strukturell eine Fehlerklasse, bei der Quellbearbeitungen in `docs/**/*.md` committet werden, ohne dass der generierte `public/docs/**/*`-Baum im selben Commit neu gebaut wird.

## Was der Hook tut

Wenn du `git commit` ausführst und im Staging-Set mindestens ein Pfad `docs/**/*.md` enthalten ist, macht der Hook:

1. Führt `bin/rails mkdocs:build` aus — das regeneriert `site/` und kopiert es nach `public/docs/`.
2. Führt `git add public/docs/` aus — damit werden die neu generierten Dateien in den laufenden Commit gefaltet, sodass Quelle und generierte Ausgabe atomar zusammen ausgeliefert werden.

Schlägt der Build fehl, wird der Commit mit der Fehlerausgabe des Rake-Tasks abgebrochen. In diesem Zustand wird nichts committet.

### Warum es existiert

Der Rails-Server liefert `/docs/` aus dem versionierten `public/docs/`-Baum aus — **nicht** aus dem `docs/`-Quellbaum. Jede Abweichung zwischen Quelle und generierter Ausgabe führt dazu, dass stillschweigend veraltete Inhalte an Endnutzer ausgeliefert werden. Während des v7.0-UAT tauchte dies als Gap **G-02** (Commit `7cf16114`) auf — `public/docs/` hinkte vier Wochen hinterher und musste spontan neu gebaut werden. Dieser Hook macht diese Drift-Klasse auf einem Arbeitsplatz, an dem er aktiv ist, strukturell unmöglich.

## Aktivierung (einmalig, pro frischem Clone)

Overcommit wird als Gemfile-Gem ausgeliefert, aber die Hooks werden **nicht** automatisch installiert. Bei jedem frischen Clone ausführen:

```bash
bundle exec overcommit --install
bundle exec overcommit --sign
```

`--install` verdrahtet `.git/hooks/pre-commit` (und verwandte), damit sie an overcommit weiterreichen. `--sign` signiert die `.overcommit.yml`-Konfiguration; overcommit verweigert die Ausführung einer unsignierten Konfiguration als Sicherheitsmaßnahme gegen nicht vertrauenswürdige Pulls.

**Nach jeder Bearbeitung von `.overcommit.yml` oder `bin/overcommit/*` neu signieren:**

```bash
bundle exec overcommit --sign
bundle exec overcommit --sign pre-commit   # wenn sich der Inhalt eines Hook-Skripts ändert
```

Der erste Befehl signiert die Konfigurationsdatei neu; der zweite signiert einzelne Plugin-Hooks neu und ist erforderlich, sobald sich der Inhalt des referenzierten Skripts ändert.

## Voraussetzungen

Der Hook ruft `bin/rails mkdocs:build` auf, was erfordert, dass das `mkdocs`-CLI auf deinem PATH verfügbar ist. Installation via pip:

```bash
pip install mkdocs-material mkdocs-static-i18n pymdown-extensions
```

Fehlt `mkdocs` beim Auslösen des Hooks, wird der Commit abgebrochen mit:

```
[MkDocsBuild] ERROR: mkdocs CLI not found.
[MkDocsBuild] Install with:
[MkDocsBuild]   pip install mkdocs-material mkdocs-static-i18n pymdown-extensions
```

Es gibt kein stilles Überspringen bei fehlendem `mkdocs` — eine fehlende CLI blockiert den Commit immer.

## Wann er auslöst / wann nicht

- **Löst aus**, wenn mindestens ein gestageter Pfad `docs/**/*.md` matcht.
- **Löst NICHT aus**, wenn das Staging-Set nur Ruby-, JS-, ERB-, YAML-, Config- oder sonstige Dateien außerhalb von `docs/**/*.md` enthält. Overcommits `include:`-Filter kurzschließt den ganzen Hook — kein Rails-Boot, kein `mkdocs`-Aufruf, kein Overhead.

Das bedeutet: Tägliche Ruby-/JS-/Schema-Arbeit sieht keinerlei Kosten durch diesen Hook.

## Notausgang (Bypass)

Für legitime Notfälle (z. B. ein Fix committen, während der Docs-Build vorübergehend kaputt ist) kannst du den Hook für einen einzelnen Commit umgehen:

```bash
SKIP=MkDocsBuild git commit -m "fix: dringend, Docs-Rebuild steht aus"
```

Der nächste Commit, der `docs/**/*.md` berührt, regeneriert alles — der Notausgang heilt sich also beim nächsten docs-touchenden Commit von selbst.

**Nicht** `--no-verify` verwenden — das überspringt jeden Hook, nicht nur `MkDocsBuild`, und verbirgt die Tatsache, dass überhaupt ein Bypass stattgefunden hat.

## Fehlerbehebung

**"mkdocs CLI not found"** — Installiere die oben gezeigten Voraussetzungen. Das `pip install`-Kommando ist dasselbe, das sowohl der Rake-Task als auch der Hook ausgeben.

**Hook lief, aber `git status public/docs/` zeigt nichts Neues gestaget** — Das ist normal. Es bedeutet, dass deine `docs/**/*.md`-Änderung keine gerenderte HTML-Ausgabe verändert hat (z. B. hast du einen trailing newline hinzugefügt, einen Whitespace-Typo korrigiert, den mkdocs normalisiert, oder eine Datei editiert, die in der mkdocs-Config ausgeschlossen ist). Der Hook lief trotzdem erfolgreich; der Commit ist sauber.

**"Overcommit::Exceptions::InvalidHookSignature"** — Jemand hat `.overcommit.yml` oder `bin/overcommit/mkdocs-build-on-docs-change` bearbeitet. Neu signieren:

```bash
bundle exec overcommit --sign
bundle exec overcommit --sign pre-commit
```

**"Ich möchte den Hook manuell ausführen, ohne zu committen"** — Verwende:

```bash
bundle exec overcommit --run
```

Das führt alle Pre-Commit-Hooks gegen das aktuelle Staging-Set aus, ohne einen Commit anzulegen. Nützlich, um den Hook nach Änderungen zu verifizieren.

## Verwandte Dateien

- `.overcommit.yml` — Overcommit-Konfiguration (registriert MkDocsBuild, deaktiviert Default-Hooks).
- `bin/overcommit/mkdocs-build-on-docs-change` — Das Hook-Skript, das `bin/rails mkdocs:build` ausführt und `public/docs/` staged.
- `lib/tasks/mkdocs.rake` — Der Rake-Task, den der Hook aufruft (auch standalone nutzbar: `bin/rails mkdocs:build`).
