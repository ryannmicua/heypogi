#!/usr/bin/env python3
"""Validate that a software delivery artifact contains the expected headings.

This is a lightweight checklist helper for the software-delivery-architect skill.
It does not judge technical correctness.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REQUIRED_HEADINGS = {
    "standard_answer": [
        "Answer",
        "Basis",
        "Assumptions or Limitations",
        "Next Step",
    ],
    "technical_assessment": [
        "Technical Assessment",
        "Summary",
        "Current Understanding",
        "Evidence Reviewed",
        "Key Risks",
        "Options",
        "Recommendation",
        "Required Decisions",
        "Next Steps",
    ],
    "implementation_plan": [
        "Implementation Plan",
        "Goal",
        "Scope",
        "Non-Goals",
        "Assumptions",
        "Architecture Approach",
        "Work Breakdown",
        "Testing Plan",
        "Rollout Plan",
        "Rollback Plan",
        "Risks",
        "Open Questions",
    ],
    "code_review": [
        "Code Review",
        "Verdict",
        "Blocking Issues",
        "Non-Blocking Suggestions",
        "Tests Needed",
        "Security Considerations",
        "Suggested PR Comment",
    ],
    "bug_diagnosis": [
        "Bug Diagnosis",
        "Symptom",
        "Known Facts",
        "Likely Causes",
        "Evidence",
        "Recommended Fix",
        "Tests to Add",
        "Deployment Considerations",
    ],
    "architecture_decision": [
        "Architecture Decision Record",
        "Status",
        "Context",
        "Decision",
        "Alternatives Considered",
        "Consequences",
        "Risks",
        "Validation Plan",
        "Review Date",
    ],
    "delivery_readiness": [
        "Delivery Readiness Review",
        "Change Summary",
        "Requirements Status",
        "Test Status",
        "Migration Status",
        "Observability Status",
        "Rollback Status",
        "Security Review Status",
        "Documentation Status",
        "Support Readiness",
        "Final Recommendation",
    ],
}


def normalize_heading(text: str) -> str:
    return re.sub(r"\s+", " ", text.strip().lower())


def extract_headings(markdown: str) -> set[str]:
    headings = set()
    for line in markdown.splitlines():
        match = re.match(r"^#{1,6}\s+(.+?)\s*$", line)
        if match:
            headings.add(normalize_heading(match.group(1)))
    return headings


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("artifact", help="Path to markdown artifact to validate")
    parser.add_argument("--type", required=True, choices=sorted(REQUIRED_HEADINGS))
    args = parser.parse_args()

    path = Path(args.artifact)
    if not path.exists():
        print(f"ERROR: file not found: {path}")
        return 2

    markdown = path.read_text(encoding="utf-8")
    present = extract_headings(markdown)
    required = [normalize_heading(h) for h in REQUIRED_HEADINGS[args.type]]
    missing = [h for h in required if h not in present]

    if missing:
        print("FAIL: missing headings")
        for heading in missing:
            print(f"- {heading}")
        return 1

    print("PASS: required headings present")
    return 0


if __name__ == "__main__":
    sys.exit(main())
