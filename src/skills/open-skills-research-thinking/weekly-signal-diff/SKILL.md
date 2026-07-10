---
name: weekly-signal-diff
description: Compare a defined set of inputs against the state from the last run and report only meaningful changes -- new signals, shifted assumptions, dead threads, emerging patterns. Use on a recurring weekly cadence for staying current without re-reading everything.
---

# Weekly Signal Diff

Review a defined set of inputs and report only what meaningfully changed since the last run. The state file pattern (skill remembers its last run) unlocks a whole class of recurring workflows.

## Trigger Conditions

- User runs this on a weekly (or other recurring) cadence
- User asks "what changed?" or "what's new?"
- User wants a diff against the previous state

## State File

Maintain a state file at `docs/signals/.state.json`:

```json
{
  "last_run": "2024-03-15T10:00:00Z",
  "inputs": {
    "notes_folder": {
      "last_observed": ["file1.md:2024-03-14", "file2.md:2024-03-13"],
      "last_content_hash": "abc123"
    },
    "docs/ideas/": {
      "last_observed": ["2024-03-10-brain-dump.md"]
    },
    "project_state": {
      "active_branches": ["feature-x", "bugfix-y"],
      "open_issues": ["#42", "#47"]
    },
    "saved_searches": {
      "opencode releases": "last_seen: v1.2.0"
    }
  }
}
```

The state file is what makes a true diff possible -- without it, every run is a re-summary.

## Input List

Define which inputs to watch on setup:

| Input Type | How to Check |
|------------|-------------|
| Folders | New/modified files since last run |
| Notes files | Content diff against last hash |
| Git branches | New, merged, or stale branches |
| Issues/PRs | Status changes |
| Saved searches / RSS | New results since last seen |
| Project state | Changes in active workstreams |

## Output Format

Order by importance of change, not by source:

```markdown
# Signal Diff: <date range>

## Critical Changes
- <item 1>

## New Signals
- <item 2>
- <item 3>

## Shifted Assumptions
- <what was assumed> -> <what's now indicated>

## Dead Threads
- <something that went quiet or was abandoned>

## Emerging Patterns
- <pattern observed across multiple inputs>

## Suggested Follow-Ups
1. <one concrete next action>
2. <another>
3. <another>
```

## No-Change Rule

No-change is a valid and short answer. Never pad a quiet week:
```
# Signal Diff: Apr 1 -- Apr 7
No meaningful changes this week.
```

## Suggested Follow-Ups

Close with at most three follow-ups based on the diff. These should be concrete and actionable -- not "think about X" but "check Y" or "draft Z."

## Verification

Do an initial baseline run to populate the state file. Report what was recorded. On the second run, confirm only changes appear in the output.
