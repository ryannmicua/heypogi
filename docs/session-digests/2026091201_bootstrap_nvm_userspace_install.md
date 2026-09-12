---
lorespec: "0.1"
id: "2026091201"
date: "2026-09-12"
source: "claude"
topic: "Bootstrap now installs nvm and Node.js LTS in user space instead of treating Node as an unprovisionable blocker"
tags: [nvm, nodejs, bootstrap, userspace, provisioning]
classification:
  type: technical
  domains: [devops, tooling, bootstrapping]
  value: medium
trails: [heypogi-bootstrap, heypogi-tooling]
---

## Session Arc

### Started
User asked whether bootstrap installs nvm. The answer was no - bootstrap assumed nvm was pre-installed and only verified Node.js existed.

### Pivots
- User requested bootstrap include nvm installation so Node/npm run in user space instead of from root
- User requested official nvm installation method via web search
- After research, user approved the git clone approach with reasoning comments explaining why it differs from the official curl script

### Ended
Bootstrap now provisions nvm + Node.js LTS in user space. The implementation uses git clone (not the official curl script) to avoid duplicate profile entries since setup-env.sh already manages profiles.

## ARTIFACTS

### A1: check-prereqs.sh nvm integration
- **What**: Modified `tooling/machine/check-prereqs.sh` to install nvm and Node.js LTS during the install phase
- **Key changes**:
  - Added `source_nvm()` - safely sources nvm.sh with --no-use
  - Added `install_nvm()` - clones nvm from GitHub (latest release tag)
  - Added `install_node_lts()` - installs Node LTS via `nvm install --lts`
  - Updated `check_node()` / `check_npm()` remediation messages
  - Reordered `do_install()` to install apt packages first, then nvm + Node, then verify
- **Location**: `tooling/machine/check-prereqs.sh`

### A2: bootstrap.sh comment update
- **What**: Updated Step 1 comment to reflect Node.js is now provisioned
- **Location**: `bootstrap/bootstrap.sh` line 431

## DECISIONS

### D1: Git clone instead of official curl script for nvm
- **Decision**: Use `git clone --branch <tag> --depth 1` instead of the official `curl -o- .../install.sh | bash`
- **Issue**: Official nvm install script modifies shell profiles (.bashrc, .profile, etc.)
- **Positions**:
  - Official curl script: handles everything but modifies profiles
  - Git clone: only installs nvm, no profile changes
- **Arguments**: heypogi's `setup-env.sh` already manages PATH and profile entries via `env-common.template`. Using curl would create duplicate nvm source lines in profiles.
- **Warrant**: heypogi's layered env setup means we should avoid tools that independently modify shell profiles
- **Qualifier**: in this case
- **Status**: settled

### D2: Query GitHub API for latest nvm version
- **Decision**: Use GitHub API to get latest release tag instead of using install.sh's internal version detection
- **Issue**: Need to determine latest nvm version without sourcing nvm internals
- **Warrant**: GitHub API is reliable and gives us the tag directly
- **Qualifier**: usually (falls back to master if offline)
- **Status**: settled

## INSIGHTS

### I1: nvm profile duplication risk
- **Statement**: The official nvm install script adds source lines to shell profiles, which would conflict with heypogi's existing env setup that already manages PATH and profile entries via `env-common.template`.
- **Source**: Web search of nvm official installation docs
- **Confidence**: high

## OPEN QUESTIONS

### Q1: nvm version pinning
- Current implementation uses `lts/*` (latest LTS) which stays current without manual updates
- Alternative: pin to a specific LTS version for reproducibility
- **Status**: accepted current approach (lts/*)

## NEXT STEPS

### NS1: Verify end-to-end bootstrap flow
- Run bootstrap install on a clean system to verify nvm + Node provisioning works with userspace-shims
- **Urgency**: soon

## Connections

- D1 —[informed_by]→ I1
- A1 —[depends_on]→ D1
- A1 —[depends_on]→ D2
- A2 —[related_to]→ A1
