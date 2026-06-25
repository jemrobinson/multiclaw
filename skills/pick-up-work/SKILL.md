---
name: "pick-up-work"
description: "Scan Slack and GitHub for actionable work, triage it, then act on the highest-priority item: unblock an existing PR, respond to a review, or implement a new issue."
---

# Pick up work

Use when an agent should autonomously decide what to work on next. Scans Slack channels and GitHub for all work that needs attention, triages it, picks the most important actionable item, and acts on it. Posts concise status updates so the team knows what is happening.

Invoke this skill when asked to "check what needs doing", "pick up the next task", "see what's blocking progress", or similar open-ended requests to contribute autonomously.

## Inputs

- A GitHub repository (or the default GitHub repository for the project).
- Slack channel(s) to scan for context (or use all accessible channels if none are specified).
- Optional: the agent's own GitHub username, used to find assigned or authored issues/PRs.

## Workflow

1. Gather context.
   - Read recent messages (last 20–30) from each accessible Slack channel. Look for:
     - direct or indirect mentions of this agent or its GitHub username
     - concrete implementation or review requests
     - GitHub issue/PR links
     - reports of failing checks, conflicts, or blockers that need help
   - Read GitHub state for the repository:
     - open issues and PRs, especially those assigned to, authored by, or review-requested from this agent
     - PRs with failing checks, merge conflicts, requested changes, or stale review comments
     - PRs from others that are waiting for review

2. Categorise every work item into one of:
   - **Needs my code** — an issue or PR with open review comments or failing checks that require changes from this agent.
   - **Needs my review** — a PR where this agent has been asked to review.
   - **Needs response or clarification** — a Slack message or GitHub comment requiring acknowledgement.
   - **Waiting on someone else** — this agent's open PR is CI-green and awaiting another person's review. Not active work.
   - **Not actionable** — closed, stale, or otherwise out of scope.

3. Prioritise.
   - **First**: unblock existing PRs this agent owns — address requested changes, CI failures, merge conflicts, or review comments.
   - **Second**: respond to direct mentions, tags, and review requests.
   - **Third**: if no existing PR has actionable work, pick one bounded open issue that can become a clean, focused PR. Do not pile up overlapping or hard-to-review PRs.
   - **Fourth**: open GitHub issues for concrete bugs or technical debt discovered while working.
   - Do not treat "waiting on review" as a reason to idle — state the wait clearly and move on to useful, low-collision work.

4. Announce intent (for non-trivial implementation work).
   - Before starting implementation, post a short message in the Slack channel naming:
     - the issue or PR being picked up
     - why it was selected (priority, blocker, tag)
     - the action to be taken
   - Keep the tone that of an engineer, not a project manager.

5. Act on the chosen task.
   - **Code work**: use the `write-code` skill to implement the change or address review comments.
   - **Review work**: use the `review-pull-request` skill to inspect the diff, run verification, and approve or request changes.
   - **Issue work**: open or update a GitHub issue with specific reproduction steps, expected behaviour, and a proposed next step.
   - **Coordination**: tag the relevant person with a specific, low-noise ask and include the exact link.

6. Communicate status.
   - After completing the chosen task, post a concise update to the Slack channel:
     - what was done (with PR or issue link)
     - what is now waiting on review or CI
     - any current blocker and who was asked
     - the next item to pick up, if one is already clear

## Verification

Before reporting success, confirm:

- The chosen task has been completed or clearly handed off, with evidence (PR link, CI status, review posted).
- The Slack status update was sent, or the exact blocker is reported.
- No unrelated branches were modified, reset, or force-pushed.

## Safety / etiquette

- Do not close issues to reduce backlog; only close when work is merged or the project owner explicitly asks.
- Do not merge or push changes that bypass the repository's normal review and CI expectations.
- Do not claim to be busy with a PR solely because it is open and awaiting review — state what is waiting and then pick up other work.
- Do not spam Slack or GitHub with repeated updates; post on meaningful state changes only.
- If blocked and unable to find any actionable work after checking both Slack and GitHub, finish with exactly:

  ```
  HEARTBEAT_OK
  ```

## Output pattern

```
Doing now:   <active task / PR / branch>
Waiting:     <review / CI / person> — <link>
Blocked:     <exact blocker and who was asked, or "none">
Next:        <next issue/PR if current work is waiting>
```
