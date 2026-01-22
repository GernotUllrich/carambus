# SSH-Setup für Streaming (Passwortlos)

## Übersicht

Die Streaming-Rake-Tasks benötigen SSH-Zugriff vom **Local Server** (192.168.2.210) zu den **Raspberry Pi Scoreboards** (z.B. 192.168.2.217). Für eine reibungslose Nutzung sollte dies **ohne Passwort** funktionieren.

## Warum passwortlos?

- Rake-Tasks können nicht interaktiv Passwörter eingeben
- Automatisierte Stream-Steuerung funktioniert nur mit Key-basierter Authentifizierung
- Sicherer als Passwort-Authentifizierung

## Schnellstart

### 1. SSH-Verbindung testen

```bash
# Auf dem Local Server (192.168.2.210)
cd /path/to/carambus_bcw
rake 'streaming:ssh_test[3]'
```

Dies zeigt:
- ✅ Ob SSH-Keys auf dem Local Server vorhanden sind
- ✅ Ob die Verbindung funktioniert
- ✅ Ob der Public Key bereits auf dem Raspberry Pi eingetragen ist
- 📋 Anleitung zum Einrichten, falls noch nicht geschehen

### 2. Public Key auf Raspberry Pi hinzufügen

Falls der Test zeigt, dass der Key noch nicht eingetragen ist:

**Option A: Automatisch (wenn SSH mit Passwort funktioniert):**

```bash
# Auf dem Local Server
ssh-copy-id pi@192.168.2.217
```

**Option B: Manuell:**

1. **Public Key anzeigen:**
   ```bash
   # Auf dem Local Server
   cat ~/.ssh/id_rsa.pub
   # oder
   cat ~/.ssh/id_ed25519.pub
   ```

2. **Auf dem Raspberry Pi:**
   ```bash
   ssh pi@192.168.2.217
   mkdir -p ~/.ssh
   chmod 700 ~/.ssh
   nano ~/.ssh/authorized_keys
   # Public Key einfügen (eine Zeile)
   chmod 600 ~/.ssh/authorized_keys
   ```

3. **Testen:**
   ```bash
   # Vom Local Server aus
   ssh pi@192.168.2.217 "echo 'SSH works!'"
   ```

## Detaillierte Anleitung

### Schritt 1: SSH-Keys auf Local Server prüfen

```bash
# Auf dem Local Server (192.168.2.210)
ls -la ~/.ssh/
```

Sie sollten mindestens eines dieser Dateien sehen:
- `id_rsa` / `id_rsa.pub`
- `id_ed25519` / `id_ed25519.pub`
- `id_ecdsa` / `id_ecdsa.pub`

### Schritt 2: SSH-Keys generieren (falls nicht vorhanden)

```bash
# Auf dem Local Server
ssh-keygen -t ed25519 -C "local-server@carambus"
# Oder für RSA:
ssh-keygen -t rsa -b 4096 -C "local-server@carambus"
```

**Wichtig:** Drücken Sie Enter, um den Standard-Speicherort zu verwenden (`~/.ssh/id_ed25519`).

### Schritt 3: Public Key auf Raspberry Pi kopieren

**Für Table 3 (Tisch 7, IP: 192.168.2.217):**

```bash
# Auf dem Local Server
ssh-copy-id pi@192.168.2.217
```

Falls `ssh-copy-id` nicht verfügbar ist, manuell:

```bash
# 1. Public Key anzeigen
cat ~/.ssh/id_ed25519.pub

# 2. Auf Raspberry Pi einfügen
ssh pi@192.168.2.217
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "PASTE_PUBLIC_KEY_HERE" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
exit
```

### Schritt 4: Verbindung testen

```bash
# Auf dem Local Server
rake 'streaming:ssh_test[3]'
```

Oder manuell:

```bash
ssh pi@192.168.2.217 "echo 'SSH works without password!'"
```

Wenn keine Passwort-Abfrage erscheint, funktioniert es! ✅

## Für mehrere Raspberry Pis

Wenn Sie mehrere Scoreboards haben, wiederholen Sie Schritt 3 für jeden:

```bash
# Für jeden Raspberry Pi
ssh-copy-id pi@192.168.2.217  # Tisch 7
ssh-copy-id pi@192.168.2.218  # Tisch 8
ssh-copy-id pi@192.168.2.219  # Tisch 9
# etc.
```

## Troubleshooting

### Problem: "Permission denied (publickey)"

**Ursache:** Public Key ist nicht in `authorized_keys` eingetragen.

**Lösung:**
1. Prüfen Sie, ob der Key eingetragen ist:
   ```bash
   ssh pi@192.168.2.217 "cat ~/.ssh/authorized_keys"
   ```
2. Falls nicht, fügen Sie ihn hinzu (siehe Schritt 3)

### Problem: "Host key verification failed"

**Ursache:** SSH kennt den Host noch nicht.

**Lösung:**
```bash
ssh-keyscan -H 192.168.2.217 >> ~/.ssh/known_hosts
```

### Problem: "Connection refused"

**Ursache:** SSH-Service läuft nicht auf dem Raspberry Pi.

**Lösung:**
```bash
# Auf dem Raspberry Pi
sudo systemctl status ssh
sudo systemctl enable ssh
sudo systemctl start ssh
```

### Problem: "No SSH keys found"

**Ursache:** Keine SSH-Keys auf dem Local Server.

**Lösung:**
```bash
# Auf dem Local Server
ssh-keygen -t ed25519 -C "local-server@carambus"
```

## Automatisierung

Sie können ein Script erstellen, das alle Raspberry Pis automatisch einrichtet:

```bash
#!/bin/bash
# setup-ssh-keys.sh

LOCAL_SERVER_USER=$(whoami)
RASPI_USER="pi"
RASPI_IPS=(
  "192.168.2.217"  # Tisch 7
  "192.168.2.218"  # Tisch 8
  # ... weitere IPs
)

# Prüfe SSH-Key
if [ ! -f ~/.ssh/id_ed25519.pub ]; then
  echo "Generating SSH key..."
  ssh-keygen -t ed25519 -C "local-server@carambus" -f ~/.ssh/id_ed25519 -N ""
fi

# Kopiere Key zu jedem Raspberry Pi
for ip in "${RASPI_IPS[@]}"; do
  echo "Setting up SSH for $ip..."
  ssh-copy-id -i ~/.ssh/id_ed25519.pub ${RASPI_USER}@${ip}
done

echo "✅ SSH setup complete!"
```

## Sicherheit

### Best Practices

1. **Verwenden Sie ed25519 Keys** (moderner und sicherer als RSA)
2. **Schützen Sie private Keys:**
   ```bash
   chmod 600 ~/.ssh/id_ed25519
   chmod 644 ~/.ssh/id_ed25519.pub
   ```
3. **Deaktivieren Sie Passwort-Authentifizierung** (optional, nach Key-Setup):
   ```bash
   # Auf dem Raspberry Pi: /etc/ssh/sshd_config
   PasswordAuthentication no
   PubkeyAuthentication yes
   ```
4. **Verwenden Sie SSH-Agent** für zusätzliche Sicherheit

### Key-Rotation

Falls ein Key kompromittiert wurde:

```bash
# 1. Neuen Key generieren
ssh-keygen -t ed25519 -C "local-server@carambus-v2"

# 2. Alten Key aus authorized_keys entfernen
# Auf jedem Raspberry Pi:
ssh pi@192.168.2.217
nano ~/.ssh/authorized_keys
# Alte Key-Zeile löschen

# 3. Neuen Key hinzufügen
ssh-copy-id -i ~/.ssh/id_ed25519.pub pi@192.168.2.217
```

## Prüfen für Table 3 (Tisch 7)

```bash
# Auf dem Local Server
cd /path/to/carambus_bcw
rake 'streaming:ssh_test[3]'
```

Dies zeigt:
- ✅ Ob SSH funktioniert
- ✅ Ob der Key eingetragen ist
- 📋 Anleitung, falls etwas fehlt

## Weitere Informationen

- [SSH Key Management](https://www.ssh.com/academy/ssh/key)
- [Streaming Architecture](../developers/streaming-architecture.de.md)
- [Where to Run Rake Tasks](./where-to-run-rake-tasks.md)

