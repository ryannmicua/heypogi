# SME Agent Maintenance Checklist

## Ownership

- Assign an SME owner.
- Assign a technical or operations owner.
- Define who approves source changes.
- Define who reviews escalations and failed answers.

## Review cadence

Recommended defaults:

| Domain Risk | Review Cadence |
|---|---|
| Low | Quarterly |
| Medium | Monthly |
| High | Biweekly or monthly |
| Regulated/sensitive | Before launch and after every source change |

## Source maintenance

- Track authoritative source titles and owners.
- Remove or mark deprecated sources.
- Confirm new sources are approved before use.
- Check that source priority rules still apply.
- Retest after major source changes.

## Feedback loop

- Capture user corrections.
- Capture human expert overrides.
- Track escalations and why they occurred.
- Convert recurring failures into new test cases.
- Update examples when real usage changes.

## Audit checklist

- Did the agent cite or identify sources when required?
- Did it stay in scope?
- Did it avoid unauthorized actions?
- Did it escalate high-risk cases?
- Did it avoid storing or exposing unnecessary sensitive data?
- Did it use the expected output format?

## Revision record

Use this format:

| Version | Date | Change | Reason | Approved By |
|---|---|---|---|---|
| 0.1 |  | Initial draft |  |  |
