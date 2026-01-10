# YouTube Streaming - Entwicklungs-Setup

## Übersicht

Für die Entwicklung und das Testen des Streaming-Systems kann ein einzelner Raspberry Pi verwendet werden, der sowohl das Scoreboard als auch das Streaming simuliert.

## Besonderheiten im Entwicklungsnetzwerk

Im Gegensatz zum normalen Betrieb in Clubs (wo jeder Tisch einen eigenen Raspberry Pi hat):

- **Einzelner Raspberry Pi**: Ein Raspi simuliert mehrere Tisch-Scoreboards
- **Desktop-User**: Der Raspberry Pi läuft mit Desktop unter dem User `pi`
- **SSH-User**: SSH-Zugriff erfolgt passwortlos über den User `www-data`
- **Custom Port**: SSH läuft auf einem nicht-Standard Port (z.B. 8910)
- **Key-basierte Authentifizierung**: Keine Passwort-Authentifizierung

## Voraussetzungen

### 1. SSH-Key auf dem Raspberry Pi einrichten

Auf dem Raspberry Pi (als `www-data` User):

```bash
# Als root oder mit sudo
sudo -u www-data mkdir -p /var/www/.ssh
sudo -u www-data chmod 700 /var/www/.ssh

# Public Key vom Entwicklungsrechner kopieren
# (Ersetze mit deinem tatsächlichen Public Key)
sudo -u www-data sh -c 'cat >> /var/www/.ssh/authorized_keys' << 'EOF'
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC... your-public-key-here
EOF

sudo -u www-data chmod 600 /var/www/.ssh/authorized_keys
```

### 2. SSH auf Custom Port konfigurieren

In `/etc/ssh/sshd_config`:

```
Port 8910
```

SSH-Service neu starten:

```bash
sudo systemctl restart sshd
```

### 3. Testen der SSH-Verbindung

Vom Entwicklungsrechner:

```bash
ssh -p 8910 www-data@192.168.1.50
```

Wenn die Verbindung ohne Passwort-Eingabe funktioniert, ist die Einrichtung erfolgreich.

## Streaming-Setup ausführen

### Umgebungsvariablen setzen

Für alle Streaming-Rake-Tasks:

```bash
export RASPI_SSH_USER=www-data
export RASPI_SSH_PORT=8910
```

Optional: Expliziter SSH-Key (normalerweise nicht nötig):

```bash
export RASPI_SSH_KEYS=~/.ssh/id_rsa
```

### Setup ausführen

```bash
# Mit Umgebungsvariablen
RASPI_SSH_USER=www-data RASPI_SSH_PORT=8910 \
  rake streaming:setup[192.168.1.50]
```

### Test ausführen

```bash
RASPI_SSH_USER=www-data RASPI_SSH_PORT=8910 \
  rake streaming:test[192.168.1.50]
```

### Konfiguration deployen

Nach dem Erstellen einer Stream-Konfiguration in der Admin-Oberfläche:

```bash
# Stelle sicher, dass in der StreamConfiguration:
# - raspi_ip: 192.168.1.50
# - raspi_ssh_port: 8910

RASPI_SSH_USER=www-data RASPI_SSH_PORT=8910 \
  rake streaming:deploy[TABLE_ID]
```

## Bash-Alias für einfachere Verwendung

In `~/.bashrc` oder `~/.zshrc`:

```bash
# Carambus Streaming Development
alias rstream='RASPI_SSH_USER=www-data RASPI_SSH_PORT=8910'

# Verwendung:
# rstream rake streaming:setup[192.168.1.50]
# rstream rake streaming:test[192.168.1.50]
# rstream rake streaming:deploy[1]
```

## Stream-Konfiguration erstellen

1. In der Admin-Oberfläche: `/admin/stream_configurations/new`
2. Wichtige Einstellungen für Development:
   - **Table**: Wähle Tisch aus
   - **Raspi IP**: `192.168.1.50` (oder deine Dev-Raspi IP)
   - **Raspi SSH Port**: `8910`
   - **YouTube Stream Key**: Dein Test-Stream-Key von YouTube
   - **Camera Device**: `/dev/video0`

## Troubleshooting

### SSH Connection Refused

```
❌ Connection refused: 192.168.1.50:8910
```

**Lösung**: Überprüfe, ob SSH auf Port 8910 läuft:

```bash
# Auf dem Raspberry Pi
sudo netstat -tlnp | grep 8910
```

### Permission Denied (publickey)

```
❌ SSH authentication failed
```

**Lösungen**:
1. Überprüfe, ob der Public Key korrekt in `/var/www/.ssh/authorized_keys` steht
2. Überprüfe Berechtigungen: `chmod 700 /var/www/.ssh && chmod 600 /var/www/.ssh/authorized_keys`
3. Überprüfe Ownership: `chown -R www-data:www-data /var/www/.ssh`
4. Teste manuell: `ssh -v -p 8910 www-data@192.168.1.50` (verbose output)

### Sudo-Rechte für www-data

Wenn `www-data` keine sudo-Rechte hat, in `/etc/sudoers.d/www-data`:

```
www-data ALL=(ALL) NOPASSWD: /bin/systemctl start carambus-stream@*
www-data ALL=(ALL) NOPASSWD: /bin/systemctl stop carambus-stream@*
www-data ALL=(ALL) NOPASSWD: /bin/systemctl status carambus-stream@*
www-data ALL=(ALL) NOPASSWD: /bin/systemctl restart carambus-stream@*
www-data ALL=(ALL) NOPASSWD: /usr/bin/apt-get
www-data ALL=(ALL) NOPASSWD: /bin/mkdir
www-data ALL=(ALL) NOPASSWD: /bin/chown
www-data ALL=(ALL) NOPASSWD: /bin/chmod
www-data ALL=(ALL) NOPASSWD: /bin/mv
```

Berechtigungen setzen:

```bash
sudo chmod 440 /etc/sudoers.d/www-data
```

## Unterschiede zum Produktionsbetrieb

| Aspekt | Development | Produktion (Club) |
|--------|-------------|-------------------|
| Raspberry Pis | 1 für alle Tische | 1 pro Tisch |
| SSH User | `www-data` | `pi` |
| SSH Port | 8910 (custom) | 22 (standard) |
| SSH Auth | Key-basiert | Passwort |
| Desktop User | `pi` | `pi` |

## Nächste Schritte

Nach erfolgreichem Setup:

1. Stream-Konfiguration in Admin-Oberfläche erstellen
2. Konfiguration deployen: `rstream rake streaming:deploy[TABLE_ID]`
3. Stream starten über Admin-Oberfläche
4. Logs überwachen: `ssh -p 8910 www-data@192.168.1.50 'journalctl -u carambus-stream@1 -f'`

## Siehe auch

- [Streaming Setup (Administrator)](../administrators/streaming-setup.de.md)
- [Streaming Architektur (Entwickler)](./streaming-architecture.de.md)
- [Streaming Quickstart (Administrator)](../administrators/streaming-quickstart.de.md)



