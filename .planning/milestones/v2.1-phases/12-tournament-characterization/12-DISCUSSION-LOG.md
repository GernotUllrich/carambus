# Phase 12: Tournament Characterization - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-10
**Phase:** 12-tournament-characterization
**Areas discussed:** Test scope strategy, Scraping VCR approach, Test organization, PaperTrail baselines

---

## Test Scope Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| All clusters (Recommended) | AASM, scraping, dynamic attributes, PaperTrail, calendar, rankings | ✓ |
| Core only | AASM + scraping + attributes + PaperTrail — skip calendar/rankings | |
| Extraction targets only | Only scraping + calendar | |

**User's choice:** All clusters — comprehensive before extraction.

---

## Scraping VCR Approach

### Cassette Source
| Option | Description | Selected |
|--------|-------------|----------|
| Record from real URLs | Use real ClubCloud tournament URLs for VCR cassettes | ✓ |
| Synthetic HTML fixtures | Create static HTML fixtures | |
| Skip scraping tests | Defer to Phase 14 extraction | |

### URL Discovery
| Option | Description | Selected |
|--------|-------------|----------|
| User provides during execution | User gives specific URLs | |
| Claude finds them | Discover from codebase/existing cassettes | ✓ |
| Use existing cassettes | Reuse v1.0 RegionCc cassettes | |

---

## Test Organization

| Option | Description | Selected |
|--------|-------------|----------|
| Split by concern (Recommended) | Separate files per concern area | ✓ |
| Single file | One tournament_char_test.rb | |
| Extend existing | Add to tournament_test.rb | |

---

## PaperTrail Baselines

| Option | Description | Selected |
|--------|-------------|----------|
| All state changes (Recommended) | Create, AASM transitions, attribute updates, destroy | ✓ |
| AASM transitions only | Only state transitions | |
| You decide | Claude picks based on extraction risk | |

---

## Claude's Discretion

- Test method grouping within concern files
- AASM transition prioritization
- Scraping variant coverage selection
- Shared TournamentTestHelper creation
- Calendar/rankings file organization
