# Conventions

CLAUDE.md building blocks for the whole department. Product repos do not copy these files — their workflows sync `conventions/` fresh on every agent run, so an approved change here is immediately active in every product.

## How they bind

- **[saas-constitution.md](saas-constitution.md)** is embedded in **every** agent prompt, without exception (design §4.0). An agent that must deviate marks it with the `DEVIATION(constitution-N)` format defined there, so the deviation is visible at a gate.
- **[coding-conventions.md](coding-conventions.md)** binds the implementers and is the reviewer's checklist source.
- **[performance-budgets.md](performance-budgets.md)** binds architect (state affected budgets per design), test engineer (test against them), reviewer (block on violations), and release manager (error budget gate).

## How they change

Only via reviewed PRs — never by an agent editing directly:

1. The **retrospective agent** opens a proposal PR when a completed feature shows a repeatable mistake (bar: "which mistake happens again without this rule?").
2. The **rulebook curator** (human) edits directly or approves proposals. Merge requires human review; that is the whole change process.

Rules that stop earning their keep are pruned quarterly via the lessons mechanism (design §9). A short rulebook that is actually applied beats an exhaustive one that is skimmed.
