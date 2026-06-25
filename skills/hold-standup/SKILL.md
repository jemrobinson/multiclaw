---
name: "hold-standup"
description: "Facilitate a structured stand-up in Slack: either run a full stand-up (post prompt, collect responses, summarise) or summarise an existing stand-up thread that is already in progress."
---

# Hold stand-up

Use to facilitate a stand-up for the developer team in Slack. Supports two modes:

- **Full stand-up** (default): post the prompt to the channel, collect responses, and produce a summary.
- **Summarise only**: find the most recent stand-up thread in the channel and summarise the replies already present, without posting a new prompt.

Use summarise-only mode when a stand-up prompt has already been posted (e.g. by a scheduled cron run earlier) and you only need to compile and share the summary.

## Inputs

- Slack channel to use for the stand-up.
- `mode`: `full` (default) or `summarise`.
- List of team members to tag (full mode only), or derive from the project's recent GitHub contributors if not supplied.
- Optional: custom stand-up questions (full mode only; defaults to the three standard questions below).

## Workflow — full mode

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

4. Summarise (shared with summarise mode — see below).

## Workflow — summarise mode

1. Find the most recent stand-up thread.
   - Read recent messages in the channel.
   - Identify the latest message that looks like a stand-up prompt (contains the standard questions or a stand-up heading).
   - If no stand-up thread is found, report that and stop.

2. Read all replies.
   - Collect threaded replies and any flat follow-up messages that are clearly responses to the prompt.
   - Note which participants have responded and which have not.

3. Summarise (shared step).

## Summarise (shared step)

- Produce a concise per-person summary covering: completed work, today's focus, and blockers.
- Highlight blockers prominently so the team can act on them.
- If any participant has no current task assigned, note this as a potential handoff opportunity.
- Flag any participants who did not respond.
- Post the summary back to the Slack channel as a reply to the original prompt.

## Verification

Before reporting success, confirm:

- Full mode: the stand-up prompt was sent to the correct Slack channel with all participants tagged.
- Both modes: responses have been read, or the absence of responses is noted explicitly.
- Both modes: the summary has been posted to the channel or returned to the user.

## Safety / etiquette

- Only post in the channel the user specifies; do not infer or guess channel names.
- Do not tag participants who are known to be on leave or unavailable.
- Send one prompt per stand-up; do not send repeated nudges unless explicitly instructed.
- In summarise mode, do not post a new prompt — only post the summary as a reply to the existing thread.
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
