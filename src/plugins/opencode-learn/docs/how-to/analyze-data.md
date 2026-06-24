# How to Analyze Your Collected Data

Query the `learn.db` to understand your patterns, preferences, and workflow.

## Prerequisites

- The plugin has been running for at least a few sessions
- SQLite CLI (`sqlite3`) or any SQLite browser

## Quick Analysis Reports

Open the database:

```bash
sqlite3 ~/.local/share/opencode-learn/learn.db
```

### My Most-Used Tools

```sql
SELECT tool_name, count(*) AS uses,
       ROUND(avg(success) * 100, 1) AS success_rate
FROM tool_call
GROUP BY tool_name
ORDER BY uses DESC;
```

### My Session Costs Across Projects

```sql
SELECT p.directory,
       ROUND(SUM(s.cost), 2) AS total_cost,
       ROUND(AVG(s.tokens_input)) AS avg_input_tokens
FROM step s
JOIN project p ON p.id = s.project_id
GROUP BY p.directory
ORDER BY total_cost DESC;
```

### What Commands I Run Most

```sql
SELECT command, count(*) AS times_run
FROM shell_command
GROUP BY command
ORDER BY times_run DESC
LIMIT 20;
```

### Which Agents I Use

```sql
SELECT agent, count(*) AS switches
FROM agent_switch
GROUP BY agent
ORDER BY switches DESC;
```

### My @agent References in Prompts

```sql
SELECT agent_refs, count(*) AS mentions
FROM user_prompt
WHERE agent_refs IS NOT NULL
GROUP BY agent_refs
ORDER BY mentions DESC;
```

### What Permissions I Allow vs Deny

```sql
SELECT permission_type,
       user_response,
       count(*) AS times
FROM permission
WHERE user_response IS NOT NULL
GROUP BY permission_type, user_response
ORDER BY times DESC;
```

### Model Preferences Over Time

```sql
SELECT model_id, provider_id, count(*) AS sessions
FROM model_switch
GROUP BY model_id, provider_id
ORDER BY sessions DESC;
```

### Common Errors That Trigger Retries

```sql
SELECT error_message, count(*) AS freq
FROM retry
GROUP BY error_message
ORDER BY freq DESC
LIMIT 10;
```

### Corrections by Type

```sql
SELECT classification, count(*) AS freq
FROM correction
GROUP BY classification
ORDER BY freq DESC;
```

### Unprompted Preferences Stated

```sql
SELECT category, count(*) AS freq
FROM preference
GROUP BY category
ORDER BY freq DESC;
```

## Running the Built-in Analysis Tool

The plugin includes a CLI tool that clusters corrections and flags patterns ready for rule promotion:

```bash
cd ~/.opencode/plugins/opencode-learn
bun src/analyze.ts
```

This prints a markdown report to stdout. For recurring corrections (freq >= 2), it proposes concrete rule instructions.

## Advanced: NLP on Prompt Text

The `user_prompt.text` and `assistant_response.text` columns contain raw conversation text. Export them for external analysis:

```bash
sqlite3 ~/.local/share/opencode-learn/learn.db \
  "SELECT text FROM user_prompt" > prompts.txt
```

You can then run topic modeling, sentiment analysis, or style classification on these files.

## Related

- [How to promote corrections to rules →](promote-corrections.md)
- [Database schema reference →](../reference/db-schema.md)

