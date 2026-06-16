---
name: "assign-work"
description: "Assign a GitHub issue to the best contributor and notify the team via Slack."
---

# Assign work

Use when asked to assign a GitHub issue to the best person for a project and make sure they see it.

## Inputs

- A GitHub repository (or the default GitHub repository for the project)
- GitHub issue URL or number.
- Slack channel to use for notifying the developer team.
- Optional constraints from the user, e.g. preferred assignee, exclude someone, urgency, or desired skill area.

## Workflow

1. Identify the repository and issue.
   - Use `gh issue view` for title, body, labels, comments, current assignees, linked PRs, author, and state.
   - If the issue is closed or already assigned, report that and ask only if reassignment would be destructive or socially surprising.

2. Inspect who contributes to the project.
   - Check recent commit authors: `git shortlog -sne --all` or `gh api repos/<owner>/<repo>/contributors`.
   - Check recent issue/PR participants when useful: open PR authors, issue authors, recent reviewers, and comments.
   - Prefer contributors with relevant recent work in touched areas, matching labels, similar issues, or related PRs.
   - Consider social/team context already known in the conversation, such as GitHub-to-chat identity mappings.
   - Do not assign purely by volume if the issue clearly belongs to a specific domain owner.

3. Decide the assignee.
   - Pick one primary GitHub username unless the issue explicitly needs multiple owners.
   - State the reason briefly: relevant files, recent commits, related issue/PR ownership, or product/domain fit.
   - If no suitable assignee can be found, do not guess; report the top candidates and ask the user.

4. Assign the issue in GitHub.
   - Use `gh issue edit <issue> --add-assignee <github-login>`.
   - Re-read the issue afterwards to confirm the assignee is present.
   - If permissions fail, report the exact blocker and do not pretend assignment succeeded.

5. Notify the developer team.
   - Send a short message in the Slack channel used by the developer team so the team see it and do not duplicate work.
   - Include the issue link, assignee mention/name if known, and one-line reason/context.
   - Ask them to acknowledge or say if they are blocked.
   - Keep it non-annoying; do not send repeated nudges unless explicitly asked or a heartbeat/follow-up instruction says to.

## Identity notes

- Use known mappings from conversation or memory when available, but verify GitHub logins before assignment.

## Verification

Before reporting success, confirm:

- the GitHub issue shows the chosen assignee;
- the Slack message was sent, or the exact messaging permission/channel blocker is reported;
- the final response includes the issue URL, assignee, reason, and notification status.

## Safety / etiquette

- Assignment is an external write. Only do it when the user asked for assignment or clearly delegated issue triage.
- Do not assign work to someone who has explicitly declined or is known to be unavailable.
- Prefer one clear owner over spraying assignments across the team.
- If the issue is ambiguous, ask one concise question rather than assigning randomly.

## Output

A concise message, formatted for Slack or chat, summarising the action taken:

```
Assigned issue #123 in $REPOSITORY_NAME to @github-login and notified the developer team in $SLACK_CHANNEL.
```