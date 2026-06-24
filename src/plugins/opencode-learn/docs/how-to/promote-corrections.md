# How to Promote Corrections to Rules

Turn recurring correction patterns into enforceable agent instructions.

## When to Promote

A single correction is just feedback. A correction that recurs across sessions is a signal that the agent should adopt a rule.

The built-in analysis tool flags corrections that have appeared **2 or more times** as "graduate candidates."

## Step 1: Generate Proposals

```bash
cd ~/.opencode/plugins/opencode-learn
bun src/analyze.ts --apply
```

This writes proposals to the `proposed_rule` table with status `pending`. It also marks the source corrections as `resolved` so they won't appear in future analysis runs.

## Step 2: Review the Proposals

Query the proposed rules:

```sql
SELECT id, classification, instruction, freq, status
FROM proposed_rule
WHERE status = 'pending'
ORDER BY freq DESC;
```

Each proposal includes:
- **classification**: skill_misuse, memory_update, behavioral, rule, or preference
- **instruction**: A suggested rule text
- **freq**: How many times this pattern appeared
- **evidence**: Example correction texts (stored as JSON)

## Step 3: Approve or Reject

Once reviewed, update the status:

```sql
-- Approve a rule
UPDATE proposed_rule
SET status = 'approved', reviewed_at = datetime('now')
WHERE id = 1;

-- Reject a rule (one-off, not meaningful)
UPDATE proposed_rule
SET status = 'rejected', reviewed_at = datetime('now')
WHERE id = 2;
```

## Step 4: Apply Approved Rules

For approved preferences and behavior rules, add them to your `AGENTS.md` or `opencode.json`:

**In AGENTS.md:**
```markdown
## User Preferences

- Always explain shell commands before running them
- Use ripgrep instead of grep for file searches
- Prefer camelCase for variable names
```

**In opencode.json agent overrides:**
```json
{
  "agents": {
    "build": {
      "system": "User preferences:\n- Explain commands before running them\n- Use ripgrep over grep"
    }
  }
}
```

For hard rules, add them as permissions:

```json
{
  "permissions": {
    "bash": "allow",
    "write": "ask",
    "delete": "deny"
  }
}
```

## Step 5: Auto-Approve (Use Sparingly)

For patterns you trust, you can auto-approve:

```bash
bun src/analyze.ts --apply --approve
```

This writes proposals directly as `approved` instead of `pending`. Use this only for well-understood, low-risk patterns.

The Corrections → Analysis → Promotion pipeline (based on the Jozefiak corrections-loop pattern) ensures that:
- One-off corrections stay as data and don't create noise
- Recurring patterns graduate into actual behavior changes
- Every promotion is reviewable and reversible

## Related

- [How to analyze your data →](analyze-data.md)
- [Architecture and design decisions →](../explanation/architecture.md)

