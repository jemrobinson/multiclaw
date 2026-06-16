---
name: "hold-standup"
description: "Facilitate a structured stand-up in Slack: post the prompt, collect responses, and summarise progress and blockers."
---

# Hold stand-up

Use to facilitate a stand-up for the developer team in Slack. Posts the stand-up prompt to the team, collects responses, and produces a concise summary of progress and blockers.

## Inputs

- Slack channel to use for the stand-up.
- List of team members to tag, or derive from the project's recent GitHub contributors if not supplied.
- Optional: custom stand-up questions (defaults to the three standard questions below).

## Workflow

1. Identify participants.
   - Use the supplied list of team members, or derive from recent GitHub contributors using `gh api repos/<owner>/<repo>/contributors` or `git shortlog -sne --all`.
   - Resolve each participant's Slack handle using known GitHub-to-Slack identity mappings from conversation or memory.
   - If a participant's Slack handle cannot be resolved, include their name in plain text rather than guessing.

2. Post the stand-up prompt.
   - Send a single message to the Slack channel tagging all participants.
   - Include the standard questions:
     1. What did you complete since the last stand-up?
     2. What are you working on today?
     3. Do you have any blockers?
   - Use a clear heading with the date so participants can find the thread easily.

3. Collect responses.
   - Read replies in the thread or channel after a reasonable interval.
   - If running interactively, wait for acknowledgements before summarising.
   - If running on a schedule, summarise responses that are already present.
   - Note any participants who have not yet responded.

4. Summarise.
   - Wait a few minutes for responses to arrive, then read all replies in the thread.
   - Produce a concise per-person summary covering: completed work, today's focus, and blockers.
   - Highlight blockers prominently so the team can act on them.
   - Flag any participants who did not respond.
   - Post the summary back to the Slack channel as a reply to the original prompt.

## Verification

Before reporting success, confirm:

- The stand-up prompt was sent to the correct Slack channel with all participants tagged.
- Responses have been read, or the absence of responses is noted explicitly.
- The summary has been posted to the channel or returned to the user.

## Safety / etiquette

- Only post in the channel the user specifies; do not infer or guess channel names.
- Do not tag participants who are known to be on leave or unavailable.
- Send one prompt per stand-up; do not send repeated nudges unless explicitly instructed.
- Keep the tone neutral and professional.

## Output

A concise stand-up summary, posted to the Slack channel and returned to the user:

```
## Stand-up — YYYY-MM-DD

**@person-one**
- Done: completed X
- Today: working on Y
- Blockers: none

**@person-two**
- Done: completed A
- Today: working on B
- Blockers: blocked on #NN — issue title

**Did not respond:** @person-three
```
