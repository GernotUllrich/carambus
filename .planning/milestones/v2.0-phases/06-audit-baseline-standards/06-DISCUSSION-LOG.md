# Phase 6: Audit Baseline & Standards - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-10
**Phase:** 06-audit-baseline-standards
**Areas discussed:** Audit approach, Fixtures vs factories, Assertion style, Audit output format

---

## Audit Approach

| Option | Description | Selected |
|--------|-------------|----------|
| Automated scan first | Run grep/analysis scripts to categorize issues, then manual review of flagged files | ✓ |
| Manual read-through | Read every file sequentially, document issues as found | |
| Hybrid by directory | Quick automated scan per directory, then deep-dive on worst offenders | |

**User's choice:** Automated scan first
**Notes:** Comprehensive scan scope selected — check skips, assertion counts, empty tests, naming, setup patterns, unused helpers, test-to-code mapping.

---

## Fixtures vs Factories

| Option | Description | Selected |
|--------|-------------|----------|
| Fixtures primary | Keep fixtures as the standard, use Model.create! for complex setups | ✓ |
| Migrate to FactoryBot | Gradually replace fixtures with factories | |
| Allow both explicitly | Document when to use each approach | |

**User's choice:** Fixtures primary
**Notes:** No additional follow-up needed.

---

## Assertion Style

| Option | Description | Selected |
|--------|-------------|----------|
| test "description" blocks | More readable, Rails default | ✓ |
| def test_method_name | Classic MiniTest style | |
| Allow both | Don't enforce naming | |

**User's choice:** test "description" blocks

| Option | Description | Selected |
|--------|-------------|----------|
| Keep shoulda-matchers | Useful for concise tests, don't mandate but keep available | ✓ |
| Remove it | Pure MiniTest only | |
| You decide | Claude evaluates during audit | |

**User's choice:** Keep shoulda-matchers available
**Notes:** No additional follow-up needed.

---

## Audit Output Format

| Option | Description | Selected |
|--------|-------------|----------|
| Per-file issue list | Markdown listing every file with categorized issues | ✓ |
| Categorized by issue type | Group all issues of same type together | |
| Both views | Per-file detail + summary by issue type | |

**User's choice:** Per-file issue list
**Notes:** This becomes the work queue for Phases 7-9.

---

## Claude's Discretion

- Exact automated scan scripts and approach
- Issue severity categorization
- Summary statistics inclusion
- Characterization test handling

## Deferred Ideas

None — discussion stayed within phase scope.
