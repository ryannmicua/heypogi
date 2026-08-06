# Concepts

Shared domain vocabulary for this project — entities, named processes, and status concepts with project-specific meaning. Seeded with core domain vocabulary, then accretes as ce-compound and ce-compound-refresh process learnings; direct edits are fine. Glossary only, not a spec or catch-all.

## Dev Stack

### Dev Stack
The set of always-on developer tools this machine runs as npm CLIs rather than desktop applications — an agent runtime, a web UI server, and a headless agent daemon. "Dev Stack" names the trio together with the invariants they are expected to satisfy, not any one tool.

The stack is deliberately CLI-only: where a tool also ships a desktop app, the app may connect as a client but must not be the listening process, and must not manage its own daemon. Each component autostarts at login through its own mechanism.

### Supervisor
The single entry point that installs, verifies, repairs, and controls the whole Dev Stack, so no component is managed ad hoc.

The Supervisor is idempotent and has distinct read-only and mutating modes: checking the Intended State never changes it, while repair and install modes may restart daemons and register autostarts. Because it starts long-lived daemons in-process, the Supervisor is also responsible for the environment those daemons capture — see Session-Scoped Environment.

*Not to be confused with* the headless agent daemon's own internal supervisor process — see Flagged ambiguities.

### Intended State
The declared target configuration of the Dev Stack that the Supervisor verifies as a whole: every component current, installed as a CLI, listening on the expected interface, autostarting at login, and configured with the credentials remote access requires.

Intended State is a claim about the machine, not about the repo. Some of it comes from repo-held templates and some from manual, non-automatable steps (interactive password setup) — so a component can be correctly installed and still not be in Intended State.

### Session-Scoped Environment
Environment variables that exist only inside a running tool's process tree — injected by a parent process at startup rather than persisted to any user or machine setting — and are therefore inherited by everything that tool launches.

The distinguishing test is scope mismatch: a variable present in a live process but absent from the persisted settings is session-scoped, which identifies it as inherited and points at the launching process. A long-lived daemon started from inside such a session captures those variables permanently, and passes them to every process it later spawns; this is why the Supervisor strips them around daemon starts.

## Flagged ambiguities

- "Supervisor" is this project's word for the Dev Stack's entry point. Note that the headless agent daemon's own runtime process tree has been observed to use the same word for an internal process of its own — a vendor term, not project vocabulary. The glossary term always refers to the project's entry point.
