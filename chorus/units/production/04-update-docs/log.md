---
status: complete
started_at: "2026-03-13T14:39:02+08:00"
completed_at: "2026-03-13T14:41:14+08:00"
deviations: null
summary: Rewrote CLAUDE.md and README.md to reflect provider model, global config, and new CLI flags
---

# Execution Log

## What Was Done

- Rewrote CLAUDE.md:
  - Schema section: `backend:` top-level, `providers:` replaces `roles:`, `provider:` replaces `vault:` in credentials
  - Config files section: `~/.config/pcm/pcm.yml` as primary, `conf.d/` as optional
  - Architecture section: "Vault Roles" → "Providers" with new env var names
  - CLI Reference: flags `-u` and `-a` replace `-p` and `-c`
  - Env vars table: `PCM_PROVIDER_*` vars
  - Naming conventions: references to "accounts vault" instead of "credentials vault"
- Rewrote README.md:
  - "Roles" → "Providers" throughout
  - All credential examples use `provider:` not `vault:`
  - Flow diagram updated to show `provider: workspace`
  - Loading order includes `~/.config/pcm/pcm.yml` as first source
  - CLI flags updated to `-u` and `-a`
  - Env var table uses `PCM_PROVIDER_*`
  - Mise integration example uses `PCM_PROVIDER_WORKSPACE`
  - Backend section uses top-level `backend:` not `defaults.backend`
  - Design Principles: "Providers over vault names"

## Test Results

- `grep -c 'VAULT_ROLE' CLAUDE.md` — 0 matches
- `grep -c 'VAULT_ROLE' README.md` — 0 matches
- `grep 'provider:' CLAUDE.md` — shows credential definitions use `provider:`
- `grep 'providers:' CLAUDE.md` — shows providers section
- README.md loading order lists `~/.config/pcm/pcm.yml` first
- README.md CLI reference shows `-u` and `-a` flags

## Notes

None.

## Context Updates

- CLAUDE.md and README.md are now fully aligned with the provider model.
- All documentation references use `providers:`, `provider:`, `PCM_PROVIDER_*`, and `-u`/`-a` flags.
- No legacy `roles:`, `vault:` (in credential context), `PCM_VAULT_ROLE_*`, or `-p`/`-c` references remain in docs.
