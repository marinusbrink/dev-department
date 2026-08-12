# Runbook: incident — an agent misbehaves

For when an agent does something wrong: loops, produces damaging PRs, posts nonsense at scale, deviates unmarked, or touches what it shouldn't. Work top to bottom; steps 1–2 before diagnosis — stop first, understand second.

## 1. Stop the department

Kill switch, per [kill-switch.md](kill-switch.md):

```bash
gh variable set AGENTS_ENABLED --body false --repo marinusbrink/ryd
```

Cancel in-flight runs (same runbook). One misbehaving agent stops the whole department — that is intentional: agents share conventions and workflows, so a systematic fault is rarely contained to one role.

## 2. Assess the blast radius

Agents cannot merge, cannot push to main, cannot deploy (branch protection, §8). The possible damage surface is therefore:

- **branches and draft/open PRs** they created,
- **comments and labels** on issues and PRs,
- **API spend**,
- and — only if a bad PR passed *both human gates* — code on main.

List what the agent touched: its runs (`gh run list`), its PRs (`gh pr list --author "app/github-actions"`), its comments on the affected issues.

## 3. Revoke the work

- **Open/draft PR**: close it and delete the branch — `gh pr close <n> --repo <repo> --delete-branch`. Reset the issue's pipeline label to the last good state (e.g. back to `status:design`).
- **Merged PR** (passed gate 2 before the problem surfaced): `git revert` via a normal PR — never a force-push to main. If it reached production, the release manager/devops rollback path applies (previous Cloud Run revision).
- **Wrong labels/comments**: labels corrected by hand; comments stay — they are the audit trail, and §5 treats history as learning data. Add a correcting comment rather than deleting.
- **Suspected secret or PII exposure**: rotate the affected secrets (`ANTHROPIC_API_KEY`, `DIGEST_TOKEN`, any product secrets in the run's scope) before anything else in this step, and treat PII-in-logs per constitution rule 5 as a critical finding.

## 4. Record and learn

1. Open an **incident issue** in `dev-department`: what happened, which runs (links), what was revoked, root cause once known.
2. If a rule would have prevented it, open a **lesson proposal** using `templates/retrospective.md`. The retrospective agent's ≥2-PR evidence bar applies to *pattern* proposals — as rulebook curator you may add a rule from a single incident when the severity warrants it; note the incident issue as cause.
3. If the root cause is an agent definition or workflow bug, fix it in `dev-department` via a normal reviewed PR — the fix is live for all products on the next run (§3).

## 5. Resume

Per [kill-switch.md](kill-switch.md): variable back to `true`, re-apply the pipeline labels of everything that was mid-phase, verify the next digest looks normal.
