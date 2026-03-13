---
objective: Clean, consistent, RESTful CLI API
status: complete
depends_on: platform
---

Cleanup tier — API restructuring.

Consolidates the CLI surface into four resource groups with consistent REST
verbs and singular nouns. Drops orphaned top-level commands, hides internal
commands, and ensures every advertised command has a clear scope.

## Design Decisions

**Four resource groups (singular nouns):**
- `credential` — project-scoped, operates on merged config for $PWD
- `vault` — backend-scoped, interacts with the password manager
- `plugin` — registry-scoped, browse and add plugins
- `cache` — local device, manages cached SA tokens

**Consistent REST verbs:**
- `list` — index all resources
- `show` — read details for one resource
- `get` — fetch actual secret value from backend (credential only)
- `create` — create a new resource (vault only)
- `add` — add a resource to the project (plugin only)
- `validate` — check resource state (credential only)
- `clear` — remove a resource (cache only)

**Dropped commands:**
- `pcm get` (top-level) → `pcm credential get`
- `pcm new` → `pcm plugin add` covers it
- `pcm list` (top-level) → redundant with `pcm credential validate`
- `pcm token` → `pcm cache`
- `pcm init` → `pcm plugin add`

**Hidden commands (functional but not in help/completions):**
- `pcm completions <shell>`
- `pcm remote-env`

**Renamed:**
- `credentials` → `credential` (singular)
- `plugins` → `plugin` (singular)
- `token` → `cache`
- `plugins available` → `plugin list`
- `init <plugin>` → `plugin add <name>`
- `token get` → `cache show`

## Target API

```
pcm credential list
pcm credential show <name>
pcm credential get <name>
pcm credential get <name/field>
pcm credential validate [--fix [-y]]

pcm vault list
pcm vault show <name>
pcm vault create <name>

pcm plugin list [--installed]
pcm plugin show <name>
pcm plugin add <name>

pcm cache list
pcm cache show [vault]
pcm cache clear [vault]

pcm config
pcm update
pcm help
```

## Completion Criteria

- All four resource groups implemented with correct verbs
- All singular nouns (credential, vault, plugin, cache)
- No orphaned top-level commands (get, list, init, new, validate, token)
- `completions` and `remote-env` hidden from help and completions
- `pcm help` shows clean, grouped output
- Shell completions updated
- CLAUDE.md and README.md reflect final API
- Plugin credential definitions use `pcm credential get` in .env.schema
