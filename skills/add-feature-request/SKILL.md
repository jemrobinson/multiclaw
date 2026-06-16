---
name: "add-feature-request"
description: "Creates a concise implementation plan for a new feature and opens a comprehensive GitHub issue."
---

# Add feature request

Use to create a concise implementation plan for a new feature in a GitHub repository and open a structured GitHub issue to request its implementation.

## Inputs

- A GitHub repository (or the default GitHub repository for the project)
- Optional constraints from the user, e.g. urgency, or desired skill area.

## Workflow

Given a GitHub repository (or the default one if none is supplied), the skill accomplishes the following:

1. Read the current state of the repository:
   - Prefer the existing local checkout when current; otherwise fetch/clone the repo.
   - Inspect the file tree, README, relevant source files, open PRs/issues if they matter, and current branch status.

2. Generate a short but actionable implementation plan covering:
   - files to touch, tests to add, verification strategy, and key assumptions.

3. Open a new GitHub issue in the repository with a clear, structured spec. The issue gets:
   - a descriptive title,
   - a body that includes: feature request, current repo context, proposed implementation plan, verification plan, and assumptions/open questions.
   - appropriate labels (including a `feature-request` label and a priority label such as `priority:p1-next` or `priority:p2-soon`).

## Output

A concise message, formatted for Slack or chat, summarising the opened issue:

```
✓ Created issue #123 in $REPOSITORY_NAME: "Add dark-mode support"
```
