# Email-Konfiguration (SMTP/Gmail)

**Zielgruppe:** Entwickler, Systemadministratoren  
**Status:** Produktiv  
**Letzte Aktualisierung:** Februar 2026

## Übersicht

Diese Anleitung beschreibt die Konfiguration von Email-Versand über SMTP (Gmail) für Carambus. Dies ist notwendig für:
- Benutzer-Registrierung (Bestätigungsemails)
- Passwort-Reset
- Benachrichtigungen
- Turnier-Einladungen

## Hintergrund

**Problem (ursprünglich):**  
User-Registrierung schlug fehl mit `Net::ReadTimeout` nach ~5 Sekunden beim Versuch, Bestätigungsemails über sendmail/postfix zu versenden.

**Root Cause:**
- Postfix-Service auf Raspberry Pi war nicht korrekt konfiguriert
- Systemd-Service zeigte "active (exited)", führte aber nur `/bin/true` aus
- Email-Delivery-Timeouts blockierten die Benutzer-Registrierung

**Lösung:**  
Umstellung von `sendmail` auf **SMTP (Gmail)** für zuverlässigen Email-Versand.

## Konfiguration

### 1. Production Environment Files

Die SMTP-Konfiguration ist in den Production-Environment-Files definiert:

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

**Wichtig:** Credentials werden über Umgebungsvariablen geladen, **niemals** hardcoded!

### 2. Gmail App Password erstellen

**Voraussetzung:** Gmail-Account mit aktivierter 2-Faktor-Authentifizierung

#### Schritt 1: 2-Faktor-Authentifizierung aktivieren

Falls noch nicht aktiviert:
1. Gehe zu: https://myaccount.google.com/security
2. Klicke auf "2-Step Verification"
3. Folge dem Setup-Assistenten (Telefon-Verifizierung erforderlich)

#### Schritt 2: App-Passwort generieren

1. Gehe zu: https://myaccount.google.com/apppasswords
2. Wähle App: "Mail"
3. Wähle Gerät: "Other (Custom name)" → Gib "Carambus" ein
4. Klicke "Generate"
5. **Kopiere das 16-stellige Passwort sofort!** (wird nur einmal angezeigt)

**Beispiel:**
```
Angezeigt: abcd efgh ijkl mnop
Verwenden: abcdefghijklmnop  (ohne Leerzeichen!)
```

### 3. Production Server konfigurieren

#### Für Development (lokal)

Normalerweise nicht nötig, da Development meist keine echten Emails versendet.

Falls doch benötigt:
```bash
# In ~/.bashrc oder ~/.zshrc
export SMTP_USERNAME="your-email@gmail.com"
export SMTP_PASSWORD="your-16-char-app-password"

# Reload
source ~/.bashrc
```

#### Für Production Server (z.B. carambus_bcw)

**SSH zum Server:**
```bash
ssh www-data@<server-ip> -p <port>
```

**Option A: Umgebungsvariablen in .bashrc**
```bash
# Editiere .bashrc
nano ~/.bashrc

# Füge am Ende hinzu:
export SMTP_USERNAME="your-email@gmail.com"
export SMTP_PASSWORD="abcdefghijklmnop"

# Speichern: Ctrl+X, Y, Enter

# Reload
source ~/.bashrc

# Verifizieren
echo $SMTP_USERNAME
echo $SMTP_PASSWORD
```

**Option B: Systemd Service (empfohlen für Production)**
```bash
# Editiere Service-Datei
sudo nano /etc/systemd/system/carambus_bcw.service

# Füge in [Service]-Sektion hinzu:
Environment="SMTP_USERNAME=your-email@gmail.com"
Environment="SMTP_PASSWORD=abcdefghijklmnop"

# Speichern und Service neu laden
sudo systemctl daemon-reload
sudo systemctl restart carambus_bcw

# Status prüfen
sudo systemctl status carambus_bcw
```

**Empfehlung:** Beide Optionen verwenden für maximale Kompatibilität.

## Testing

### Test 1: Rails Console

```bash
cd ~/carambus_bcw/current
RAILS_ENV=production bundle exec rails console

# Test-Email senden
ActionMailer::Base.mail(
  from: ENV['SMTP_USERNAME'],
  to: ENV['SMTP_USERNAME'],
  subject: 'Carambus SMTP Test',
  body: 'Falls du diese Email erhältst, funktioniert SMTP!'
).deliver_now

# Sollte ohne Fehler durchlaufen
# Prüfe deinen Gmail-Posteingang
exit
```

### Test 2: Benutzer-Registrierung

1. Browser öffnen: `https://your-carambus-domain.de`
2. Zur Registrierungsseite navigieren
3. Test-Benutzer anlegen
4. Sollte ohne Timeout abschließen
5. Bestätigungsmail prüfen

### Test 3: Logs überwachen

```bash
tail -f ~/carambus_bcw/current/log/production.log | grep -i mail
```

Bei erfolgreicher Email:
```
Sent mail to test@example.com (123ms)
```

Bei Fehlern:
```
Net::SMTPAuthenticationError: 535-5.7.8 Username and Password not accepted
```

## Troubleshooting

### Fehler: "Invalid credentials" (535-5.7.8)

```ruby
Net::SMTPAuthenticationError: 535-5.7.8 Username and Password not accepted
```

**Lösungen:**
- ✅ 2-Faktor-Authentifizierung ist aktiviert?
- ✅ App-Passwort verwenden, NICHT reguläres Passwort
- ✅ Leerzeichen aus App-Passwort entfernen
- ✅ Neues App-Passwort generieren
- ✅ `SMTP_USERNAME` ist vollständige Email-Adresse?

### Fehler: "Connection refused"

```ruby
Errno::ECONNREFUSED: Connection refused - connect(2) for "smtp.gmail.com" port 587
```

**Lösungen:**
- Firewall erlaubt ausgehenden Port 587?
- Alternative: Port 465 (SSL) versuchen:
  ```ruby
  config.action_mailer.smtp_settings = {
    address: 'smtp.gmail.com',
    port: 465,
    # ... rest der config
  }
  ```

### Fehler: "Timeout"

```ruby
Net::ReadTimeout: Net::ReadTimeout
```

**Lösungen:**
- Internet-Verbindung prüfen
- DNS auflöst `smtp.gmail.com`?
  ```bash
  nslookup smtp.gmail.com
  ```
- Timeout-Werte erhöhen bei langsamer Verbindung:
  ```ruby
  open_timeout: 10,
  read_timeout: 10
  ```

### Umgebungsvariablen nicht gesetzt

```bash
# Prüfen ob Variablen gesetzt sind
echo $SMTP_USERNAME
echo $SMTP_PASSWORD

# Falls leer: Environment neu laden
source ~/.bashrc

# Systemd-Service prüfen
sudo systemctl show carambus_bcw -p Environment
```

## Sicherheits-Best-Practices

### ✅ DO's

- ✅ Umgebungsvariablen für Credentials verwenden
- ✅ App-Passwörter verwenden (nicht Account-Passwort)
- ✅ TLS-Verschlüsselung aktivieren (port 587)
- ✅ App-Passwörter regelmäßig rotieren
- ✅ Verschiedene App-Passwörter für verschiedene Anwendungen

### ❌ DON'Ts

- ❌ Credentials niemals in Config-Dateien hardcoden
- ❌ Credentials niemals in Git committen
- ❌ App-Passwörter nicht teilen
- ❌ Reguläres Gmail-Passwort nicht in Anwendungen verwenden
- ❌ Unverschlüsseltes SMTP (Port 25) verwenden

## Alternative: Andere SMTP-Provider

Falls Gmail nicht gewünscht ist, funktioniert die gleiche Konfiguration auch mit:

### GMX
```ruby
address: 'mail.gmx.net',
port: 587,
domain: 'gmx.net'
```

### SendGrid
```ruby
address: 'smtp.sendgrid.net',
port: 587,
user_name: 'apikey',
password: ENV['SENDGRID_API_KEY']
```

### Amazon SES
```ruby
address: 'email-smtp.eu-west-1.amazonaws.com',
port: 587,
user_name: ENV['AWS_SMTP_USERNAME'],
password: ENV['AWS_SMTP_PASSWORD']
```

## Deployment-Checkliste

Für jeden neuen Production-Server:

- [ ] Gmail App-Passwort erstellt
- [ ] `SMTP_USERNAME` in ~/.bashrc gesetzt
- [ ] `SMTP_PASSWORD` in ~/.bashrc gesetzt
- [ ] Environment-Variablen in systemd Service gesetzt
- [ ] Service neu gestartet
- [ ] Test-Email von Rails Console erfolgreich
- [ ] Benutzer-Registrierung getestet
- [ ] Bestätigungsmail empfangen
- [ ] Logs überwacht (keine Fehler)

## Technische Details

### Email-Flow

1. User registriert → `RegistrationsController#create`
2. Devise erstellt User mit `:confirmable`
3. Devise triggert Bestätigungsmail via ActionMailer
4. ActionMailer nutzt SMTP-Settings für Verbindung zu smtp.gmail.com:587
5. Email wird über TLS-verschlüsselte Verbindung versendet
6. User erhält Bestätigungsmail

### Timeout-Settings

```ruby
open_timeout: 5   # Max 5 Sekunden für Verbindungsaufbau
read_timeout: 5   # Max 5 Sekunden für Response
enable_starttls_auto: true  # TLS-Verschlüsselung
```

### Betroffene Files

- `app/models/user.rb` - User-Model mit `:confirmable`
- `config/initializers/devise.rb` - Devise-Konfiguration
- `app/mailers/application_mailer.rb` - Base Mailer-Klasse
- `app/controllers/registrations_controller.rb` - Benutzer-Registrierung

## Rollback-Plan

Falls SMTP-Probleme auftreten:

**Option 1: Email-Versand temporär deaktivieren**
```ruby
# In config/environments/production-*.rb
config.action_mailer.perform_deliveries = false
```

**Option 2: Zurück zu sendmail (nicht empfohlen)**
```ruby
config.action_mailer.delivery_method = :sendmail
```

## Siehe auch

- [Deployment-Workflow](../deployment-workflow.de.md)
- [Administrator Email-Konfiguration](../../administrators/email-configuration.de.md)
- [Rails ActionMailer Docs](https://guides.rubyonrails.org/action_mailer_basics.html)
- [Devise Configuration](https://github.com/heartcombo/devise)

## Historie

- **Februar 2026:** Dokumentation konsolidiert aus mehreren Quellen
- **Januar 2026:** Migration von sendmail zu Gmail SMTP
- **Problem:** User-Registrierung Timeout mit sendmail/postfix
- **Lösung:** SMTP-Konfiguration mit Gmail App-Passwörtern
