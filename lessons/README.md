# Lessons learned

This folder is the department's curated memory (design §9): short rules that prevent a mistake from happening twice. It is deliberately small — the bar for adding a rule is **"which mistake happens again without this rule?"** Most PRs yield no lesson, and that is the intent.

## Format

**One rule per file** (or, for a themed collection, one rule per bullet within a file). Every rule carries three mandatory fields:

- **Date** — when the rule was added.
- **Cause** — a link to the PR (and review comments) that triggered it.
- **Scope** — `department-wide` or `product-specific`. Department-wide lessons live here and become part of every agent's context via the conventions sync. Product-specific lessons belong in that product repo's CLAUDE.md, not here — if a proposal lands here with product-specific scope, it should be moved during review.

File naming: `YYYY-MM-DD-short-slug.md`.

```markdown
---
date: 2026-08-11
cause: https://github.com/marinusbrink/ryd/pull/123
scope: department-wide
---

The rule itself: one short, imperative sentence that a reviewer can check
mechanically. Optionally one or two sentences of context — no essays.
```

## Lifecycle

1. The **retrospective agent** analyzes each completed PR (diff between agent output and merged result, plus review comments) and — only on a repeatable pattern — opens a **proposal PR** to this folder or to `conventions/`.
2. The rulebook curator (human) approves or rejects. Agents never change lessons or conventions directly.
3. **Quarterly pruning**: a scheduled run proposes removal of rules that were not relevant in any review for 3 months. A rulebook only works if it stays short.
