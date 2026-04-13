---
phase: 29
slug: break-fix
status: verified
threats_open: 0
asvs_level: 1
created: 2026-04-13
---

# Phase 29 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| bin/ scripts -> docs/ files | Scripts read and modify documentation files on disk | Markdown text (public, no secrets) |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-29-01 | T (Tampering) | bin/fix-docs-links.rb | accept | Script is local tooling run by developer; no untrusted input. Regex patterns are hardcoded. | closed |
| T-29-02 | I (Info Disclosure) | docs/ files | accept | Documentation is public; no secrets in doc files. | closed |
| T-29-03 | T (Tampering) | docs/ content edits | accept | Documentation is version-controlled; all changes are committed and reviewable via git diff. No executable code is modified. | closed |
| T-29-04 | I (Info Disclosure) | docs/ content | accept | Documentation is public-facing; no credentials or secrets in doc files. | closed |

*Status: open · closed*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-29-01 | T-29-01 | Local dev tooling with hardcoded regex; no attack surface | Claude (plan-phase) | 2026-04-13 |
| AR-29-02 | T-29-02 | All documentation is public-facing; no secrets to disclose | Claude (plan-phase) | 2026-04-13 |
| AR-29-03 | T-29-03 | Git version control provides full audit trail of all doc changes | Claude (plan-phase) | 2026-04-13 |
| AR-29-04 | T-29-04 | Public documentation with no credential exposure | Claude (plan-phase) | 2026-04-13 |

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-04-13 | 4 | 4 | 0 | gsd-secure-phase orchestrator |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-04-13
