#!/usr/bin/env python3
"""Validate an SME agent definition markdown file for required governance sections."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REQUIRED_SECTIONS = [
    "agent name",
    "domain",
    "purpose",
    "target users",
    "trusted knowledge sources",
    "source priority rules",
    "in-scope tasks",
    "out-of-scope tasks",
    "tools and integrations",
    "permissions",
    "decision rules",
    "escalation rules",
    "compliance and safety rules",
    "required output formats",
    "evaluation test cases",
    "maintenance plan",
]

RECOMMENDED_TERMS = [
    "escalate",
    "source",
    "permission",
    "risk",
    "review",
    "out-of-scope",
]


def normalize_heading(text: str) -> str:
    text = re.sub(r"^#+\s*", "", text.strip())
    text = re.sub(r"^\d+\.\s*", "", text)
    text = text.replace("&", "and")
    return re.sub(r"\s+", " ", text.lower()).strip()


def extract_headings(markdown: str) -> set[str]:
    headings: set[str] = set()
    for line in markdown.splitlines():
        if re.match(r"^#{1,6}\s+", line):
            headings.add(normalize_heading(line))
    return headings


def has_section(headings: set[str], required: str) -> bool:
    return any(required == heading or required in heading for heading in headings)


def validate(path: Path) -> int:
    if not path.exists():
        print(f"ERROR: file not found: {path}")
        return 2
    if not path.is_file():
        print(f"ERROR: path is not a file: {path}")
        return 2

    markdown = path.read_text(encoding="utf-8")
    headings = extract_headings(markdown)

    missing = [section for section in REQUIRED_SECTIONS if not has_section(headings, section)]
    missing_terms = [term for term in RECOMMENDED_TERMS if term not in markdown.lower()]

    if missing:
        print("FAIL: missing required sections")
        for section in missing:
            print(f"- {section}")
    else:
        print("PASS: all required sections found")

    if missing_terms:
        print("WARN: recommended governance terms not found")
        for term in missing_terms:
            print(f"- {term}")

    if not missing and not missing_terms:
        print("PASS: no common governance gaps detected")

    return 1 if missing else 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate an SME agent definition markdown file.")
    parser.add_argument("markdown_file", help="path to the SME agent definition markdown file")
    args = parser.parse_args()
    return validate(Path(args.markdown_file))


if __name__ == "__main__":
    sys.exit(main())
