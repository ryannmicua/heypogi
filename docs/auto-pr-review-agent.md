# Automated PR Review Agent (discussion)

## Idea

Trigger an agent on this machine to review PRs on-demand, then post results back to the PR.

## Trigger

`/review` comment on a GitHub PR → GitHub Actions workflow (self-hosted runner on this machine) → agent CLI → review posted as PR comment.

## How it gives the reviewer context

The `actions/checkout@v4` step clones the PR branch. The agent CLI runs from that checkout, reads `AGENTS.md`, `docs/`, and the codebase to orient itself naturally. No external knowledge base needed — the repo is the context.

The same runner handles any repo because the checkout swaps the project context per job.

## Architecture sketch

```
PR comment "/review" → GitHub webhook → Self-hosted runner
                                           ↓
                                   checkout@v4 (PR branch)
                                           ↓
                                   Agent CLI reviews diff
                                           ↓
                                   gh pr review --body="..."
```

## What'd need building

- `.github/workflows/pr-review.yml` — triggers on `issue_comment`, filters for `/review`, checks out PR, runs agent, posts review
- Self-hosted runner installed as a Windows service on this machine
- The agent CLI (opencode, Codex, etc.) installed and on PATH

## Open questions

- How to handle long-running reviews (agent could take minutes)
- How to stream or update results
- Whether to auto-request changes or just report findings
- Security: runner has access to any repo it can clone (consider scoped tokens)
- Whether workflows live in each repo or org-level
