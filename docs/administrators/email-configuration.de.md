# E-Mail-Konfiguration

## Übersicht

Carambus verwendet E-Mail für:
- Benutzerregistrierung (Bestätigungs-E-Mails)
- Passwort-Zurücksetzen
- Account-Einladungen
- Benachrichtigungen

## Produktionsumgebung - SMTP-Konfiguration

### Warum SMTP statt Sendmail

Frühere Konfigurationen verwendeten `sendmail`, was auf Raspberry Pi Servern oft zu Timeouts führte, da:
- Sendmail/Postfix nicht korrekt konfiguriert war
- Der Service nicht richtig lief
- Timeouts die Benutzerregistrierung blockierten

### SMTP (Gmail)

Alle Produktionsumgebungen versenden per SMTP über Gmail. Die `production.rb` jeder Instanz wird
**generiert**: `scenario:prepare_deploy` bzw. `scenario:generate_configs` erzeugen sie aus
`lib/tasks/scenarios.rake` (`generate_production_rb_env`); auf dem Server liegt sie unter
`/var/www/<basename>/shared/config/environments/production.rb`.

**Erzeugter Block:**
```ruby
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: "smtp.gmail.com",
  port: 587,
  domain: "carambus.de",
  user_name: ENV["SMTP_USERNAME"],
  password: ENV["SMTP_PASSWORD"],
  authentication: "plain",
  enable_starttls_auto: true,
  open_timeout: 5,
  read_timeout: 5
}
config.action_mailer.perform_deliveries = true
config.action_mailer.raise_delivery_errors = true
config.action_mailer.default_options = { from: ENV["SMTP_USERNAME"] || "no-reply@carambus.de" }
```

## Zugangsdaten einrichten

### Weg über das Scenario Management

Puma läuft als systemd-Dienst `puma-<basename>` und liest die Zugangsdaten **ausschließlich** aus
`/etc/<basename>.env` (`EnvironmentFile=` in `templates/puma/puma.service.erb`). Eine `.bashrc` oder
`.profile` erreicht den Dienst nicht.

1. Zugangsdaten in `carambus_data/secrets.yml` eintragen (nicht versioniert):
   ```yaml
   shared:
     smtp:
       username: "...@gmail.com"
       password: "..."          # Gmail: App-Passwort, nicht das Kontopasswort
   # oder nur für ein Szenario:
   per_scenario:
     <szenario>:
       smtp:
         username: "..."
         password: "..."
   ```
2. Vom Admin-Rechner aus einem carambus-Checkout:
   ```bash
   bin/rails "scenario:prepare_deploy[<szenario>]"
   ```
   `prepare_deploy` legt `/etc/<basename>.env` an (Modus 600, Eigentümer root), sofern die Datei fehlt.
   Ohne SMTP-Daten und ohne `smtp_enabled: false` bricht der Task mit einer Anleitung ab.

Die systemd-Unit `puma-<basename>.service` selbst **nicht editieren**: `prepare_deploy` schreibt sie bei
jedem Lauf neu.

### Zugangsdaten ändern

Eine vorhandene `/etc/<basename>.env` überschreibt `prepare_deploy` nie. Zum Ändern auf dem Server:

```bash
sudo nano /etc/<basename>.env
sudo systemctl restart puma-<basename>
```

### Server ohne echtes SMTP: `SKIP_SMTP_GUARD`

In Production prüft `config/initializers/smtp_guard.rb` beim Server-/Sidekiq-Boot, ob
`SMTP_USERNAME` und `SMTP_PASSWORD` gesetzt sind, und bricht den Start sonst bewusst ab
(Fail-Fast, damit Devise-Mails nicht still scheitern). Interne bzw. Scenario-Server, die
**kein echtes SMTP** brauchen (z. B. `carambus_gu`), setzen stattdessen das Opt-out-Flag —
sauberer als Dummy-SMTP-Zugangsdaten zu hinterlegen.

Der Weg dafür ist die `config.yml` des Szenarios:

```yaml
environments:
  production:
    smtp_enabled: false
```

`prepare_deploy` schreibt dann `SKIP_SMTP_GUARD=1` in `/etc/<basename>.env`. Existiert die Datei schon,
die Zeile dort von Hand ergänzen und `puma-<basename>` neu starten.

Ist `SKIP_SMTP_GUARD` gesetzt, wird der Guard übersprungen und der Server bootet ohne
SMTP-Zugangsdaten. **Ohne** das Flag bleibt der Fail-Fast-Schutz unverändert aktiv — auf
echten Mail-versendenden Servern also weglassen.

## Gmail App-Passwort erstellen

**Wichtig:** Verwende kein normales Gmail-Passwort, sondern ein App-Passwort!

### Voraussetzung: 2-Faktor-Authentifizierung

Gmail App-Passwörter erfordern aktivierte 2-Faktor-Authentifizierung:

1. Gehe zu: https://myaccount.google.com/security
2. Klicke auf "Bestätigung in zwei Schritten"
3. Folge den Anweisungen zur Aktivierung

### App-Passwort erstellen

1. Gehe zu: https://myaccount.google.com/apppasswords
   - Oder: Google-Konto → Sicherheit → Bestätigung in zwei Schritten → App-Passwörter
2. App auswählen: "Mail"
3. Gerät auswählen: "Anderes (benutzerdefinierter Name)" → "Carambus" eingeben
4. Klicke auf "Generieren"
5. **Kopiere das 16-stellige Passwort** (ohne Leerzeichen!)
   - Angezeigt: `abcd efgh ijkl mnop`
   - Verwenden: `abcdefghijklmnop`
6. Als `password` unter `smtp` in `secrets.yml` eintragen

## Testen

### Manueller Test in Rails Console

Die Konsole läuft nicht unter systemd und kennt `SMTP_USERNAME`/`SMTP_PASSWORD` daher nicht. Die Werte für
die Sitzung aus der (nur für root lesbaren) Datei übernehmen:

```bash
ssh -p 8910 www-data@<server>
cd /var/www/<basename>/current
set -a; eval "$(sudo cat /etc/<basename>.env)"; set +a
RAILS_ENV=production bin/rails console

# Test E-Mail senden
ActionMailer::Base.mail(
  from: ENV['SMTP_USERNAME'],
  to: ENV['SMTP_USERNAME'],
  subject: 'Test E-Mail',
  body: 'Dies ist ein Test'
).deliver_now
```

### Benutzerregistrierung testen

1. Öffne die Registrierungsseite
2. Erstelle einen neuen Benutzer
3. Prüfe die Logs auf Fehler:
   ```bash
   tail -f /var/www/<basename>/shared/log/production.log
   ```

## Fehlersuche

### Puma startet nicht, nginx meldet 502

**Symptom:** Im Journal `FATAL: SMTP-ENV nicht gesetzt`.

```bash
sudo journalctl -u puma-<basename> -n 40 --no-pager
```

**Lösung:** `/etc/<basename>.env` fehlt oder ist unvollständig. SMTP-Daten in `secrets.yml` eintragen und
`prepare_deploy` erneut ausführen (legt die Datei an, wenn sie fehlt), oder die Datei von Hand ergänzen und
`puma-<basename>` neu starten.

### Timeout-Fehler

**Symptom:**
```
Net::ReadTimeout (Net::ReadTimeout with #<TCPSocket:(closed)>)
```

**Ursachen:**
- SMTP-Server nicht erreichbar
- Firewall blockiert Port 587
- Falsche SMTP-Credentials

**Lösung:**
```bash
# Test SMTP-Verbindung
telnet smtp.gmail.com 587

# Prüfe, ob die Zugangsdaten gesetzt sind (Werte nicht in Tickets kopieren)
sudo cat /etc/<basename>.env

# Prüfe Logs
tail -100 /var/www/<basename>/shared/log/production.log
```

### Authentifizierungsfehler

**Symptom:**
```
Net::SMTPAuthenticationError
```

**Lösung:**
- Verwende ein Gmail App-Passwort (16 Zeichen, keine Leerzeichen)
- Prüfe, ob Username korrekt ist (vollständige E-Mail-Adresse)
- Stelle sicher, dass 2-Faktor-Authentifizierung aktiviert ist
- Erstelle ein neues App-Passwort, falls unsicher

### Port blockiert

**Symptom:**
```
Errno::ECONNREFUSED (Connection refused)
```

**Lösung:**
```bash
# Teste die Verbindung zu Port 587
nc -vz smtp.gmail.com 587
```

Port 465 (SSL) oder 25 (unverschlüsselt, nicht empfohlen) wären eine Änderung am generierten Block, also
am Generator in `lib/tasks/scenarios.rake`.

## Alternative: Sendmail reparieren (nicht empfohlen)

Falls du trotzdem Sendmail verwenden möchtest:

```bash
# Postfix installieren
sudo apt-get install postfix

# Postfix als Internet Site konfigurieren
sudo dpkg-reconfigure postfix

# Service starten
sudo systemctl enable postfix
sudo systemctl start postfix

# Test
echo "Test" | mail -s "Test Subject" gernot.ullrich@gmx.de
```

**Problem:** Viele ISPs blockieren Port 25, sodass ausgehende E-Mails nicht funktionieren.

## Sicherheitshinweise

1. **Niemals Passwörter in Git committen**: Zugangsdaten stehen nur in `carambus_data/secrets.yml` (nicht
   versioniert) und auf dem Server in `/etc/<basename>.env` (Modus 600)
2. Nutze App-Passwörter statt normaler Passwörter
3. `enable_starttls_auto: true` steht im generierten Block

## Deployment

Änderungen am SMTP-Block gehören in den Generator, nicht in eine Datei unter `config/environments/`:

```bash
# In einem beliebigen aktuellen carambus-Checkout
# lib/tasks/scenarios.rake (generate_production_rb_env) anpassen, dann
git add lib/tasks/scenarios.rake
git commit -m "..."
git pull --rebase origin master && git push origin master

# Konfiguration neu erzeugen und ausrollen (vom Admin-Rechner)
bin/rails "scenario:prepare_deploy[<szenario>]"
bin/rails "scenario:deploy[<szenario>]"
```

Auf dem Server ist `current` ein entpacktes Release ohne Git; dort kein `git pull`. Nur für eine geänderte
`/etc/<basename>.env` genügt auf dem Server `sudo systemctl restart puma-<basename>`.

## Siehe auch

- [Deployment Workflow](../developers/deployment-workflow.md)
- [Server Architektur](server-architecture.md)
- [Scenario Management](../developers/scenario-management.md)
- [Raspberry Pi Quickstart, Abschnitt 3.1](raspberry-pi-quickstart.md)
