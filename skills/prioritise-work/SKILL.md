---
name: "prioritise-work"
description: "Scan Slack channels and GitHub repos for all work, create missing issues, prioritise everything, assign the top items to the best contributors, and notify the team."
---

# Prioritise work

Scan all visible Slack channels and GitHub issues/PRs to identify every piece of work, create GitHub issues for untracked work items, apply prioritisation labels, assign the top unassigned items to the best contributors, and notify the team.

## Inputs

- A GitHub repository (or the default GitHub repository for the project).
- Slack channel to use for assignment notifications.
- The `add-feature-request` skill must be available.
- GitHub CLI (`gh`) must be authenticated.
- Optional constraints per issue: preferred assignee, exclude someone, urgency, or desired skill area.

## Workflow

1. Gather Slack channels.
   - Read the Slack channel list or use known channel IDs from memory/workspace.
   - Read the recent messages (last 20–30) from each channel using `slack.readMessages`.
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

6. Identify the top unassigned items.
   Determine the 5 most important issues that:
   - Do **not** already have an open PR addressing them.
   - Are not already assigned.
   - Have the highest priority label (P0 > P1 > P2 > P3).
   - Are not blocked by another issue (unless no alternatives exist).

7. Assign each top item to the best contributor.
   For each of the top unassigned issues:
   - Inspect who contributes to the project:
     - Check recent commit authors: `git shortlog -sne --all` or `gh api repos/<owner>/<repo>/contributors`.
     - Check recent issue/PR participants: open PR authors, issue authors, recent reviewers, and comments.
     - Prefer contributors with relevant recent work in touched areas, matching labels, similar issues, or related PRs.
   - Pick one primary GitHub username. Do not assign purely by volume if the issue clearly belongs to a specific domain owner.
   - If no suitable assignee can be found, skip assignment for that issue and flag it in the output.
   - Assign using `gh issue edit <number> --add-assignee <github-login>`.
   - Re-read the issue to confirm the assignee is present before moving on.

8. Notify the team.
   - Send a single summary message to the Slack channel listing all assignments made:
     - issue link, assignee name, and a one-line reason for each.
   - Ask assignees to acknowledge or flag if they are blocked.
   - Do not send one message per assignment; batch into one.

## Verification

Before reporting success, confirm:

- All open issues have a priority label applied.
- Each top item either has a confirmed GitHub assignee or is explicitly flagged as unassignable.
- The Slack notification was sent, or the exact messaging permission/channel blocker is reported.

## Safety / etiquette

- Do not assign work to someone who has explicitly declined or is known to be unavailable.
- Prefer one clear owner per issue over splitting assignments.
- Assignment is an external write — only perform it when this skill is explicitly invoked or clearly delegated.
- If an issue is ambiguous, apply a priority label but skip assignment and flag it for human review.

## Next steps

After running this skill, agents can execute the assigned work using `pick-up-work` or `write-code`.

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

### Assigned
**#NN - title** → @github-login (reason)
**#NN - title** → @github-login (reason)
**#NN - title** → unassigned (no suitable contributor found)
```
