---
name: "write-code"
description: "Gather context, implement code for an issue or PR, self-review, verify checks, then open or update a pull request and communicate status."
---

# Write code

Use when asked to write code to address a GitHub issue, or to push changes in response to review comments on an existing pull request.

## Inputs

- A GitHub repository (or the default GitHub repository for the project).
- GitHub issue URL or number, or an existing pull request URL or number to update.
- Slack channel for status updates (optional).

## Workflow

1. Gather context.
   - Read the GitHub issue or PR: title, body, acceptance criteria, comments, and any linked references.
   - If access has been given to any Slack channels, read recent messages there for additional context, requests, or blockers that have not yet made it into GitHub.
   - If updating an existing PR, read all open review comments and identify which are unresolved.
   - If the requirements are unclear, post a clarifying comment on the issue or PR before writing any code.

2. Write the code.
   - Create a feature branch from the repository's default branch, or check out the existing PR branch if updating one.
   - Use a descriptive branch name derived from the issue number and title, e.g. `123-short-description`.
   - Implement the smallest coherent change that satisfies the requirements or addresses the review comments.
   - Add or update tests and documentation as needed.
   - Keep changes scoped; avoid drive-by refactors.

3. Self-review.
   - Re-read the full diff before committing.
   - Look for: logic errors, missed edge cases, unnecessary complexity, missing test coverage, and anything likely to prompt a reviewer to request changes.
   - Make improvements now rather than after review where possible.

4. Verify.
   - Run all available checks: tests, lint, typecheck, build, and static analysis.
   - If a check cannot run locally, record why and what was inspected instead.
   - Do not push if tests or lint are failing unless the failure is pre-existing and demonstrably unrelated to the change.

5. Commit and push.
   - Create one or more logically connected commits with messages that explain the user-visible change and reference the issue number.
   - Use the repository's configured git identity; do not alter global git config.
   - Push the branch to the remote.
   - Do not force-push unless correcting a commit on a branch with no review activity yet.

6. Open or update the pull request.
   - If no PR exists: open one with a description covering what was implemented, how it was verified, and any known limitations. Include a closing keyword, e.g. `Closes #123`. Request review from the configured reviewer(s).
   - If a PR exists: push the new commits and respond to each open review comment explaining how it was addressed, or giving a clear reason if it was not changed.
   - Ensure the PR title describes the change rather than the implementation mechanics.

7. Communicate status.
   - Post a concise update on the GitHub issue or PR summarising what was done.
   - If a Slack channel was provided, post there with the PR link and a one-line summary of what changed.
   - State clearly what is done, what is waiting on review, and anything that remains blocked.

## Safety / etiquette

- Never include secrets, tokens, private local paths, or unrelated repository state in commits or PR descriptions.
- Preserve unrelated work. Do not delete branches, reset shared branches, or rewrite history without explicit confirmation.
- Do not close issues to reduce backlog; only close when work is merged or the project owner explicitly asks.

## Output

A concise message summarising the action taken:

```
Implemented #NN in $REPOSITORY_NAME — PR #NN opened/updated: "Short PR title"
Checks: passed | Reviewer notified | Status posted in $SLACK_CHANNEL
```
