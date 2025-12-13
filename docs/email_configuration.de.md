# E-Mail-Konfiguration

## Übersicht

Carambus verwendet E-Mail für:
- Benutzerregistrierung (Bestätigungs-E-Mails)
- Passwort-Zurücksetzen
- Account-Einladungen
- Benachrichtigungen

## Produktionsumgebung - SMTP-Konfiguration

### Problem mit Sendmail

Die ursprüngliche Konfiguration verwendete `sendmail`, was auf Raspberry Pi Servern oft zu Timeouts führt, da:
- Sendmail/Postfix nicht korrekt konfiguriert ist
- Der Service nicht richtig läuft
- Timeouts die Benutzerregistrierung blockieren

### Lösung: SMTP (Gmail)

Die Produktionsumgebungen sind jetzt auf SMTP umgestellt:

**Dateien:**
- `config/environments/production-bc-wedel.rb`
- `config/environments/production-carambus-de.rb`

**Konfiguration:**
```ruby
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: 'smtp.gmail.com',
  port: 587,
  domain: 'bc-wedel.de',  # oder 'carambus.de'
  user_name: ENV['SMTP_USERNAME'],
  password: ENV['SMTP_PASSWORD'],
  authentication: 'plain',
  enable_starttls_auto: true,
  open_timeout: 5,
  read_timeout: 5
}
```

## Umgebungsvariablen einrichten

### Auf dem Produktionsserver

SSH zum Server und setze die Umgebungsvariablen:

```bash
# Als www-data User
sudo -u www-data -i

# Umgebungsvariablen in .bashrc oder .profile setzen
echo 'export SMTP_USERNAME="deine-email@gmail.com"' >> ~/.bashrc
echo 'export SMTP_PASSWORD="dein-app-passwort"' >> ~/.bashrc

# Neu laden
source ~/.bashrc
```

### Für Systemd Service

Wenn Puma als Systemd Service läuft, müssen die Variablen in der Service-Datei gesetzt werden:

```bash
sudo nano /etc/systemd/system/carambus_bcw.service
```

Füge unter `[Service]` hinzu:
```ini
Environment="SMTP_USERNAME=deine-email@gmail.com"
Environment="SMTP_PASSWORD=dein-app-passwort"
```

Service neu laden:
```bash
sudo systemctl daemon-reload
sudo systemctl restart carambus_bcw
```

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
6. Als `SMTP_PASSWORD` verwenden

## Testen

### Manueller Test in Rails Console

```bash
cd ~/carambus_bcw/current
RAILS_ENV=production bundle exec rails console

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
   tail -f ~/carambus_bcw/current/log/production.log
   ```

## Fehlersuche

### Timeout-Fehler

**Symptom:**
```
Net::ReadTimeout (Net::ReadTimeout with #<TCPSocket:(closed)>)
```

**Ursachen:**
- SMTP-Server nicht erreichbar
- Firewall blockiert Port 587
- Falsche SMTP-Credentials
- `SMTP_PASSWORD` Umgebungsvariable nicht gesetzt

**Lösung:**
```bash
# Test SMTP-Verbindung
telnet smtp.gmail.com 587

# Prüfe Umgebungsvariablen
echo $SMTP_PASSWORD

# Prüfe Logs
tail -100 ~/carambus_bcw/current/log/production.log
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
# Teste Port 587
sudo netstat -tuln | grep 587

# Teste alternative Ports
# Port 465 (SSL): config.action_mailer.smtp_settings[:port] = 465
# Port 25 (unverschlüsselt, nicht empfohlen)
```

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

1. **Niemals Passwörter in Git committen**
2. Verwende immer Umgebungsvariablen für Credentials
3. Nutze App-Passwörter statt normaler Passwörter
4. Setze `enable_starttls_auto: true` für verschlüsselte Verbindungen

## Deployment

Nach Änderungen an den Environment-Dateien:

```bash
# In carambus_master
git add config/environments/production-*.rb
git commit -m "Switch from sendmail to SMTP for email delivery"
git push

# Auf dem Produktionsserver
cd ~/carambus_bcw/current
git pull
sudo systemctl restart carambus_bcw
```

## Siehe auch

- [Deployment Workflow](deployment_workflow.de.md)
- [Server Architektur](server_architektur.de.md)
- [Scenario Management](scenario_management.de.md)

