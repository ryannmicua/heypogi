---
name: clarity-without-drift
description: Improve the readability of plans, specifications, requirements, and technical documents without changing their meaning, scope, decisions, authority boundaries, or implementation guidance. Use when refining content for human readers or AI implementation agents.
allowed-tools:
  - Read
  - Write
  - Edit
---

# Clarity Without Drift

Improve human readability without changing the document's semantic contract.

## When to Use This Skill

Use this skill when:

- Refining a plan, specification, requirements document, or technical guide
- Making a document easier for humans or AI agents to scan
- Reducing repetition, dense prose, or vague wording
- Reorganizing content without changing its meaning
- Improving headings, lists, tables, examples, or cross-references
- Making implementation guidance clearer while preserving technical precision

Do not use this skill to decide product scope, reopen settled decisions, or redesign an implementation plan. Use a planning or review skill for those tasks.

## Core Principle

Improve structure and expression, not meaning.

Readability is subordinate to semantic accuracy. A shorter or simpler sentence is not an improvement if it removes an actor, condition, exception, consequence, authority boundary, or uncertainty state.

## Preservation Contract

Before editing, identify the document's contract. Preserve these elements unless the user explicitly asks to change them:

- Frontmatter, identifiers, links, and publication metadata
- Requirements, acceptance criteria, examples, and success measures
- Decision IDs, decision-status metadata, rationales, and rejected alternatives
- Technical constraints, schemas, versions, paths, and protocol terms
- Actors, flows, states, transitions, dependencies, and sequencing
- Active scope, deferred scope, exclusions, and open questions
- Verification gates, test obligations, and Definition of Done items
- Authority, safety, security, attribution, and trust boundaries

Keep exact modal strength. Do not weaken or strengthen `must`, `must not`, `may`, `should`, `can`, or `does not`.

## Readability Principles

Apply these after extracting the preservation contract:

- Use active voice when the actor matters.
- Use definite, specific, concrete language.
- Omit words that add no meaning.
- Keep related words and conditions together.
- Give each paragraph one job and begin with its topic.
- Use parallel structure for parallel requirements, decisions, and steps.
- Place important qualifications close to the statements they qualify.
- Prefer short sentences, but do not split a rule if that separates its condition from its consequence.
- Use headings and lists to expose structure, not to decorate the document.
- Make execution order and dependencies explicit when the document is intended for agents.

## Technical Precision Overrides Style

Do not simplify wording when simplification would weaken precision.

Preserve:

- Negative safety rules such as "must not overwrite"
- Explicit actors, preconditions, states, effects, and consequences
- Distinctions such as `unsupported`, `unavailable`, `not checked`, `invalid`, and `unknown`
- Exact identifiers, paths, schemas, versions, and protocol names
- Rationale that explains an authority, security, or trust boundary
- The distinction between a review gate, fixture, manual check, and executable test

Do not convert a technical constraint into a slogan. Do not replace a precise term with a broader synonym merely because it sounds simpler.

## Avoid AI Writing Patterns

Remove:

- Puffery and promotional adjectives such as "groundbreaking," "seamless," and "robust"
- Empty gerund phrases such as "ensuring reliability" or "enabling consistency"
- Generic verbs such as "leverage" when a concrete verb is available
- Repeated conclusions and redundant framing
- Abstract claims where a concrete behavior would be clearer
- Excessive bolding, bullets, tables, or decorative sections

Prefer:

```text
The adapter writes the marker after confirmation.
The local link is replaceable.
An unknown marker version returns `unsupported`.
```

Avoid:

```text
The adapter facilitates a robust and seamless registration experience.
```

## Safe Structural Improvements

The following changes are usually safe when the preservation contract remains intact:

- Add a document map or short overview
- Separate rationale, requirements, design, execution, and verification
- Group related requirements under descriptive headings
- Convert repeated prose into a list or table
- Add explicit implementation order and dependency summaries
- Add cross-references between requirements, decisions, units, and tests
- Replace vague references such as "the above" with named sections or IDs
- Shorten duplicated explanations after preserving the strongest version
- Correct broken internal references when the intended target is unambiguous

When adding a summary, label it as a summary. Do not let it replace the authoritative detail.

## Workflow

### 1. Classify the Request

Determine whether the user wants:

- Readability refinement only
- Readability refinement plus structural reorganization
- A substantive content change
- A review or critique rather than an edit

If the request includes substantive changes, separate those changes from the readability pass and do not silently make them.

### 2. Build a Preservation Inventory

Read the complete document when possible and record:

- All numbered or named IDs
- All decisions and their status annotations
- All requirements and acceptance examples
- All file paths, schemas, versions, and dependencies
- All active, deferred, and excluded scope
- All verification and completion criteria
- All unresolved questions

For a large document, process one coherent section at a time, but perform the inventory and final consistency check against the full document.

### 3. Identify Readability Problems

Separate presentation problems from semantic problems. Look for:

- Missing orientation for new readers
- Headings that do not describe the section's job
- Long paragraphs containing multiple topics
- Requirements mixed with rationale or implementation detail
- Hidden dependencies or execution order
- Vague pronouns and unanchored references
- Repeated or contradictory wording
- Dense lists without grouping
- Terms used inconsistently

Do not resolve a genuine product or technical ambiguity by guessing. Preserve it as an open question or report it to the user.

### 4. Refine Conservatively

Make the smallest changes that improve scanning and comprehension. Prefer local edits and clear section boundaries over wholesale rewriting.

Use existing terminology unless a terminology correction is necessary. If a term must change, update all references and report the change.

### 5. Recheck for Drift

After editing, verify:

- Every preserved ID still exists and has the same role
- Every settled decision remains settled and traceable
- Every requirement retains its actor, condition, action, and consequence
- Every implementation unit retains its files, dependencies, and verification
- Active, deferred, and excluded scope remain distinct
- Modal strength and uncertainty states are unchanged
- Internal references, numbering, and dependency order are consistent
- No new technology, requirement, or promise was invented

### 6. Report the Result

Summarize:

- Readability improvements made
- Structural changes made
- Internal reference corrections
- Contract elements explicitly preserved
- Ambiguities left unresolved
- Validation performed

## Completion Criteria

The refinement is complete only when:

- The document is easier to scan than before.
- The original semantic contract is preserved.
- Settled decisions are not reopened.
- Requirements and acceptance examples retain their meaning.
- Implementation guidance remains actionable by an AI agent.
- Scope boundaries and deferred work remain visible.
- Technical terms, identifiers, and modal strength remain accurate.
- Internal references and dependency order are consistent.
- The final report distinguishes readability edits from substantive changes.
