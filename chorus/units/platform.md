---
objective: You can build on it
status: complete
depends_on: production
---

Platform tier — Validate, generate, and provision credentials.

Adds the ability for PCM to not just read credentials but to create them.
`pcm validate` checks that all credentials for the current project exist in
the backend, generates values where authorized, prompts the user where not,
and creates the missing items.

## Key Design Decisions

- **Item-level creation, not field-level patching.** When an item is entirely
  missing, PCM collects all field values and creates the item in one call.
  When an item exists but a field is missing, PCM reports it but does not
  attempt to edit — that's deferred to a future enhancement.
- **Backend-agnostic types.** Credential definitions declare a generic `type:`
  (e.g., `secret`, `api`, `login`) that the backend maps to its native
  category. The PCM schema never references 1Password-specific categories.
- **`generate:` implies authority.** If a field has a `generate:` spec, PCM
  is authorized to create that value. No separate `authority:` boolean needed.
- **One generate type to start:** `password` with configurable `length`.
  More types added as backend capabilities are investigated.
- **Prefix guard.** Any command that resolves credentials with a prefix
  requires the prefix env vars to be set. This is enforced globally, not
  per-command.
- **Idempotent.** Running `pcm validate` twice does nothing the second time.
  Generated values are not rotated.

## Completion Criteria

- `_pcm_item_exists` added to backend interface and implemented in `op.sh`
- `_pcm_create_item` works with generic type-to-category mapping in `op.sh`
- `pcm validate` checks all credentials for the current project
- Missing items with `generate:` fields are created automatically
- Missing items without `generate:` prompt the user for values
- Items that exist but have missing fields are reported (not patched)
- Prefix env vars are validated before any credential resolution
- `pcm validate` is idempotent
- Backend type mapping documented
