---
status: complete
started_at: "2026-03-13T14:36:44+08:00"
completed_at: "2026-03-13T14:37:51+08:00"
deviations: null
summary: Added ~/.config/pcm/pcm.yml as primary global config, consolidated conf.d files, updated install.sh
---

# Execution Log

## What Was Done

- Added Phase 0 to `_build_config`: loads `~/.config/pcm/pcm.yml` before `conf.d/`
- Updated schema comment and header comment to document 3-phase loading order
- Updated `cmd_config` to show `pcm.yml` as first source in merge order
- Updated `cmd_help` to show new loading order
- Created `~/.config/pcm/pcm.yml` consolidating vaults.yml, gh.yml, and aws.yml
- Removed `~/.config/pcm/conf.d/vaults.yml`, `gh.yml`, and `aws.yml`
- Kept `conf.d/` directory intact for optional future use
- Updated `install.sh` to create `pcm.yml` with starter template instead of just `conf.d/`

## Test Results

- Debug output shows: "Loading global config: ~/.config/pcm/pcm.yml" first
- `pcm config` lists `~/.config/pcm/pcm.yml` as first source
- `pcm credentials list` shows gh and aws
- `pcm vault list` shows correct provider mappings
- `conf.d/` directory is empty

## Notes

None.

## Context Updates

- Primary global config is now `~/.config/pcm/pcm.yml`, loaded before `conf.d/` fragments.
- Loading order: `pcm.yml` → `conf.d/*.yml` → walked `.pcm.yml` files.
- `conf.d/` directory is still supported but optional — users can split config if preferred.
- `install.sh` now creates `pcm.yml` with a starter template on fresh install.
