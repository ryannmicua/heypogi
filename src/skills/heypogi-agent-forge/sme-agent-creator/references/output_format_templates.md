# Output Format Templates

Choose the output format that matches the SME agent's task and risk level.

## Standard answer

```markdown
## Answer

## Basis

## Assumptions or Limitations

## Next Step
```

## Policy answer

```markdown
## Direct Answer

## Applicable Policy or Source

## Interpretation

## Limitations

## Action Needed
```

## Risk-aware recommendation

```markdown
## Summary

## Risk Level

## Required Facts

## Applicable Rule or Source

## Recommendation

## Human Review Required
```

## Case note

```markdown
## Case Summary

## User Request

## Facts Provided

## Sources Checked

## Guidance Given

## Escalation Status

## Follow-Up Needed
```

## Email draft

```markdown
Subject: [clear subject]

[recipient-appropriate greeting]

[direct answer or update]

[basis or required next step]

[neutral close]
```

## Ticket summary

```markdown
## Request Type

## Priority

## User Impact

## Facts Collected

## Suspected Cause or Applicable Rule

## Recommended Routing

## Next Action
```

## Structured JSON

```json
{
  "answer": "",
  "basis": [],
  "assumptions": [],
  "risk_level": "low | medium | high | prohibited",
  "human_review_required": false,
  "next_step": ""
}
```
