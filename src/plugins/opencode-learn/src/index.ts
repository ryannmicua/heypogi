import type { Plugin, Hooks } from "@opencode-ai/plugin"
import { getDB, ensureProject } from "./db"
import {
  trackAssistantResponse,
  trackToolCall,
  clearSession,
  detectCorrection,
  detectPreference,
} from "./corrections"

// Tools whose input may contain file paths.
const FILE_TOOLS = new Set(["read", "write", "edit", "apply_patch", "glob", "grep", "bash"])

/** Extract plausible file paths from tool input. */
function extractPaths(tool: string, input: Record<string, unknown>): string[] {
  if (tool === "read" || tool === "write" || tool === "edit" || tool === "apply_patch") {
    const fp = input["filePath"] ?? input["filepath"] ?? input["path"]
    if (typeof fp === "string") return [fp]
  }
  if (tool === "glob") {
    const pattern = input["pattern"]
    if (typeof pattern === "string") return [pattern]
  }
  if (tool === "grep") {
    const pattern = input["pattern"]
    if (typeof pattern === "string") return [pattern]
  }
  if (tool === "bash") {
    const cmd = input["command"] ?? input["cmd"]
    if (typeof cmd === "string") {
      // crude heuristic: extract flags that look like file paths
      const matches = [...cmd.matchAll(/(?:[-][-a-z]+\s+)(\S+)/gi)].map((m) => m[1])
      return matches.filter((m) => m.includes(".") || m.includes("/") || m.includes("\\"))
    }
  }
  return []
}

const plugin: Plugin = async (input) => {
  const projectID = ensureProject(input.directory)

  const buffer: Array<() => void> = []
  let timer: ReturnType<typeof setInterval> | null = null

  const flush = () => {
    const batch = buffer.splice(0)
    if (!batch.length) return
    const d = getDB()
    d.exec("BEGIN")
    for (const write of batch) write()
    d.exec("COMMIT")
  }

  const push = (write: () => void) => {
    buffer.push(write)
    if (!timer) timer = setInterval(flush, 2_000)
  }

  const lastToolPending = new Map<string, string>()

  const hooks: Hooks = {
    event: ({ event }) => {
      const p = event.properties as Record<string, unknown>
      const sessionID = (p?.sessionID ?? "") as string
      const ts = (p?.timestamp as number)
        ? new Date(p.timestamp as number).toISOString()
        : new Date().toISOString()

      switch (event.type) {
        // ── User prompts ──
        case "session.next.prompt.promoted": {
          const prompt = p?.prompt as { text: string; files?: unknown[]; agents?: Array<{ name: string }> } | undefined
          if (!prompt) break
          const userText = prompt.text

          push(() => {
            getDB().run(
              "INSERT INTO user_prompt (project_id, session_id, text, agent_refs, has_files, delivery, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
              projectID, sessionID,
              userText,
              prompt.agents ? JSON.stringify(prompt.agents.map((a) => a.name)) : null,
              prompt.files && prompt.files.length > 0 ? 1 : 0,
              (p?.delivery ?? "steer") as string,
              ts,
            )
          })

          // Try correction first (needs prior assistant response)
          const correction = detectCorrection(sessionID, userText)
          if (correction) {
            push(() => {
              getDB().run(
                "INSERT INTO correction (project_id, session_id, classification, user_text, assistant_context, tool_context, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
                projectID, sessionID, correction.classification, correction.userText,
                correction.assistantContext, correction.toolContext, ts,
              )
            })
            break
          }

          // If not a correction, check for unprompted preference
          const pref = detectPreference(userText)
          if (pref) {
            push(() => {
              getDB().run(
                "INSERT INTO preference (project_id, session_id, category, user_text, created_at) VALUES (?, ?, ?, ?, ?)",
                projectID, sessionID, pref.category, pref.userText, ts,
              )
            })
            break
          }
          break
        }

        // ── Assistant responses ──
        case "session.next.text.ended": {
          const e = p as { assistantMessageID: string; textID: string; text: string }
          trackAssistantResponse(sessionID, e.text)
          push(() => {
            getDB().run(
              "INSERT INTO assistant_response (project_id, session_id, assistant_message_id, text, created_at) VALUES (?, ?, ?, ?, ?)",
              projectID, sessionID, e.assistantMessageID, e.text, ts,
            )
          })
          break
        }

        // ── Session compactions ──
        case "session.next.compaction.ended": {
          const e = p as { sessionID: string; messageID: string; reason: string; text: string; recent?: string }
          push(() => {
            getDB().run(
              "INSERT INTO session_summary (project_id, session_id, text, recent, reason, created_at) VALUES (?, ?, ?, ?, ?, ?)",
              projectID, e.sessionID, e.text, e.recent ?? null, e.reason, ts,
            )
          })
          break
        }

        // ── Tool calls ──
        case "session.next.tool.called": {
          const e = p as { sessionID: string; tool: string; input: Record<string, unknown> }
          lastToolPending.set(sessionID, e.tool)

          // Extract file paths from tool input
          const paths = extractPaths(e.tool, e.input ?? {})
          if (paths.length) {
            for (const fp of paths) {
              push(() => {
                getDB().run(
                  "INSERT INTO file_change (project_id, session_id, tool_name, file_path, created_at) VALUES (?, ?, ?, ?, ?)",
                  projectID, e.sessionID, e.tool, fp, ts,
                )
              })
            }
          }

          push(() => {
            getDB().run(
              "INSERT INTO tool_call (project_id, session_id, tool_name, input, success, created_at) VALUES (?, ?, ?, ?, 0, ?)",
              projectID, e.sessionID, e.tool, JSON.stringify(e.input ?? {}), ts,
            )
          })
          break
        }
        case "session.next.tool.success": {
          const tool = lastToolPending.get(sessionID)
          if (tool) trackToolCall(sessionID, tool)
          lastToolPending.delete(sessionID)
          push(() => {
            getDB().run(
              `UPDATE tool_call SET success = 1
               WHERE session_id = ? AND id = (SELECT max(id) FROM tool_call WHERE session_id = ?)`,
              sessionID, sessionID,
            )
          })
          break
        }
        case "session.next.tool.failed": {
          const tool = lastToolPending.get(sessionID)
          if (tool) trackToolCall(sessionID, tool)
          lastToolPending.delete(sessionID)
          const e = p as { sessionID: string; error: { message: string } }
          push(() => {
            getDB().run(
              `UPDATE tool_call SET success = 0, error_message = ?
               WHERE session_id = ? AND id = (SELECT max(id) FROM tool_call WHERE session_id = ?)`,
              e.error.message, sessionID, sessionID,
            )
          })
          break
        }

        // ── Steps ──
        case "session.next.step.ended": {
          const e = p as {
            sessionID: string; agent: string; model: Record<string, unknown>
            finish: string; cost: number; tokens: { input: number; output: number; reasoning: number }
          }
          push(() => {
            getDB().run(
              "INSERT INTO step (project_id, session_id, agent, model, finish, cost, tokens_input, tokens_output, tokens_reasoning, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
              projectID, e.sessionID, e.agent ?? null, JSON.stringify(e.model), e.finish, e.cost, e.tokens.input, e.tokens.output, e.tokens.reasoning, ts,
            )
          })
          break
        }
        case "session.next.step.failed": {
          const e = p as { sessionID: string; error: { message: string } }
          push(() => {
            getDB().run(
              "INSERT INTO step (project_id, session_id, failed, error_message, created_at) VALUES (?, ?, 1, ?, ?)",
              projectID, e.sessionID, e.error.message, ts,
            )
          })
          break
        }

        // ── Shell commands ──
        case "session.next.shell.started": {
          const e = p as { sessionID: string; command: string }
          push(() => {
            getDB().run(
              "INSERT INTO shell_command (project_id, session_id, command, created_at) VALUES (?, ?, ?, ?)",
              projectID, e.sessionID, e.command, ts,
            )
          })
          break
        }

        // ── Agent switches ──
        case "session.next.agent.switched": {
          const e = p as { sessionID: string; agent: string }
          push(() => {
            getDB().run(
              "INSERT INTO agent_switch (project_id, session_id, agent, created_at) VALUES (?, ?, ?, ?)",
              projectID, e.sessionID, e.agent, ts,
            )
          })
          break
        }

        // ── Model switches ──
        case "session.next.model.switched": {
          const e = p as { sessionID: string; model: { id: string; providerID: string; variant?: string } }
          push(() => {
            getDB().run(
              "INSERT INTO model_switch (project_id, session_id, model_id, provider_id, variant, created_at) VALUES (?, ?, ?, ?, ?, ?)",
              projectID, e.sessionID, e.model.id, e.model.providerID, e.model.variant ?? null, ts,
            )
          })
          break
        }

        // ── Permission requests & responses ──
        case "permission.asked": {
          const e = p as {
            sessionID: string; permission: string; patterns: string[]
            tool?: { messageID: string; callID: string }
          }
          push(() => {
            getDB().run(
              "INSERT INTO permission (project_id, session_id, permission_type, patterns, tool_name, created_at) VALUES (?, ?, ?, ?, ?, ?)",
              projectID, e.sessionID, e.permission, JSON.stringify(e.patterns), e.tool?.callID ?? null, ts,
            )
          })
          break
        }
        case "permission.replied": {
          const e = p as { sessionID: string; requestID: string; reply: string }
          push(() => {
            getDB().run(
              `UPDATE permission SET user_response = ?, replied_at = ?
               WHERE session_id = ? AND id = (SELECT max(id) FROM permission WHERE session_id = ? AND user_response IS NULL)`,
              e.reply, ts, e.sessionID, e.sessionID,
            )
          })
          break
        }

        // ── Retries ──
        case "session.next.retried": {
          const e = p as { attempt: number; error: { message: string; statusCode?: number } }
          push(() => {
            getDB().run(
              "INSERT INTO retry (project_id, session_id, attempt, error_message, error_status_code, created_at) VALUES (?, ?, ?, ?, ?, ?)",
              projectID, sessionID, e.attempt, e.error.message, e.error.statusCode ?? null, ts,
            )
          })
          break
        }
      }
    },
    dispose: async () => {
      if (timer) clearInterval(timer)
      flush()
    },
  }

  return hooks
}

export default plugin
