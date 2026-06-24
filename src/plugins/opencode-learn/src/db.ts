import { Database } from "bun:sqlite"
import path from "path"
import fs from "fs/promises"
import os from "os"

const SCHEMA = `
CREATE TABLE IF NOT EXISTS project (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  directory TEXT NOT NULL UNIQUE,
  first_seen_at TEXT NOT NULL,
  last_seen_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS user_prompt (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER NOT NULL REFERENCES project(id),
  session_id TEXT NOT NULL,
  text TEXT NOT NULL,
  agent_refs TEXT,
  has_files INTEGER NOT NULL DEFAULT 0,
  delivery TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS assistant_response (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER NOT NULL REFERENCES project(id),
  session_id TEXT NOT NULL,
  assistant_message_id TEXT,
  text TEXT NOT NULL,
  agent TEXT,
  model TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS session_summary (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER NOT NULL REFERENCES project(id),
  session_id TEXT NOT NULL,
  text TEXT NOT NULL,
  recent TEXT,
  reason TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS tool_call (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER NOT NULL REFERENCES project(id),
  session_id TEXT NOT NULL,
  tool_name TEXT NOT NULL,
  input TEXT,
  success INTEGER NOT NULL,
  error_message TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS step (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER NOT NULL REFERENCES project(id),
  session_id TEXT NOT NULL,
  agent TEXT,
  model TEXT,
  finish TEXT,
  failed INTEGER NOT NULL DEFAULT 0,
  error_message TEXT,
  cost REAL,
  tokens_input INTEGER,
  tokens_output INTEGER,
  tokens_reasoning INTEGER,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS shell_command (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER NOT NULL REFERENCES project(id),
  session_id TEXT NOT NULL,
  command TEXT NOT NULL,
  output_snippet TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS agent_switch (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER NOT NULL REFERENCES project(id),
  session_id TEXT NOT NULL,
  agent TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS model_switch (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER NOT NULL REFERENCES project(id),
  session_id TEXT NOT NULL,
  model_id TEXT NOT NULL,
  provider_id TEXT NOT NULL,
  variant TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS retry (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER NOT NULL REFERENCES project(id),
  session_id TEXT NOT NULL,
  attempt INTEGER NOT NULL,
  error_message TEXT,
  error_status_code INTEGER,
  created_at TEXT NOT NULL
);

-- Corrections: detected when user pushes back on assistant output
CREATE TABLE IF NOT EXISTS correction (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER NOT NULL REFERENCES project(id),
  session_id TEXT NOT NULL,
  classification TEXT NOT NULL,
  user_text TEXT NOT NULL,
  assistant_context TEXT,
  tool_context TEXT,
  created_at TEXT NOT NULL,
  resolved INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_tool_call_project ON tool_call(project_id);
CREATE INDEX IF NOT EXISTS idx_tool_call_name ON tool_call(tool_name);
CREATE INDEX IF NOT EXISTS idx_session_summary_project ON session_summary(project_id);
CREATE INDEX IF NOT EXISTS idx_step_project ON step(project_id);
CREATE INDEX IF NOT EXISTS idx_user_prompt_project ON user_prompt(project_id);
CREATE INDEX IF NOT EXISTS idx_correction_project ON correction(project_id);
CREATE INDEX IF NOT EXISTS idx_correction_classification ON correction(classification);
CREATE INDEX IF NOT EXISTS idx_correction_resolved ON correction(resolved);

-- Permission requests & responses (allow/deny patterns)
CREATE TABLE IF NOT EXISTS permission (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER NOT NULL REFERENCES project(id),
  session_id TEXT NOT NULL,
  permission_type TEXT NOT NULL,
  patterns TEXT,
  tool_name TEXT,
  user_response TEXT,          -- "once", "always", "reject", or NULL if pending
  created_at TEXT NOT NULL,
  replied_at TEXT
);

-- File changes extracted from tool call inputs
CREATE TABLE IF NOT EXISTS file_change (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER NOT NULL REFERENCES project(id),
  session_id TEXT NOT NULL,
  tool_name TEXT NOT NULL,
  file_path TEXT NOT NULL,
  created_at TEXT NOT NULL
);

-- Non-correction preferences (user states preference unprompted)
CREATE TABLE IF NOT EXISTS preference (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER NOT NULL REFERENCES project(id),
  session_id TEXT NOT NULL,
  category TEXT NOT NULL,
  user_text TEXT NOT NULL,
  created_at TEXT NOT NULL
);

-- Proposed rules: candidates promoted from corrections/preferences
CREATE TABLE IF NOT EXISTS proposed_rule (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER REFERENCES project(id),
  classification TEXT NOT NULL,
  instruction TEXT NOT NULL,
  evidence TEXT,              -- JSON: example texts
  freq INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TEXT NOT NULL,
  reviewed_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_proposed_rule_status ON proposed_rule(status);
CREATE INDEX IF NOT EXISTS idx_permission_project ON permission(project_id);
CREATE INDEX IF NOT EXISTS idx_file_change_project ON file_change(project_id);
CREATE INDEX IF NOT EXISTS idx_preference_project ON preference(project_id);
`

export type ProjectRow = { id: number; directory: string }

let db: Database | null = null

export function getDB(): Database {
  if (db) return db
  const dir = path.join(os.homedir(), ".local", "share", "opencode-learn")
  fs.mkdir(dir, { recursive: true })
  db = new Database(path.join(dir, "learn.db"))
  db.exec("PRAGMA journal_mode=WAL")
  db.exec(SCHEMA)
  return db
}

export function ensureProject(directory: string): number {
  const d = getDB()
  const now = new Date().toISOString()
  const existing = d.query("SELECT id FROM project WHERE directory = ?").get(directory) as ProjectRow | null
  if (existing) {
    d.run("UPDATE project SET last_seen_at = ? WHERE id = ?", now, existing.id)
    return existing.id
  }
  const info = d.run("INSERT INTO project (directory, first_seen_at, last_seen_at) VALUES (?, ?, ?)", directory, now, now)
  return Number(info.lastInsertRowid)
}
