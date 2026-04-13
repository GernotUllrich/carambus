# RubyMine Einrichtungsanleitung - Beheben von "Rails server launcher was not found"

## Fehler: "Rails server launcher was not found in a project"

Dieser Fehler tritt auf, wenn RubyMine dein Projekt nicht als Rails-Projekt erkennt. Befolge diese Schritte zur Behebung.

---

## Losungsschritte (In Reihenfolge)

### Schritt 1: Caches leeren und neu starten

1. **RubyMine öffnen**
2. Gehe zu: **File** → **Invalidate Caches...**
3. Haken setzen bei: **Clear file system cache and Local History**
4. Klicken auf: **Invalidate and Restart**
5. Warte, bis RubyMine neu gestartet und neu indiziert hat

Dies behebt das Problem häufig, indem RubyMine die Projektstruktur neu analysiert.

---

### Schritt 2: Ruby SDK-Konfiguration prüfen

1. Gehe zu: **RubyMine** → **Preferences** (oder **Settings** unter Windows/Linux)
   - Tastenkürzel: `Cmd+,` (Mac) oder `Ctrl+Alt+S` (Windows/Linux)
2. Navigiere zu: **Languages & Frameworks** → **Ruby SDK and Gems**
3. **Prüfen, ob ein SDK ausgewählt ist:**
   - Falls kein SDK: Klicke auf **+** und füge deine Ruby-Version hinzu
   - Falls SDK vorhanden: Sicherstellen, dass es die richtige Version ist (mit `ruby -v` im Terminal prüfen)
4. **Häufige SDK-Speicherorte auf macOS:**
   - Homebrew: `/usr/local/opt/ruby/bin/ruby` oder `/opt/homebrew/opt/ruby/bin/ruby`
   - rbenv: `~/.rbenv/versions/{version}/bin/ruby`
   - rvm: `~/.rvm/rubies/{version}/bin/ruby`
5. Klicke auf **Apply** oder **OK**

**Ruby-Version ermitteln:**
```bash
cd /Users/gullrich/carambus/carambus_master
ruby -v
which ruby
```

---

### Schritt 3: Rails Framework-Erkennung konfigurieren

1. Gehe in **Preferences/Settings** zu: **Languages & Frameworks** → **Ruby on Rails**
2. **Diese Einstellungen prüfen:**
   - **Rails version:** Sollte automatisch erkannt werden (Rails ~> 7.2.0.beta2 für dieses Projekt)
   - **Rails root:** Sollte auf `/Users/gullrich/carambus/carambus_master` zeigen
   - **Rails application root:** Wie Rails root
3. Falls Rails-Version nicht erkannt:
   - Klicke auf **Detect**-Schaltfläche
   - Oder manuell setzen: **Rails root** auf dein Projektverzeichnis
4. Klicke auf **Apply**

---

### Schritt 4: Projekt von Datenträger neu laden

1. Gehe zu: **File** → **Reload Project from Disk**
2. Warte, bis RubyMine die Projektstruktur neu gescannt hat
3. Prüfen, ob der Fehler weiterhin besteht

---

### Schritt 5: Als Rails-Projekt neu importieren (falls Schritte 1-4 nicht helfen)

1. **RubyMine schließen**
2. **Zum Projektverzeichnis navigieren:**
   ```bash
   cd /Users/gullrich/carambus/carambus_master
   ```
3. **Projekt in RubyMine öffnen:**
   ```bash
   # Option 1: Aus RubyMine öffnen
   # File → Open → Ordner carambus_master auswählen
   
   # Option 2: Aus Terminal (falls über Kommandozeilentools installiert)
   mine .
   ```
4. **Wenn RubyMine sich öffnet:**
   - Es sollte fragen: "Would you like to configure this project as a Rails application?"
   - Klicke auf **Yes** oder **Configure**
   - Falls es nicht fragt, weiter mit Schritt 6

---

### Schritt 6: Projektstruktur prüfen

RubyMine muss diese Rails-Dateien erkennen:

**Erforderliche Dateien (sollten vorhanden sein):**
- ✅ `Gemfile` (mit `gem "rails"`)
- ✅ `config.ru`
- ✅ `Rakefile`
- ✅ `bin/rails`
- ✅ `config/application.rb`

**Prüfen ob vorhanden:**
```bash
cd /Users/gullrich/carambus/carambus_master
ls -la Gemfile config.ru Rakefile bin/rails config/application.rb
```

Falls eine fehlt, ist das Projekt möglicherweise nicht korrekt eingerichtet.

---

### Schritt 7: Deployment-Server konfigurieren (nach Behebung)

Sobald RubyMine das Rails-Projekt erkennt:

1. Gehe zu: **Tools** → **Deployment** → **Configuration**
2. Klicke auf **+** um einen neuen Server hinzuzufügen
3. Wähle deinen Deployment-Typ (z.B. **SFTP**, **Local**, **FTP**)
4. Server-Einstellungen konfigurieren:
   - **Name:** Dein Servername
   - **Type:** SFTP (oder bevorzugter Typ)
   - **Host:** Deine Serveradresse
   - **Port:** SSH-Port (normalerweise 22)
   - **User name:** Dein SSH-Benutzername
   - **Authentication:** Passwort oder Schlüsselpaar
5. **Test Connection** um Verbindung zu prüfen
6. Klicke auf **OK**

---

### Schritt 8: Run-Konfiguration für Rails-Server erstellen

Falls noch eine Rails-Server-Konfiguration benötigt wird:

1. Gehe zu: **Run** → **Edit Configurations...**
2. Klicke auf **+** → **Rails**
3. Konfigurieren:
   - **Name:** Rails Server
   - **Server:** Script: rails server
   - **Environment:** `RAILS_ENV=development`
   - **Port:** `3000` (oder bevorzugter Port)
4. Klicke auf **OK**

---

## Fehlerbehebung

### Problem: "No SDK specified"

**Lösung:**
```bash
# Ruby-Installation finden
which ruby
# In RubyMine hinzufügen: Preferences → Ruby SDK and Gems → + → Add SDK
```

---

### Problem: "Rails not detected"

**Lösung:**
```bash
# Prüfen ob Rails in Gemfile vorhanden
cd /Users/gullrich/carambus/carambus_master
grep rails Gemfile

# Gems installieren falls nötig
bundle install

# Rails-Version prüfen
bundle exec rails -v
```

Dann in RubyMine: **Preferences** → **Ruby on Rails** → Klicke auf **Detect**

---

### Problem: Mehrere Projektstämme

Falls RubyMine durch die Multi-Projekt-Struktur verwirrt ist:

1. **Option 1:** `carambus_master` als Projektstamm öffnen (nicht `carambus`)
2. **Option 2:** Projektstamm konfigurieren:
   - **File** → **Project Structure** (oder `Cmd+;`)
   - **Project Settings** → **Project**
   - **Project SDK:** Ruby SDK auswählen
   - **Project compiler output:** Standard lassen oder auf `tmp/rubymine/out` setzen

---

### Problem: Immer noch nicht funktionsfähig nach allen Schritten

**Ultima Ratio:**

1. RubyMine schließen
2. RubyMine-Caches löschen:
   ```bash
   rm -rf ~/Library/Caches/RubyMine*
   rm -rf ~/Library/Application\ Support/RubyMine*
   # Hinweis: Dabei werden RubyMine-Einstellungen zurückgesetzt — vorher sichern!
   ```
3. `.idea`-Ordner im Projekt löschen (falls vorhanden):
   ```bash
   cd /Users/gullrich/carambus/carambus_master
   rm -rf .idea
   ```
4. Projekt in RubyMine erneut öffnen
5. SDK- und Rails-Einstellungen neu konfigurieren

---

## Verifizierung

Nach der Behebung prüfen, ob RubyMine Rails erkennt:

1. **Projektstruktur prüfen:**
   - Rechtsklick auf Projektstamm → **Show in Explorer** → Rails-Struktur sollte erscheinen
   
2. **Rails-Erkennung prüfen:**
   - **Preferences** → **Ruby on Rails** → Rails-Version sollte angezeigt werden (z.B. "7.2.0.beta2")

3. **Deployment-Konfiguration ausprobieren:**
   - **Tools** → **Deployment** → **Configuration**
   - Fehler sollte verschwunden sein

4. **Rails Console prüfen:**
   - **Tools** → **Run Rails Console** → Sollte funktionieren

---

## Kurzcheckliste

- [ ] Caches geleert und neu gestartet
- [ ] Ruby SDK korrekt konfiguriert
- [ ] Rails Framework erkannt
- [ ] Projekt von Datenträger neu geladen
- [ ] Deployment-Konfiguration kann fehlerfrei geöffnet werden

---

## Weiterführende Ressourcen

- [RubyMine Documentation - Rails Support](https://www.jetbrains.com/help/ruby/rails.html)
- [RubyMine Documentation - Deployment](https://www.jetbrains.com/help/ruby/deployment.html)

---

**Zuletzt aktualisiert:** 2025-01-28  
**RubyMine-Version:** Eigene Version prüfen: **RubyMine** → **About RubyMine**
