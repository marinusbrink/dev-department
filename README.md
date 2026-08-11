# dev-department

This repository **is** the software development department: a team of AI agents that takes product backlog items from idea to production, running entirely on GitHub Actions and Anthropic cloud infrastructure — nothing on the founder's own machine. Everything that defines the department — agent roles, workflows, conventions, templates, lessons learned — is a file in this repo: versioned, reviewable, with history.

Products (first [ryd](https://github.com/marinusbrink/ryd), later opentms-next) live in their own repositories and consume this department via reusable GitHub Actions workflows and a sync of `agents/` and `conventions/` on every run. An improvement here is immediately active in every product.

The authoritative design for everything in this repo:
**[docs/design/software-development-department.md](docs/design/software-development-department.md)**

## The three human roles

Everything else is done by agents. Marinus keeps exactly three roles:

1. **PBI author** — writes product backlog items as GitHub issues; the intake agent judges whether they can be built first-time-right.
2. **Two gates** — gate 1: approving the design doc PR before any code is written; gate 2: reviewing the feature PR before merge. Agents technically cannot merge or deploy to production.
3. **Rulebook curator** — approving proposed changes to conventions and lessons; the retrospective agent proposes, the human decides.

## Repository layout

| Path | Contents |
|---|---|
| `agents/` | Agent definitions (markdown + frontmatter): intake, architect, implementers, test engineer, reviewer, release manager, devops, retrospective, documentation |
| `workflows/` | Reusable GitHub Actions workflows the product repos call |
| `conventions/` | CLAUDE.md building blocks: SaaS constitution, architecture, code, test, security, performance budgets |
| `templates/` | PBI template, design doc template, retrospective template |
| `lessons/` | Curated lessons learned — see [lessons/README.md](lessons/README.md) |
| `docs/design/` | The department design document |
| `docs/runbooks/` | Operational runbooks (digest, kill switch, incident handling) |
| `docs/onboarding/` | How to onboard a new product repo (domain map requirement) |

## Guardrails in one breath

Branch protection keeps merging human; secrets are scoped per workflow; a monthly budget cap bounds cost (ceiling: TODO(choice-5)); the repository variable `AGENTS_ENABLED=false` is the kill switch; and a daily 07:00 digest reports what ran, what failed, and what waits on a human (channel: TODO(choice-1) — mail, Slack, or GitHub-only).

Open design decisions are tracked as `TODO(choice-N)` markers throughout this repo, referencing the numbered **Open choices for review** at the end of the design doc.
