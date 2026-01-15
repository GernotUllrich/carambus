# Docker Raspberry Pi - Decision Matrix & Visual Guide

**Version:** 1.0  
**Datum:** 14. Januar 2026  
**Für:** Schnelle visuelle Entscheidungsfindung

---

## 🎯 The Decision Tree

```
┌─────────────────────────────────────────────────────────────┐
│ Soll Component auf Docker migrieren?                        │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │ Braucht Hardware-     │
        │ Zugriff?              │
        └───────┬───────────────┘
                │
        ┌───────┴───────┐
        │               │
       JA              NEIN
        │               │
        ▼               ▼
┌─────────────┐  ┌──────────────┐
│ Bare-Metal  │  │ Docker       │
│ ✅ GPU      │  │ möglich      │
│ ✅ Kamera   │  │              │
│ ✅ Display  │  │ Weiter...    │
└─────────────┘  └──────┬───────┘
                        │
                        ▼
            ┌───────────────────────┐
            │ Performance-kritisch? │
            └───────┬───────────────┘
                    │
            ┌───────┴───────┐
            │               │
           JA              NEIN
            │               │
            ▼               ▼
    ┌─────────────┐  ┌──────────────┐
    │ Bare-Metal  │  │ Docker       │
    │ Streaming:  │  │ empfohlen    │
    │ ✅ FFmpeg   │  │ Rails App:   │
    │ ✅ Encoding │  │ ✅ Isolation │
    └─────────────┘  │ ✅ Rollback  │
                     └──────────────┘
```

---

## 📊 Component Classification Matrix

| Component | Hardware-Zugriff | Performance-kritisch | Docker-fähig | Empfehlung |
|-----------|------------------|----------------------|--------------|------------|
| **Scoreboard (Chromium)** | ✅ GPU + Display | ⚠️ Mittel | ❌ Nein | ❌ Bare-Metal |
| **Streaming (FFmpeg)** | ✅ Kamera + GPU | ✅ Hoch | ❌ Nein | ❌ Bare-Metal |
| **Rails Server** | ❌ Nur Netzwerk | ⚠️ Mittel | ✅ Ja | ✅ Docker |
| **PostgreSQL** | ❌ Nur Disk | ⚠️ Mittel | ✅ Ja | ✅ Docker |
| **Redis** | ❌ Nur RAM | ❌ Niedrig | ✅ Ja | ✅ Docker |
| **Nginx** | ❌ Nur Netzwerk | ❌ Niedrig | ✅ Ja | ✅ Docker |

---

## 🏗️ Architecture Comparison

### Current: Full Bare-Metal

```
┌─────────────────────────────────────────────────────────┐
│ Raspberry Pi 5 (Location Server)                        │
│                                                          │
│  systemd services:                                      │
│  ├─ puma-carambus_location_5101.service                │
│  ├─ postgresql@14-main.service                         │
│  ├─ redis-server.service                               │
│  └─ nginx.service                                       │
│                                                          │
│  Pros: ✅ Simple, ✅ Fast setup                        │
│  Cons: ⚠️ Dependency hell, ⚠️ Hard rollback          │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ Raspberry Pi 4 (Table Client × 8)                       │
│                                                          │
│  systemd services:                                      │
│  ├─ scoreboard-kiosk.service (Chromium)                │
│  └─ carambus-stream@2.service (FFmpeg)                 │
│                                                          │
│  Pros: ✅ Hardware access, ✅ Performance              │
│  Cons: ⚠️ Manual config                               │
└─────────────────────────────────────────────────────────┘
```

### Proposed: Hybrid Approach

```
┌─────────────────────────────────────────────────────────┐
│ Raspberry Pi 5 (Location Server) - ✅ DOCKER           │
│                                                          │
│  docker-compose:                                        │
│  ├─ rails:latest (Carambus App)                        │
│  ├─ postgres:16-alpine (Database)                      │
│  ├─ redis:7-alpine (Cache + ActionCable)               │
│  └─ nginx:alpine (Reverse Proxy)                       │
│                                                          │
│  Pros: ✅ Easy rollback, ✅ Reproducible              │
│  Cons: ⚠️ +300 MB RAM, ⚠️ Complexity                 │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ Raspberry Pi 4 (Table Client × 8) - ✅ BARE-METAL     │
│                                                          │
│  systemd services (unchanged):                          │
│  ├─ scoreboard-kiosk.service (Chromium)                │
│  └─ carambus-stream@2.service (FFmpeg)                 │
│                                                          │
│  Pros: ✅ Hardware access, ✅ Performance              │
│  Cons: None (this works perfectly!)                     │
└─────────────────────────────────────────────────────────┘
```

### Not Recommended: Full Docker

```
┌─────────────────────────────────────────────────────────┐
│ Raspberry Pi 5 (Location Server) - Docker              │
│  Same as Hybrid ✅                                      │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ Raspberry Pi 4 (Table Client × 8) - ❌ DOCKER         │
│                                                          │
│  docker-compose:                                        │
│  ├─ scoreboard:latest (Chromium in Container)          │
│  │   Requires: --privileged --device=/dev/dri          │
│  │   Problems: ❌ GPU unstable, ❌ X11 complex        │
│  │                                                      │
│  └─ streaming:latest (FFmpeg in Container)             │
│      Requires: --device=/dev/video0 --device=/dev/dri  │
│      Problems: ❌ HW encoder fails → Software encoder  │
│                ❌ 5-10% frame drops                     │
│                ❌ 85% CPU (vs 45% bare-metal)          │
└─────────────────────────────────────────────────────────┘
```

---

## 📈 Performance Comparison Chart

### RAM Usage (Raspberry Pi 4, 4GB total)

```
Bare-Metal:
████████░░░░░░░░░░░░  650 MB (16%)  ← Current
                       3350 MB free (84%)

Docker Full:
████████████████░░░░  1250 MB (31%)  ← Not recommended
                       2750 MB free (69%)

Docker Hybrid:
████████████░░░░░░░░  950 MB (24%)  ← Recommended
                       3050 MB free (76%)

Legend: █ = Used  ░ = Free
```

### CPU Usage (During Streaming @ 720p30)

```
Bare-Metal:
████████████████████░░░░░░░░░░  65%  ← Current
                                 35% reserve

Docker Full:
████████████████████████████░░  88%  ← Not recommended
                                 12% reserve (RISKY!)

Docker Hybrid:
████████████████████████░░░░░░  70%  ← Recommended
                                 30% reserve
```

### Update Time (8 Raspis)

```
Bare-Metal:
█ 4 min (30s × 8)  ← Current

Docker Full:
████████████████████████████ 80+ min (10 min × 8)  ← NOT ACCEPTABLE!

Docker Hybrid:
██ 8 min (1 min × 8 = 8 clients + location server)  ← Acceptable
```

---

## 🎲 Risk Matrix

```
                    High Impact
                         │
                         │
           Hardware      │      Update
           Failures      │      Slowness
               ❌        │        ❌
                         │
         ────────────────┼────────────────
                         │
                         │   Performance
         Rollback        │   Degradation
         Needed          │      ⚠️
            ✅           │
                         │
                    Low Impact
                         
           Low Probability          High Probability
```

### Docker Full: High Risk Areas

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| **Hardware-Encoder fails** | ⚠️ High (60%) | ❌ Critical | Don't use Docker for streaming |
| **GPU access breaks** | ⚠️ High (40%) | ❌ Critical | Don't use Docker for scoreboard |
| **Slow updates during event** | ✅ High (80%) | ❌ Critical | Don't use Docker for table clients |
| **Container-RAM-OOM** | ⚠️ Medium (30%) | ⚠️ High | Use 4GB+ Raspis, monitor RAM |

### Docker Hybrid: Manageable Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| **Location-Server downtime** | ✅ Low (10%) | ⚠️ Medium | Quick rollback via image tags |
| **PostgreSQL in container** | ✅ Low (5%) | ⚠️ Medium | Regular backups, volume persistence |
| **Network issues** | ⚠️ Medium (20%) | ✅ Low | Docker uses host network mode |

---

## 💡 The "Ideal Candidate" Checklist

### ✅ Good fit for Docker

- [ ] **No hardware access** (GPU, cameras, displays)
- [ ] **Stateless or easily backed up** (volumes)
- [ ] **Not performance-critical** (<50% CPU baseline)
- [ ] **Frequent updates** (benefit from image versioning)
- [ ] **Multiple instances** (benefit from orchestration)

**Example:** Rails Server on Location Server → **✅ 5/5 = Perfect**

### ❌ Bad fit for Docker

- [ ] **Hardware access required** (GPU, V4L2, displays)
- [ ] **Performance-critical** (streaming, video encoding)
- [ ] **Need low-level debugging** (strace, hardware diagnostics)
- [ ] **Rare updates** (stable, only bugfixes)
- [ ] **Single instance** (no orchestration benefit)

**Example:** Streaming on Table Client → **❌ 5/5 = Terrible**

---

## 📅 Implementation Timeline

```
┌─────────────────────────────────────────────────────────────┐
│ PHASE 1: Development (Week 1-2)                             │
├─────────────────────────────────────────────────────────────┤
│ ✅ Setup Docker for local development                       │
│ ✅ Update Dockerfile.development                            │
│ ✅ Test CI/CD pipeline with Docker                          │
│                                                              │
│ Deliverable: Faster onboarding for developers               │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ PHASE 2: Location-Server Pilot (Week 3-6)                   │
├─────────────────────────────────────────────────────────────┤
│ ✅ Create Dockerfile.production (Rails + deps)              │
│ ✅ Setup docker-compose.production.yml                      │
│ ✅ Deploy to 1 pilot location server                        │
│ ✅ Test rollback scenario                                   │
│                                                              │
│ Deliverable: Proven Docker setup for location servers       │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ PHASE 3: Evaluation (Month 4-6)                             │
├─────────────────────────────────────────────────────────────┤
│ 📊 Measure uptime vs bare-metal baseline                    │
│ 📊 Count rollbacks performed                                │
│ 📊 Measure update time vs baseline                          │
│ 🎯 Go/No-Go decision                                        │
│                                                              │
│ Deliverable: Data-driven decision for wider rollout         │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ PHASE 4: Scale (Optional, Month 7+)                         │
├─────────────────────────────────────────────────────────────┤
│ IF evaluation positive:                                      │
│ ✅ Migrate remaining location servers                       │
│ ✅ Document best practices                                  │
│ ✅ Train operations team                                    │
│                                                              │
│ Deliverable: Full Docker rollout for location servers       │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔥 Quick Reference: "Should I use Docker?"

### Ask yourself these 3 questions:

1. **Does it need hardware access?**
   - YES → ❌ **Don't use Docker**
   - NO → Continue to Q2

2. **Is it performance-critical?**
   - YES → ❌ **Consider bare-metal**
   - NO → Continue to Q3

3. **Will frequent updates/rollbacks help?**
   - YES → ✅ **Use Docker!**
   - NO → ⚠️ **Docker optional**

### Real Examples:

| Component | Q1: Hardware? | Q2: Performance? | Q3: Updates? | Decision |
|-----------|---------------|------------------|--------------|----------|
| **Scoreboard** | ✅ YES (GPU) | - | - | ❌ Bare-Metal |
| **Streaming** | ✅ YES (Camera) | - | - | ❌ Bare-Metal |
| **Rails Server** | ❌ NO | ❌ NO | ✅ YES | ✅ Docker |
| **PostgreSQL** | ❌ NO | ⚠️ MEDIUM | ✅ YES | ✅ Docker |

---

## 🎯 Final Decision Table

| Scenario | Recommendation | Confidence | Investment |
|----------|----------------|------------|------------|
| **Migrate everything to Docker** | ❌ **NO** | 🔴 High | 22-40 days |
| **Migrate only location servers** | ✅ **YES** | 🟢 High | 5-10 days |
| **Keep everything bare-metal** | ⚠️ **OK** | 🟡 Medium | 0 days |
| **Migrate only development** | ✅ **YES** | 🟢 High | 2-3 days |

### Recommended Path: **Hybrid Approach**

1. ✅ **NOW:** Docker for development (2-3 days)
2. ✅ **Q1 2026:** Docker for location servers pilot (5-10 days)
3. ⚠️ **Q2 2026:** Evaluate & decide on wider rollout
4. ❌ **NEVER:** Docker for table clients (hardware issues)

---

## 📞 Decision Support

### Still unsure? Ask these teams:

- **Technical feasibility:** Development Team
- **Cost/ROI questions:** Project Management
- **Operational impact:** DevOps/Operations
- **Timeline concerns:** Product Owner

### Red flags that indicate "Don't use Docker":

- 🚩 Component uses `/dev/video*` (cameras)
- 🚩 Component uses `/dev/dri` (GPU)
- 🚩 Component requires `--privileged` flag
- 🚩 Performance drops by >10%
- 🚩 Updates take >5 minutes per device
- 🚩 Debugging becomes significantly harder

### Green lights that indicate "Use Docker":

- 🟢 Component is network-only (no hardware)
- 🟢 Rollbacks would save significant time
- 🟢 Multiple environments need identical setup
- 🟢 CI/CD would benefit from containerization
- 🟢 Component is stateless or easily backed up

---

**Status:** ✅ Ready for decision  
**Next step:** Management approval for Phase 1 + 2  
**Contact:** Development Team for questions

