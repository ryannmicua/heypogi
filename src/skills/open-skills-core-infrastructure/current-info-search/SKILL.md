---
name: current-info-search
description: Route web research through the Perplexity API for discovering current information instead of relying on stale training data. Use for anything that changes quickly -- releases, pricing, news, APIs, versions.
---

# Current-Information Search

Call the Perplexity API directly when the model's training data might be stale. The single most common failure mode in AI-assisted research is "confirming" outdated knowledge. Search results win over training data.

## Trigger Conditions

- Any question about recent or fast-moving information (releases, pricing, news, APIs, versions)
- Any claim the model makes that might be stale
- User asks "what's the latest..." or "is this still true..."
- Research that could be wrong if it's more than a few months old

## Setup

On first use, interview for:
- Where the Perplexity API key is stored (env file)
- Which Perplexity model to default to (suggest `sonar-pro` for deep research, `sonar` for quick lookups)

## API Request

```bash
curl https://api.perplexity.ai/chat/completions \
  -H "Authorization: Bearer $PERPLEXITY_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "<saved-default-model>",
    "messages": [
      {
        "role": "system",
        "content": "You are a research assistant. Answer concisely with dates and primary sources. When information is uncertain, say so."
      },
      {
        "role": "user",
        "content": "<user query>"
      }
    ]
  }'
```

## Citation Rules

1. **Cite dates** in answers built from search results: "As of March 2024, OpenCode v2.1..."
2. **Cite primary sources** when the search result names them: "According to the OpenCode changelog (github.com/...)..."
3. **Search results win** — when search results contradict the model's training data, the search results are authoritative

## When NOT to Use

- Purely conceptual questions ("explain how transformers work")
- Historical facts unlikely to have changed ("when was Python created")
- Questions the user explicitly says are about the model's knowledge, not current facts

## Preferences (Fill on Setup)

- **Default model**: `___`
- **API key location**: `___` (env file path, never inline)

## Optional: Wire as Default Search

If the harness supports hooks, wire this so all web searches route through Perplexity automatically. Otherwise, invoke explicitly when recency matters.

## Verification

Ask a question about something released in the last month. Run the search. Show the answer with sources.
