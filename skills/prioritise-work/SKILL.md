---
name: "prioritise-work"
description: "Scan Slack channels and GitHub repos for all work, create missing issues, prioritise everything, and surface the most important next items."
---

# Prioritise work

Scan all visible Slack channels and GitHub issues/PRs to identify every piece of work, create GitHub issues for untracked work items, apply prioritisation labels, and identify the most important next issues.

## Inputs

- A GitHub repository (or the default GitHub repository for the project)
- The `slack` tool must be configured (has access to channels). Use the `slack` skill for channel details.
- The `add-feature-request` skill must be available.
- GitHub CLI (`gh`) must be authenticated.
- Know the default GitHub repository for the project

## Workflow

1. Gather Slack channels.
   - Read the Slack channel list or use known channel IDs from memory/workspace. For each visible channel:
   - Read the recent messages (last 20-30) from each channel using `slack.readMessages`.
   - Identify any mentions of work items, tasks, feature requests, bug reports, or action items.
   - Extract concrete pieces of work — things that are being discussed but have not necessarily been tracked.

2. Gather GitHub state.
   - List all open issues: `gh issue list --repo <owner>/<repo> --state open --json number,title,labels,body,comments,assignees,created_at`.
   - List all open PRs: `gh pr list --repo <owner>/<repo> --state open --json number,title,state,labels,files,commits,reviews`.
   - List the available labels: `gh label list --repo <owner>/<repo>`.
   - Note which issues already have PRs addressing them (PRs whose titles/bodies reference the issue number).

3. Identify all work items.
   Merge the work from Slack and GitHub into a single inventory:
   - **Tracked work**: Open GitHub issues (already tracked).
   - **Untracked work**: Slack discussion items that have no corresponding GitHub issue.
   - **In-progress work**: Issues that have open PRs addressing them.

4. Create missing GitHub issues.
   For each untracked work item found in Slack:
   - Determine if it truly warrants a GitHub issue (is it concrete enough? actionable?).
   - If yes, use the `add-feature-request` skill to create a structured issue in the repository.
   - Log which issues were created.

5. Apply prioritisation labels.
   Re-read all open GitHub issues. For each issue, apply one of the existing priority labels:
   - **`priority:p0-now`** — Actively owned / must be done next before expanding scope.
   - **`priority:p1-next`** — High-value next queue item once current work clears.
   - **`priority:p2-soon`** — Useful backlog item, sequence after P1 or pick up when unblocked.
   - **`priority:p3-later`** — Backlog polish or dependent work; keep but do not interrupt higher priority.

   Also ensure area labels are set (e.g., `area:auth`, `area:workflow`, `area:planning`, etc.).

   Use `gh issue edit <number> --add-label <label>` to apply labels.

   **Prioritisation criteria:**
   - **P0**: Blocks other work, causes data loss/security risk, user-facing breaking issue, or explicitly requested by the team lead.
   - **P1**: Directly improves user workflow, unblocks a team member, or is a high-value feature in the current sprint/milestone.
   - **P2**: Nice-to-have improvements, refinements, or medium-value features.
   - **P3**: Polish, documentation, low-priority features, or work dependent on P0/P1 items.

6. Identify the most important next issues.
   After labelling, determine the 5 most important next issues that:
   - Do **not** already have an open PR addressing them.
   - Have the highest priority label (P0 > P1 > P2 > P3).
   - Are not blocked by another issue (unless no alternatives exist).

   Report these as the "next things to pick up."

## Output

A concise message, formatted for Slack or chat:

```
## Prioritise Work Complete

**Channels scanned:** X
**Issues reviewed:** X
**PRs reviewed:** X
**New issues created:** X (if any)

### Priorities
- priority:p0-now: #NN - title
- priority:p1-next: #NN - title
- priority:p2-soon: #NN - title
- priority:p3-later: #NN - title

### Next up
**#NN - title** (no open PR, priority:p0-now)
**#NN - title** (no open PR, priority:p0-now)
**#NN - title** (no open PR, priority:p1-next)
**#NN - title** (no open PR, priority:p1-next)
**#NN - title** (no open PR, priority:p2-soon)
```
