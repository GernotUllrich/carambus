# Docker für Raspberry Pi - Executive Summary
## Entscheidungsvorlage für Management

**Version:** 1.0  
**Datum:** 14. Januar 2026  
**Status:** Empfehlung  
**Vollständige Studie:** [DOCKER_RASPI_FEASIBILITY_STUDY.de.md](DOCKER_RASPI_FEASIBILITY_STUDY.de.md)

---

## 🎯 Zusammenfassung in 60 Sekunden

### Fragestellung
Soll das stabile Bare-Metal-Deployment von Scoreboard & Streaming auf Raspberry Pi durch Docker-Container ersetzt werden?

### Antwort: NEIN für Table-Clients, JA für Location-Server

| Komponente | Aktuell | Empfehlung | Begründung |
|------------|---------|------------|------------|
| **Location Server (Raspi 5)** | Bare-Metal Rails | ✅ **Docker** | Einfacheres Deployment, kein Hardware-Zugriff nötig |
| **Table Clients (Raspi 4)** | Bare-Metal Scoreboard + Streaming | ✅ **Bare-Metal beibehalten** | Hardware-Zugriff kritisch, Docker zu komplex |

### Investment
- **Entwicklungsaufwand:** 5-15 Tage (Hybrid-Ansatz) statt 22-40 Tage (Full-Docker)
- **Laufende Kosten:** +€60-240/Jahr (Container-Registry) + 1-2h/Monat extra Maintenance
- **ROI:** Positiv nach 2-3 Jahren (nur bei Hybrid-Ansatz)

---

## 📊 Vergleichstabelle: Die Fakten

### Performance-Impact

| Metrik | Bare-Metal | Docker Full | Hybrid |
|--------|------------|-------------|--------|
| **Setup-Zeit pro Raspi** | 5 Min | 15-25 Min ❌ | 5-10 Min ✅ |
| **Update-Zeit** | 30 Sek | 5-15 Min ❌ | 30 Sek - 2 Min ✅ |
| **RAM-Verbrauch** | 650 MB | 1250 MB (+92%) ❌ | 650-950 MB ⚠️ |
| **CPU-Last (Streaming)** | 65% | 88% ❌ | 65-70% ✅ |
| **Streaming-Qualität** | Hardware-Encoder | Software-Encoder (5-10% Frame-Drops) ❌ | Hardware-Encoder ✅ |

### Operational-Impact

| Aspekt | Bare-Metal | Docker Full | Hybrid |
|--------|------------|-------------|--------|
| **Debugging-Komplexität** | Niedrig ✅ | Hoch ❌ | Niedrig-Mittel ⚠️ |
| **Hardware-Diagnostics** | Direkt ✅ | Eingeschränkt ❌ | Direkt (Client) ✅ |
| **Rollback bei Fehler** | Manuell (git) ⚠️ | Image-Tags ✅ | Hybrid ⚠️ |
| **Reproduzierbarkeit** | Gut ⚠️ | Exzellent ✅ | Exzellent (Server) ✅ |

---

## 🚦 Kritische Probleme mit Full-Docker

### 1. Hardware-Zugriff (❌ Blocker)

**Scoreboard:**
- ❌ GPU-Zugriff instabil (Chromium Hardware-Acceleration)
- ❌ X11-Display-Zugriff erfordert `--privileged` (Sicherheitsrisiko)
- ❌ Fullscreen-Modus funktioniert nicht zuverlässig

**Streaming:**
- ❌ Hardware-Encoder (h264_v4l2m2m) nicht stabil in Container
- ❌ Fallback zu Software-Encoding: 5-10% Frame-Drops + 85% CPU-Last
- ❌ Unbrauchbar für Live-Streaming

### 2. Update-Geschwindigkeit (❌ Kritisch)

**Aktuell (Bare-Metal):**
```bash
ssh pi@raspi 'git pull && sudo systemctl restart scoreboard'
# Dauer: 30 Sekunden
# Downtime: 5 Sekunden
```

**Mit Docker:**
```bash
docker pull ghcr.io/user/scoreboard:latest  # 1.5 GB Download!
docker-compose restart
# Dauer: 5-15 Minuten (Netzwerk-abhängig)
# Downtime: 30 Sekunden
```

**Impact:** Bei 8 Tischen vor Ort = 40-120 Minuten für Full-Update statt 4 Minuten!

### 3. Resource-Overhead (⚠️ Signifikant)

**Raspberry Pi 4 (4GB RAM):**
- Bare-Metal: 650 MB → 3350 MB verfügbar (84% frei)
- Docker: 1250 MB → 2750 MB verfügbar (69% frei)
- **Verlust:** 600 MB RAM (18% weniger verfügbar)

**Raspberry Pi 4 (2GB RAM):**
- Docker würde **nicht empfohlen** sein (zu wenig RAM)

---

## ✅ Empfohlener Hybrid-Ansatz

### Architektur

```
┌───────────────────────────────────────────────────────┐
│ Location Server (Raspberry Pi 5)                      │
│                                                        │
│ ✅ Docker-Compose:                                    │
│   ├─ Rails App (Carambus)                            │
│   ├─ PostgreSQL                                       │
│   ├─ Redis (ActionCable + Cache)                     │
│   └─ Nginx (Reverse Proxy)                           │
│                                                        │
│ Vorteile:                                             │
│ • Reproduzierbare Umgebung                           │
│ • Einfaches Rollback (Image-Tags)                    │
│ • Kein Hardware-Zugriff nötig                        │
│ • Isolierte Services                                 │
└───────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────┐
│ Table Clients (Raspberry Pi 4) × 4-8                  │
│                                                        │
│ ✅ Bare-Metal (unverändert):                         │
│   ├─ Scoreboard (Chromium Kiosk)                     │
│   └─ Streaming (FFmpeg + Hardware-Encoder)           │
│                                                        │
│ Vorteile:                                             │
│ • Direkter Hardware-Zugriff (GPU, Kamera)            │
│ • Maximale Performance                               │
│ • Schnelle Updates (30 Sekunden)                     │
│ • Einfaches Debugging                                │
└───────────────────────────────────────────────────────┘
```

### Implementierungsplan

#### Phase 1: Development (2-3 Tage) - SOFORT
```bash
# Ziel: Entwickler-Onboarding vereinfachen
1. Dockerfile.development optimieren
2. docker-compose.yml für lokale Entwicklung
3. CI/CD-Pipeline mit Docker-Tests

Nutzen:
✅ Neue Entwickler: Setup in 10 Min statt 2 Stunden
✅ Identische Umgebung für alle Entwickler
✅ Automatische Tests in CI/CD
```

#### Phase 2: Location-Server Pilot (5-10 Tage) - Q1 2026
```bash
# Ziel: Docker auf 1-2 Location-Servern testen
1. Dockerfile.production für Rails + Dependencies
2. docker-compose.production.yml (Rails + PostgreSQL + Redis + Nginx)
3. Deployment-Scripts anpassen
4. Testing auf Pilot-Server
5. Dokumentation

Nutzen:
✅ Einfacheres Deployment (docker-compose pull && up -d)
✅ Rollback in 30 Sekunden (Image-Tags)
✅ Reproduzierbare Umgebung
```

#### Phase 3: Evaluation (Q2 2026)
```bash
# Nach 3-6 Monaten Betrieb
1. Stabilität bewerten
2. Anzahl Rollbacks zählen
3. Zeit-Ersparnis messen
4. Entscheidung: Weitere Migration oder Rollback
```

---

## 💰 Kosten-Nutzen-Rechnung

### Investition

| Position | Aufwand | Kosten (€) |
|----------|---------|------------|
| **Phase 1: Development** | 2-3 Tage | 1.600-2.400 |
| **Phase 2: Location-Server** | 5-10 Tage | 4.000-8.000 |
| **Testing & Debugging** | 3-5 Tage | 2.400-4.000 |
| **Dokumentation** | 1-2 Tage | 800-1.600 |
| **Gesamt** | **11-20 Tage** | **8.800-16.000** |

*Annahme: 800€/Tag (intern oder extern)*

### Laufende Kosten

| Position | Kosten/Jahr |
|----------|-------------|
| **Container-Registry** | 60-240 € |
| **Extra Maintenance** | 1.600-2.400 € (2-3h/Monat × 800€/Tag) |
| **Gesamt** | **1.660-2.640 €** |

### Einsparungen (nach Stabilisierung)

| Position | Ersparnis/Jahr |
|----------|----------------|
| **Schnellere Rollbacks** | 800-1.600 € (1-2 Tage/Jahr gespart) |
| **Reproduzierbare Builds** | 1.600-3.200 € (Debugging-Zeit) |
| **Einfacheres Testing** | 800-1.600 € (QA-Zeit) |
| **Gesamt** | **3.200-6.400 €** |

### ROI-Timeline

```
Jahr 1: -8.800 bis -16.000 € (Investition)
Jahr 2: -1.660 +3.200 = +1.540 € (Break-Even!)
Jahr 3: -1.660 +4.800 = +3.140 €
Jahr 4: -1.660 +6.400 = +4.740 €

✅ Break-Even: Nach 2-3 Jahren
✅ ROI: Positiv bei Hybrid-Ansatz
```

---

## 🎯 Management-Entscheidung

### ✅ EMPFOHLEN: Hybrid-Ansatz implementieren

**Begründung:**
1. ✅ **Risiko minimiert:** Table-Clients bleiben auf bewährtem Bare-Metal-System
2. ✅ **Mehrwert realisiert:** Location-Server profitiert von Docker-Vorteilen
3. ✅ **Investition überschaubar:** 11-20 Tage statt 22-40 Tage
4. ✅ **ROI positiv:** Break-Even nach 2-3 Jahren
5. ✅ **Schrittweise Migration:** Pilot → Evaluation → Scale

### ❌ NICHT EMPFOHLEN: Full-Docker-Migration

**Begründung:**
1. ❌ **Hardware-Probleme:** GPU, Display, Hardware-Encoder instabil
2. ❌ **Performance-Verlust:** +92% RAM, 5-10% Frame-Drops
3. ❌ **Update-Chaos:** 40-120 Min statt 4 Min für 8 Tische
4. ❌ **ROI negativ:** Break-Even erst nach 4-16 Jahren
5. ❌ **Debugging schwieriger:** Container-Isolation erschwert Troubleshooting

---

## 📋 Nächste Schritte (bei Freigabe)

### Woche 1-2: Development-Setup
```bash
1. Dockerfile.development optimieren
2. Docker-Compose für lokales Development
3. CI/CD-Pipeline einrichten
4. Entwickler-Onboarding

Verantwortlich: Development Team
Review: Sprint-Review
```

### Woche 3-6: Location-Server Pilot
```bash
1. Dockerfile.production erstellen
2. docker-compose.production.yml mit PostgreSQL + Redis
3. Deployment-Scripts anpassen
4. Testing auf Pilot-Server (z.B. carambus_bcw)

Verantwortlich: DevOps + Lead Developer
Review: Nach Testing-Phase
```

### Monat 4-6: Evaluation
```bash
1. Stabilität bewerten
2. Metriken sammeln (Uptime, Rollbacks, Performance)
3. Go/No-Go Entscheidung für weitere Migration

Verantwortlich: Product Owner + DevOps
Review: Quartals-Review Q2 2026
```

---

## ❓ FAQ für Management

### Warum nicht Full-Docker wie andere moderne Projekte?

**Antwort:** Andere Projekte haben keinen **Hardware-Zugriff** wie wir:
- Unsere Raspis steuern **physische Displays** (GPU-Zugriff)
- Unsere Raspis verarbeiten **USB-Kameras** (V4L2-Zugriff)
- Unsere Raspis nutzen **Hardware-Encoder** (VideoCore-GPU)

Docker-Container sind für **Cloud-Native-Apps** designed, nicht für **Hardware-nahe Embedded-Systems**.

### Warum behalten unsere Konkurrenten Bare-Metal für ähnliche Use-Cases?

**Beispiele:**
- **Digital Signage (Chromium-Kiosk):** Meist Bare-Metal wegen Display-Zugriff
- **Video-Streaming (FFmpeg):** Meist Bare-Metal wegen Hardware-Encoder
- **Raspberry Pi Industrial:** Bare-Metal Standard für Hardware-I/O

**Einzige Ausnahme:** Server-only-Apps (keine Hardware) → Docker sinnvoll

### Was ist mit Kubernetes für Scale-Out?

**Antwort:** Kubernetes ist für **horizontal skalierbare Web-Apps** designed:
- 10-1000 identische Pods (Load-Balancing)
- Stateless Services
- Cloud-basiert

Unser Use-Case:
- 1 Raspi = 1 physischer Tisch (nicht skalierbar)
- Stateful (USB-Kamera, Display)
- Edge-basiert (Raspberry Pi vor Ort)

**Kubernetes wäre Overkill** und würde zusätzliche Komplexität ohne Mehrwert bringen.

### Was ist mit Podman statt Docker?

**Antwort:** Podman hat **gleiche Probleme** wie Docker:
- Hardware-Zugriff: Gleich kompliziert
- Performance-Overhead: Gleich hoch
- Debugging: Gleich schwierig

**Einziger Vorteil:** Rootless Container (Sicherheit)  
**Aber:** Bei Raspberry Pi vor Ort weniger relevant als in Cloud

### Können wir später zu Full-Docker migrieren wenn Hardware-Probleme gelöst sind?

**Antwort:** ✅ JA! Der Hybrid-Ansatz ist **nicht final**:
- Wenn Docker-Hardware-Support besser wird (neue Kernel, neue Docker-Features)
- Wenn wir zu anderen Kameras/Displays wechseln (Docker-kompatibel)
- Können wir schrittweise Table-Clients auf Docker migrieren

Der Hybrid-Ansatz ist **future-proof** und **risikominimiert**.

---

## 🔗 Weitere Informationen

- **Vollständige Studie:** [DOCKER_RASPI_FEASIBILITY_STUDY.de.md](DOCKER_RASPI_FEASIBILITY_STUDY.de.md)
- **Technische Architektur:** [docs/developers/streaming-architecture.de.md](../developers/streaming-architecture.de.md)
- **Deployment-Workflow:** [docs/developers/deployment-workflow.de.md](../developers/deployment-workflow.de.md)
- **Scenario-Management:** [docs/developers/scenario-management.de.md](../developers/scenario-management.de.md)

---

**Kontakt für Rückfragen:**
- **Technische Details:** Development Team
- **Kosten/ROI:** Project Management
- **Deployment-Plan:** DevOps Team

**Status:** ✅ **Bereit für Management-Entscheidung**  
**Empfohlene Action:** ✅ **Freigabe für Hybrid-Ansatz (Phase 1 + 2)**

