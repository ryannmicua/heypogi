/**
 * Passive correction & preference detector.
 *
 * Based on the Jozefiak corrections-loop pattern:
 * deterministic classification → cheap capture → later graduation.
 *
 * Two detectors:
 *   - corrections: user pushback after an assistant response
 *   - preferences: user states preference unprompted (no prior assistant response)
 *
 * No LLM calls, no user action required.
 */

// ── Assistant response tracker (for correction detection) ──

const lastAssistantText = new Map<string, string>()
const lastToolName = new Map<string, string>()

export function trackAssistantResponse(sessionID: string, text: string) {
  lastAssistantText.set(sessionID, text)
}

export function trackToolCall(sessionID: string, toolName: string) {
  lastToolName.set(sessionID, toolName)
}

export function clearSession(sessionID: string) {
  lastAssistantText.delete(sessionID)
  lastToolName.delete(sessionID)
}

// ── Classification patterns (deterministic, shared by corrections + preferences) ──

type CorrectionKind = "skill_misuse" | "memory_update" | "behavioral" | "rule" | "preference"

type Rule = { re: RegExp; kind: CorrectionKind }

const RULES: Rule[] = [
  // skill_misuse: wrong tool, wrong approach
  { re: /don'?t (use|run|call|execute|install|edit|write|delete)/i, kind: "skill_misuse" },
  { re: /(use|run|call|try) .*(instead|rather)/i, kind: "skill_misuse" },
  { re: /not what I (asked|wanted|meant|said)/i, kind: "skill_misuse" },
  { re: /that'?s not (what|the|how|right)/i, kind: "skill_misuse" },

  // rule: hard constraints
  { re: /(must|should) never/i, kind: "rule" },
  { re: /never (use|do|run|modify|change|touch|delete)/i, kind: "rule" },
  { re: /always (use|do|run|check|verify|include)/i, kind: "rule" },
  { re: /(must|have to) (be|use|include|follow|respect)/i, kind: "rule" },

  // memory_update: new context, facts
  { re: /actually,? (it'?s|we'?re|the|our|this|that|i)/i, kind: "memory_update" },
  { re: /let me (clarify|add|correct|explain|update)/i, kind: "memory_update" },
  { re: /that'?s (not|incorrect|wrong|outdated)/i, kind: "memory_update" },

  // behavioral: tone, format, verbosity
  { re: /(too|less|more) (verbose|detailed|concise|brief|formal)/i, kind: "behavioral" },
  { re: /don'?t (explain|ask|tell|apologize|warn)/i, kind: "behavioral" },
  { re: /just (do|run|show|give|tell)/i, kind: "behavioral" },
  { re: /(no|stop) (explaining|asking|apologizing)/i, kind: "behavioral" },

  // preference: softer guidance
  { re: /i (prefer|'?d rather|like|want|like to)/i, kind: "preference" },
  { re: /(instead|rather than)/i, kind: "preference" },
  { re: /let'?s (not|try|do|focus|stick with)/i, kind: "preference" },
  { re: /(better|worse|cleaner|simpler) (to|if|when)/i, kind: "preference" },
]

function classify(text: string): CorrectionKind | null {
  for (const { re, kind } of RULES) {
    if (re.test(text)) return kind
  }
  return null
}

// ── Correction detection ──

const SIGNAL_PATTERNS = [
  /^(no|nah|nope|not|stop|wait|hold on|actually)/i,
  /^that'?s (not|wrong|incorrect|right|the)/i,
  /^(don'?t|do not|stop|never|always)/i,
  /^(i (prefer|meant|wanted|said|asked|'?d rather))/i,
  /^(let me (clarify|correct|rephrase|add))/i,
  /(instead|rather than)/i,
  /not what (i|we) /i,
  /(wrong|incorrect|mistake|error)/i,
]

function isLikelyCorrection(text: string): boolean {
  return SIGNAL_PATTERNS.some((re) => re.test(text.trim()))
}

export type Correction = {
  classification: string
  userText: string
  assistantContext: string | null
  toolContext: string | null
}

export function detectCorrection(
  sessionID: string,
  userText: string,
): Correction | null {
  const assistantCtx = lastAssistantText.get(sessionID)
  if (!assistantCtx) return null
  if (!isLikelyCorrection(userText)) return null

  const kind = classify(userText)
  if (!kind) return null

  const toolCtx = lastToolName.get(sessionID) ?? null

  // Consume context to avoid double-detection.
  lastAssistantText.delete(sessionID)
  lastToolName.delete(sessionID)

  return {
    classification: kind,
    userText,
    assistantContext: assistantCtx.slice(0, 2000),
    toolContext: toolCtx,
  }
}

// ── Non-correction preference detection ──
//
// Catches prompts where the user states a preference unprompted
// (no preceding assistant response to correct). Signals are lighter
// — we're looking for preference/rule language, not pushback.

const PREFERENCE_SIGNALS = [
  /^(i|we|my|our).*(prefer|like|want|'?d rather|need)/i,
  /^(can you|please|could you|would you) (always|never|make sure|ensure)/i,
  /^(my|our) preference/i,
  /^(let'?s|we should|we could) (always|never|stick|focus)/i,
  /(important|critical|crucial) that/i,
  /as a (rule|principle|general practice)/i,
]

export type Preference = {
  category: string
  userText: string
}

export function detectPreference(userText: string): Preference | null {
  // Skip if this was already detected as a correction
  // (preference detector is called after correction detector)
  // Just check: is there a prior assistant response?
  // If so, it might be a correction — skip to avoid double-counting.
  // But this is handled externally by the caller.

  if (!PREFERENCE_SIGNALS.some((re) => re.test(userText.trim()))) return null

  const kind = classify(userText)
  if (!kind) return null

  return {
    category: kind,
    userText,
  }
}
