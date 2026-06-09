---
name: vault-mcp
description: >-
  Use when the user wants to persist session context, create context sets
  (上下文集), save/retrieve reference documents, or manage long-term project
  memory in the remote vault MCP server. Triggers: "save to vault", "create
  context set", "mount context", "summarize session", "context集", "设定集",
  "vault", "挂载上下文". The vault is an HTTP MCP server at
  longku-vault.zeabur.app — all interactions go through its tools, never direct
  file writes.
---

# Vault MCP — Remote Document & Context Server

**URL:** `https://longku-vault.zeabur.app/mcp`
**Auth:** Bearer token in `~/.claude/mcp.json`
**Protocol:** HTTP MCP (JSON-RPC over POST)

## Overview

The vault is a **remote persistent document store** for Claude sessions.
Instead of context drifting across sessions or living only in local memory files,
the vault holds:

- **Session transcripts** — full conversation logs under `sessions/<project>/<session-id>`
- **Reference docs** — any markdown content the user wants persisted (summaries, decisions, specs)
- **Context sets** — named collections of docs that can be mounted into a session at once

All vault tools are called as MCP `tools/call` with `{ name, arguments }`.
The server is stateless HTTP — each request is a JSON-RPC POST.

## When to Use

- User asks to save/summarize a session to the vault
- User wants to create or update a context set (上下文集)
- User asks to mount/load context ("挂载上下文")
- User wants to search or browse past session knowledge
- After finishing a significant piece of work — persist the learnings
- When starting a new task that references past work stored in vault

## When NOT to Use

- For local-only notes that don't need cross-session persistence → use local memory files
- For project-specific conventions → put in CLAUDE.md
- When the vault is unreachable → report the error, don't silently skip

## Tool Reference

### Reading & Discovery

| Tool | Args | Returns |
|------|------|---------|
| `list_folders` | `{}` | All folder paths |
| `list_docs` | `{ folder?: string }` | Doc paths in folder (omit for root) |
| `find_docs` | `{ query: string }` | Docs matching name search |
| `read_doc` | `{ path: string, face: "human"\|"agent" }` | Document content |
| `list_contexts` | `{}` | All context sets with member count + token estimate |
| `get_context` | `{ name: string }` | Concatenated markdown of all enabled members |

### Writing & Mutating

| Tool | Args | Returns |
|------|------|---------|
| `write_doc` | `{ path: string, content: string }` | `{ ok, path }` |
| `delete_doc` | `{ path: string }` | Soft-delete (recycle bin) |
| `move_doc` | `{ from: string, to: string }` | Rename or move |
| `copy_doc` | `{ from: string, to: string }` | Duplicate doc or folder |
| `create_context` | `{ name: string, face: "human"\|"agent", members: [{path, kind, enabled}] }` | `{ ok, name }` |

### `read_doc` face parameter

- `"human"` — Readable transcript format (for user review)
- `"agent"` — Agent-optimized format (for loading into context). May return "not found" if only human-face content exists.

### `create_context` members

Each member is `{ path: "sessions/...", kind: "doc"|"folder", enabled: bool }`.
When `get_context` is called, all **enabled** members are concatenated into one markdown
string. Use folders to include all docs within them.

## Folder Conventions

```
sessions/                        # All session transcripts live here
  <project>/                     # Per-project grouping (e.g. alpha137, cryoACE)
    <session-id>                 # One doc per session (8-char hex id)
  YYYY-MM-DD/                    # Date-based folder for daily summaries
    <topic>                      # Named reference docs
```

- **Session transcripts:** `sessions/<project>/<session-id>` — auto-saved by the vault system
- **Daily summaries:** `sessions/YYYY-MM-DD/summary` — manually created
- **Topic docs:** `sessions/YYYY-MM-DD/<topic>` — specific feature/bug/decision writeups
- **Context sets** live in their own namespace — not under `sessions/`

## Core Workflows

### Workflow 1: Save today's session as context

After a productive session, persist the key learnings:

1. Summarize what was done (commits, decisions, bugs, lessons)
2. `write_doc` to `sessions/YYYY-MM-DD/<topic>` for each distinct piece
3. `write_doc` to `sessions/YYYY-MM-DD/summary` for the overall day
4. `create_context` to bundle these docs + relevant past session transcripts
5. Report what was saved and the context set name

### Workflow 2: Mount a context set into current session

When the user or task references past work:
1. `list_contexts` to see available sets
2. `get_context` with the relevant name
3. The returned markdown becomes working context — cite it when using the knowledge

### Workflow 3: Search for past knowledge

1. `find_docs` with keywords related to the topic
2. `read_doc` on the most relevant hits (use `face: "human"` for browsing)
3. Synthesize findings for the current task

### Workflow 4: Update an existing context set

1. `list_contexts` to confirm it exists
2. `create_context` with the same name + updated members list — it overwrites
3. New sessions mounting this context get the updated set

## Common Patterns

### Browsing session transcripts efficiently

Sessions can be thousands of lines. To find the key parts:
- `read_doc` returns full content — pipe through `tail -N` or `grep` locally
- Look for "## assistant" headers for agent responses (actual work output)
- The tail of a session transcript usually contains the verification/deploy section

### Interacting via Python when shell quoting is tricky

For docs with special characters (backticks, quotes, `$`), use a Python heredoc:

```bash
python3 << 'PYEOF'
import json, urllib.request

def vault(method, args):
    data = json.dumps({
        "jsonrpc": "2.0", "id": 1, "method": "tools/call",
        "params": {"name": method, "arguments": args}
    }).encode()
    req = urllib.request.Request(
        "https://longku-vault.zeabur.app/mcp",
        data=data,
        headers={
            "Authorization": "Bearer <token>",
            "Content-Type": "application/json"
        }
    )
    return json.loads(urllib.request.urlopen(req))

result = vault("write_doc", {"path": "...", "content": "..."})
print(result)
PYEOF
```

### Reading the auth token

```bash
cat ~/.claude/mcp.json | python3 -c "import sys,json; print(json.load(sys.stdin)['mcpServers']['vault']['headers']['Authorization'].split()[-1])"
```

## Gotchas

| Symptom | Cause / Fix |
|---|---|
| `read_doc` with `face: "agent"` returns "not found" | Only human-face content exists for that doc. Use `face: "human"`. |
| `write_doc` to a new subfolder | Folder is auto-created. No need to `mkdir` first. |
| Context set `tokens: 0` after creation | Token count is computed lazily — mount it once to trigger calculation. |
| `create_context` with same name | Overwrites the existing context set. This is the update path. |
| Shell escaping fails on markdown content | Use Python heredoc (`python3 << 'PYEOF'`) instead of inline curl. |
| Vault unreachable / timeout | The server is on Zeabur. If down, write content locally and retry later. Report to user. |

## Context Set Design

A good context set bundles related knowledge so future sessions can mount it in one call:

- **Include:** session summaries, design decisions, bug fixes with root causes, gotchas
- **Exclude:** raw full-length transcripts (too large), trivial/exit sessions, duplicate starts
- **Naming:** kebab-case, descriptive (`mirrorsea-dev`, `cryoACE-modeling`)
- **Reuse:** a context set is living — update it as the project evolves
- **Face:** use `"agent"` for sets intended for Claude consumption, `"human"` for review
