---
phase: 31
slug: new-documentation
status: verified
threats_open: 0
asvs_level: 1
created: 2026-04-13
---

# Phase 31 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Source code -> docs/ | Service/model source files read to write documentation | Class names, method signatures, constants (public, no secrets) |
| docs/ files | New markdown documentation created in docs/developers/services/ | Public architecture documentation |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-31-01 | Information Disclosure | docs/developers/services/*.md | accept | Public interface documentation only; no secrets. Service files already in repo. | closed |
| T-31-02 | Information Disclosure | docs/developers/services/*.md | accept | Public interface documentation only; no credentials or internal secrets | closed |
| T-31-03 | Information Disclosure | video-crossref.*.md | accept | Public interface only; AI model name (gpt-4o-mini) not sensitive; no API keys | closed |

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-31-01 | T-31-01 | Namespace docs expose only public class names and method signatures already visible in the repo | Claude (plan-phase) | 2026-04-13 |
| AR-31-02 | T-31-02 | Same as AR-31-01 for League/PartyMonitor/Umb namespace pages | Claude (plan-phase) | 2026-04-13 |
| AR-31-03 | T-31-03 | Video cross-ref docs expose confidence threshold (0.75) and model name (gpt-4o-mini) — neither is sensitive | Claude (plan-phase) | 2026-04-13 |

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-04-13 | 3 | 3 | 0 | gsd-secure-phase orchestrator |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-04-13
