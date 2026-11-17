#!/usr/bin/env bash
# Watches one PBI through the department pipeline for the PO companion (agents/po-companion.md).
# Polls the issue, its design PR and its feature PR; prints one line per change:
#   <UTC time> <event> <detail>
# Events: intake-questions, intake-ready, issue-comment, design-pr-opened, design-pr-updated,
#         design-merged, feature-pr-opened, feature-pr-ready, feature-pr-updated, pr-comment,
#         ci-green, ci-red, build-paused, pr-merged (then exits 0), error.
# Usage: watch-pbi.sh <owner/repo> <issue-number> [interval-seconds, default 180]
# Read-only: it never writes to GitHub.
set -uo pipefail

REPO="${1:?usage: watch-pbi.sh <owner/repo> <issue-number> [interval-seconds]}"
ISSUE="${2:?usage: watch-pbi.sh <owner/repo> <issue-number> [interval-seconds]}"
INTERVAL="${3:-180}"

emit() { printf '%s %s %s\n' "$(date -u +%H:%M:%S)" "$1" "${2:-}"; }

# Finds the newest PR whose title starts with "<prefix>:" and ends with "(#<issue>)".
find_pr() {
  gh pr list --repo "$REPO" --state all --search "\"(#$ISSUE)\" in:title" --limit 20 \
    --json number,title \
    --jq "[.[] | select((.title | startswith(\"$1:\")) and (.title | endswith(\"(#$ISSUE)\")))] | .[0].number // empty"
}

# One line describing a PR: state|draft|head|comments|ci  (ci: green, red, pending or none)
pr_snapshot() {
  gh pr view "$1" --repo "$REPO" --json state,isDraft,headRefOid,comments,statusCheckRollup --jq '
    def ci: if (.statusCheckRollup | length) == 0 then "none"
            elif any(.statusCheckRollup[]; (.conclusion // .state // "") | test("FAILURE|ERROR|CANCELLED|TIMED_OUT")) then "red"
            elif all(.statusCheckRollup[]; (.conclusion // .state // "") | test("SUCCESS|NEUTRAL|SKIPPED")) then "green"
            else "pending" end;
    "\(.state)|\(.isDraft)|\(.headRefOid[0:7])|\(.comments | length)|\(ci)"'
}

field() { echo "$1" | cut -d'|' -f"$2"; }

prev_labels="" prev_comments="" design_pr="" prev_design="" feature_pr="" prev_feature=""
first=1

while :; do
  issue=$(gh issue view "$ISSUE" --repo "$REPO" --json labels,comments --jq \
    '"\([.labels[].name] | sort | join(","))|\(.comments | length)|\(.comments[-1].body // "" | split("\n")[0] | .[0:120])"' 2>&1) \
    || { emit error "issue: $issue"; sleep "$INTERVAL"; continue; }
  labels=$(field "$issue" 1); comments=$(field "$issue" 2); last=$(echo "$issue" | cut -d'|' -f3-)

  if [ -n "$prev_comments" ] && [ "$comments" != "$prev_comments" ]; then
    case "$last" in
      "### Intake: ready"*) emit intake-ready "#$ISSUE" ;;
      *"Build pipeline paused"*) emit build-paused "#$ISSUE: $last" ;;
      *)
        if [[ ",$labels," == *",status:intake,"* ]]; then emit intake-questions "#$ISSUE: $last"
        else emit issue-comment "#$ISSUE: $last"; fi ;;
    esac
  fi
  [ -n "$prev_labels" ] && [ "$labels" != "$prev_labels" ] && emit labels "#$ISSUE: $labels"
  prev_labels="$labels" prev_comments="$comments"

  [ -z "$design_pr" ] && design_pr=$(find_pr Design) && [ -n "$design_pr" ] && [ $first -eq 0 ] && emit design-pr-opened "#$design_pr"
  if [ -n "$design_pr" ]; then
    d=$(pr_snapshot "$design_pr" 2>/dev/null) || d="$prev_design"
    if [ -n "$prev_design" ] && [ "$d" != "$prev_design" ]; then
      if [ "$(field "$d" 1)" = MERGED ]; then emit design-merged "#$design_pr"
      elif [ "$(field "$d" 3)" != "$(field "$prev_design" 3)" ]; then emit design-pr-updated "#$design_pr new commits"
      elif [ "$(field "$d" 4)" != "$(field "$prev_design" 4)" ]; then emit pr-comment "#$design_pr"; fi
    fi
    prev_design="$d"
  fi

  [ -z "$feature_pr" ] && feature_pr=$(find_pr Feature) && [ -n "$feature_pr" ] && [ $first -eq 0 ] && emit feature-pr-opened "#$feature_pr (draft)"
  if [ -n "$feature_pr" ]; then
    f=$(pr_snapshot "$feature_pr" 2>/dev/null) || f="$prev_feature"
    if [ -n "$prev_feature" ] && [ "$f" != "$prev_feature" ]; then
      [ "$(field "$f" 1)" = MERGED ] && { emit pr-merged "#$feature_pr"; exit 0; }
      [ "$(field "$prev_feature" 2)" = true ] && [ "$(field "$f" 2)" = false ] && emit feature-pr-ready "#$feature_pr awaits gate 2"
      [ "$(field "$f" 3)" != "$(field "$prev_feature" 3)" ] && emit feature-pr-updated "#$feature_pr new commits $(field "$f" 3)"
      [ "$(field "$f" 4)" != "$(field "$prev_feature" 4)" ] && emit pr-comment "#$feature_pr"
      if [ "$(field "$f" 5)" != "$(field "$prev_feature" 5)" ]; then
        case "$(field "$f" 5)" in green) emit ci-green "#$feature_pr" ;; red) emit ci-red "#$feature_pr" ;; esac
      fi
    fi
    prev_feature="$f"
  fi

  if [ $first -eq 1 ]; then
    emit watching "#$ISSUE labels=[$labels] design=${design_pr:-none}${prev_design:+ ($prev_design)} feature=${feature_pr:-none}${prev_feature:+ ($prev_feature)} every ${INTERVAL}s"
    [ "$(field "$prev_feature" 1)" = MERGED ] && { emit pr-merged "#$feature_pr (already)"; exit 0; }
    first=0
  fi
  sleep "$INTERVAL"
done
