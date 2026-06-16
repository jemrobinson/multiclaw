---
name: "review-pull-request"
description: "Review a pull request against its issue, then merge or request fixes and notify the developer via Slack."
---

# Review pull request

Use to review a GitHub pull request against an issue that the pull request should close. At the end of the review, either merge the pull request or request changes, and notify the developer team in Slack.

## Inputs

- A GitHub repository (or the default GitHub repository for the project)
- GitHub pull request URL or number.
- GitHub issue URL or number that should be closed by the pull request.
- Slack channel to use for notifying the developer team.

## Workflow

1. Read the issue.
   - Capture the issue title, body, acceptance criteria, linked context, comments, labels, and current state.
   - Identify the concrete requirements the pull request must satisfy.

2. Read the pull request.
   - Inspect the PR title/body, changed files, diff, commits, review comments, checks, and mergeability.
   - Pull/fetch the branch locally when useful for deeper code review or verification.
   - Consider using automated review tools available in the repository to assist you.

3. Review implementation quality.
   - Check whether the code meets the issue requirements.
   - Look for correctness, maintainability, accessibility/usability where relevant, test coverage, docs, obvious regressions, and security/safety concerns.
   - Run the smallest meaningful verification gate available: tests, lint, typecheck, build, static checks, or direct local smoke test.
   - Check that all open comments have been addressed, and that no unresolved conversations remain.
   - Keep the original issue submitter in the loop, checking that they are also satisfied with the implementation.

4. If satisfied:
   - Leave an approving review or concise comment when appropriate.
   - Merge the pull request using an explicit merge method supported by the repo.
   - Report the merged PR URL and verification evidence in the Slack channel.

5. If unsatisfied:
   - Leave GitHub review comments or a PR comment explaining what needs to be fixed.
   - Be specific and actionable; tie requests back to issue requirements or code quality concerns.
   - Message the PR author in the Slack channel asking them to fix the pull request.
   - Include the PR link, issue link, and a concise bullet list of required fixes.

## Verification

Before reporting success, confirm:

- The PR shows the expected merge state or the review comment is posted.
- The Slack notification was sent, or the exact messaging permission/channel blocker is reported.
- The final response includes the PR URL, outcome (merged or changes requested), and notification status.

## Safety / etiquette

- Do not merge if checks are failing, the branch is not mergeable, required requirements are unmet, or verification could not be completed for a meaningful reason.
- Prefer `gh` for GitHub operations when authenticated.
- Only merge when all acceptance criteria in the issue are demonstrably met.

## Output

A concise message, formatted for Slack or chat, summarising the action taken:

```
Merged PR #NN in $REPOSITORY_NAME (closes #NN) and notified the team in $SLACK_CHANNEL.
```

or, if changes were requested:

```
Requested changes on PR #NN in $REPOSITORY_NAME and notified @developer in $SLACK_CHANNEL with N required fixes.
```
