# Bootstrap — Open Items

Things to address in bootstrap.sh.

## To Do

### bootstrap.sh

- [ ] Git config — set `user.name` and `user.email` (prompt or accept as args)
- [ ] Copy dev-stack.sh to `tooling/bin` and make executable
- [ ] Post-install verification — run each CLI with `--version` and confirm
- [ ] OpenChamber systemd service — decide if it should have one (Paseo does)

### cloud-init (heypogi-ai-dev-vm.yaml)

- [ ] Clone URL is placeholder — replace `yourusername` with actual

### Nice to have

- [ ] Non-interactive API key setup — accept `ANTHROPIC_API_KEY`, `OPENAI_API_KEY` as env vars or args
- [ ] SSH key generation for GitHub — optional, operator may prefer to bring their own

## Decisions Needed

- Should OpenChamber have a systemd service for always-on, or is it only started on-demand via dev-stack?
- Should git config be interactive (prompt) or accept `--git-name` / `--git-email` args?
