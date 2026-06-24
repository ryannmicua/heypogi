#!/usr/bin/env bun
/**
 * correction-to-rule promotion tool.
 *
 * Usage:
 *   bun src/analyze.ts                    # dry-run report to stdout
 *   bun src/analyze.ts --apply            # write proposals to DB
 *   bun src/analyze.ts --apply --approve  # auto-approve (use with caution)
 *
 * Pipeline:
 *   1. Load unresolved corrections, cluster by classification + normalized text
 *   2. Flag items with freq >= 2 as "graduate candidates"
 *   3. Produce a markdown report
 *   4. With --apply: write proposals to proposed_rule table, mark corrections resolved
 */

import { getDB } from "./db"

type Cluster = {
  classification: string
  normalized: string
  examples: string[]
  freq: number
  sessions: string[]
  toolContexts: string[]
  correctionIDs: number[]
}

function normalize(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, "")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 120)
}

function loadClusters(): Cluster[] {
  const d = getDB()
  const rows = d.query(`
    SELECT id, classification, user_text, session_id, tool_context
    FROM correction
    WHERE resolved = 0
    ORDER BY created_at DESC
  `).all() as Array<{
    id: number
    classification: string
    user_text: string
    session_id: string
    tool_context: string | null
  }>

  const map = new Map<string, Cluster>()

  for (const row of rows) {
    const key = `${row.classification}::${normalize(row.user_text)}`
    let cluster = map.get(key)
    if (!cluster) {
      cluster = {
        classification: row.classification,
        normalized: normalize(row.user_text),
        examples: [],
        freq: 0,
        sessions: [],
        toolContexts: [],
        correctionIDs: [],
      }
      map.set(key, cluster)
    }
    cluster.freq++
    cluster.correctionIDs.push(row.id)
    if (cluster.examples.length < 3) cluster.examples.push(row.user_text)
    if (!cluster.sessions.includes(row.session_id)) cluster.sessions.push(row.session_id)
    if (row.tool_context && !cluster.toolContexts.includes(row.tool_context)) {
      cluster.toolContexts.push(row.tool_context)
    }
  }

  return Array.from(map.values()).sort((a, b) => b.freq - a.freq)
}

// ── Renderers ──

function renderRuleProposal(cluster: Cluster): string {
  const lines: string[] = []
  const tag = {
    rule: "Rule",
    preference: "Preference",
    behavioral: "Behavioral",
    skill_misuse: "Skill Correction",
    memory_update: "Context Correction",
  }[cluster.classification] ?? cluster.classification

  lines.push(`- **${tag}** (×${cluster.freq}):`)

  for (const ex of cluster.examples) {
    lines.push(`  - "${ex.slice(0, 160)}"`)
  }

  if (cluster.toolContexts.length) {
    lines.push(`  - tools: ${cluster.toolContexts.join(", ")}`)
  }

  return lines.join("\n")
}

function suggestInstruction(cluster: Cluster): string {
  const ex = cluster.examples[0]
  const kind = cluster.classification

  if (kind === "rule") {
    return `[Rule] ${ex.slice(0, 240)}`
  }
  if (kind === "preference") {
    return `[Preference] ${ex.slice(0, 240)}`
  }
  if (kind === "behavioral") {
    return `[Behavioral] ${ex.slice(0, 240)}`
  }
  if (kind === "skill_misuse") {
    return `[Skill] ${ex.slice(0, 240)}`
  }
  if (kind === "memory_update") {
    return `[Context] ${ex.slice(0, 240)}`
  }
  return ex.slice(0, 240)
}

// ── Report ──

function generateReport(clusters: Cluster[]): string {
  const graduates = clusters.filter((c) => c.freq >= 2)
  const singles = clusters.filter((c) => c.freq < 2)

  const total = clusters.reduce((s, c) => s + c.freq, 0)
  const report: string[] = []

  report.push("# Correction Analysis Report")
  report.push(`Generated: ${new Date().toISOString()}`)
  report.push("")
  report.push(`**${total}** total corrections, **${clusters.length}** unique patterns, **${graduates.length}** graduate candidates`)
  report.push("")

  if (graduates.length) {
    report.push("## Graduate Candidates (freq ≥ 2)")
    report.push("")
    report.push("These recurred and are ready for human review:")
    report.push("")
    for (const c of graduates) {
      report.push(renderRuleProposal(c))
      report.push("")
      report.push("  ```")
      report.push(`  ${suggestInstruction(c)}`)
      report.push("  ```")
      report.push("")
    }
  }

  report.push("## Singles (freq = 1)")
  report.push("")
  if (singles.length) {
    for (const c of singles) {
      report.push(renderRuleProposal(c))
    }
  } else {
    report.push("_(none)_")
  }

  report.push("")
  report.push("## Summary by Category")
  report.push("")
  const byKind = new Map<string, number>()
  for (const c of clusters) byKind.set(c.classification, (byKind.get(c.classification) ?? 0) + c.freq)
  for (const [kind, count] of byKind) report.push(`- ${kind}: ${count}`)

  return report.join("\n")
}

// ── Apply: write proposals to DB ──

function applyProposals(clusters: Cluster[], autoApprove: boolean) {
  const d = getDB()
  const graduates = clusters.filter((c) => c.freq >= 2)
  let written = 0

  d.exec("BEGIN")

  try {
    for (const c of graduates) {
      const status = autoApprove ? "approved" : "pending"
      const existing = d.query(
        "SELECT id FROM proposed_rule WHERE classification = ? AND normalized = ? AND status = 'pending'",
      ).get(c.classification, c.normalized) as { id: number } | null

      if (existing) {
        // Update: bump frequency, add new evidence
        d.run(
          `UPDATE proposed_rule SET freq = ?, evidence = ?, reviewed_at = ?
           WHERE id = ?`,
          c.freq,
          JSON.stringify({ examples: c.examples, toolContexts: c.toolContexts }),
          autoApprove ? new Date().toISOString() : null,
          existing.id,
        )
      } else {
        d.run(
          `INSERT INTO proposed_rule (classification, instruction, evidence, freq, status, created_at ${autoApprove ? ", reviewed_at" : ""})
           VALUES (?, ?, ?, ?, ?, ? ${autoApprove ? ", ?" : ""})`,
          c.classification,
          suggestInstruction(c),
          JSON.stringify({ examples: c.examples, toolContexts: c.toolContexts }),
          c.freq,
          status,
          new Date().toISOString(),
          ...(autoApprove ? [new Date().toISOString()] : []),
        )
      }

      // Mark corrections as resolved
      for (const id of c.correctionIDs) {
        d.run("UPDATE correction SET resolved = 1 WHERE id = ?", id)
      }

      written++
    }

    d.exec("COMMIT")
    console.log(`Wrote ${written} proposals (${autoApprove ? "auto-approved" : "pending review"}).`)
  } catch (err) {
    d.exec("ROLLBACK")
    throw err
  }
}

// ── Main ──

const args = process.argv.slice(2)
const shouldApply = args.includes("--apply")
const autoApprove = args.includes("--approve")

const clusters = loadClusters()

if (shouldApply) {
  applyProposals(clusters, autoApprove)
} else {
  console.log(generateReport(clusters))
}
