---
name: zeabur-github-deploy
description: >-
  Use when the user wants to publish a local project to a Zeabur server with
  GitHub-based three-way sync (local ↔ GitHub ↔ Zeabur, auto-redeploy on push).
  Triggers: "deploy this to Zeabur", "put my project on Zeabur with GitHub",
  "三端同步", "本地 GitHub Zeabur 同步", "set up git-push auto deploy on Zeabur",
  "deploy my static site / HTML demo to Zeabur". Orchestrates the existing
  zeabur:* skills in the correct order and adds the non-obvious gotchas that
  block first-time setups.
---

# Zeabur + GitHub three-way sync deploy

Set up **local ↔ GitHub ↔ Zeabur** so the user's only routine action is `git push`,
and Zeabur auto-redeploys on every push to `main`.

```
  ┌─ Local ───┐   git push    ┌─ GitHub ────┐  auto webhook  ┌─ Zeabur ────┐
  │ git repo  │ ────────────▶ │ private repo │ ─────────────▶ │ live URL    │
  └───────────┘ ◀──────────── │ (source)     │                └─────────────┘
                  git pull     └──────────────┘
```

This skill is an **orchestrator**. It calls the atomic `zeabur:*` skills
(`zeabur-auth`, `zeabur-server-catalog`, `zeabur-server-rent`,
`zeabur-project-create`, `zeabur-deploy`, `zeabur-domain-url`,
`zeabur-deployment-logs`) in the right sequence and supplies the sequencing
and gotchas those skills don't cover.

> **Always invoke the Zeabur CLI as `npx zeabur@latest …`.** Never `zeabur` directly.

## Scope

Works for **any** project Zeabur can build (it auto-detects Node, Python, Go,
Docker, etc.). The **tested, default** path is a **static HTML/front-end site**
(single `index.html` or a static folder) — Zeabur auto-detects `planType: static`
with no config file needed.

## Prerequisites

- The user is on **Claude Code** and has the **`zeabur` plugin** installed.
- **Homebrew** (macOS) or another way to install `gh` and `node`.
- A **GitHub account** and a **Zeabur account**.
- Renting a server costs money (see Part 1, step 5). **Never rent or enable
  billing without explicit user consent in chat.**

---

## Part 1 · One-time setup (per person / per machine)

Do this once. Subsequent projects (Part 2) skip all of it. Before each step,
**check whether it's already done** and skip if so — don't re-run blindly.

### 1. GitHub CLI: install, auth, AND wire git credentials

```bash
which gh || brew install gh
gh auth status        # skip login if already logged in
```

If not logged in, the login is **interactive** — the user must do it themselves
in a real terminal (the arrow-key menu needs a TTY):

> Ask the user to run `gh auth login` → GitHub.com → HTTPS → "Login with a web
> browser", and report back when it says "Logged in as …". Then **verify it
> persisted** with `gh auth status` (and `ls ~/.config/gh/`) before relying on it
> — a login done in a throwaway shell may not persist.

**CRITICAL gotcha:** `gh repo create --push` works, but a later plain `git push`
fails with *"Password authentication is not supported"* unless you wire git to
use gh's token:

```bash
gh auth setup-git     # makes `git push` use the gh credential helper
```

### 2. Node / npx (needed for the Zeabur CLI)

```bash
which npx || brew install node
npx --version
```

### 3. Zeabur login

Use the **`zeabur-auth`** skill. Run login directly — the CLI auto-opens the browser:

```bash
npx zeabur@latest auth status -i=false        # check first
npx zeabur@latest auth login                   # auto-opens browser if needed
```

### 4. Link GitHub to the Zeabur account (OAuth) — easy to miss

Installing the Zeabur **GitHub App** is **NOT** the same as **OAuth-linking** your
GitHub identity to your Zeabur account. If the account signed up with Google,
`githubID` is `null` and **`service search-repo` returns `[]` forever**, even with
the app installed.

Verify the link (token is in `~/.config/zeabur/cli.yaml`):

```bash
TOKEN=$(grep '^token:' ~/.config/zeabur/cli.yaml | awk '{print $2}')
curl -s https://api.zeabur.com/graphql -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query":"{ me { _id githubID } }"}'
# githubID must be a number, not null
```

If `githubID` is null, link it via the dashboard (browser, user does it):
**zeabur.com → 通用设置/Settings → 整合/Integrations → Github 账号 → 验证** →
authorize. You may drive this with the Claude-in-Chrome tools, but the final
**Authorize** click is an OAuth grant — let the **user** click it.

Also ensure the Zeabur GitHub **App** has access to the repo (private repos need it):
`https://github.com/apps/zeabur/installations/new` → grant the target repo (or all).

Re-verify with `npx zeabur@latest service search-repo <repo> --json -i=false`
— it should now return the repo with an `ID`.

### 5. Ensure a server exists (rent only if none) — costs money

Zeabur **deprecated free shared clusters**. Creating a project now requires a
**rented dedicated server**; the region code must be `server-<server-id>`.

**Reuse first** — list servers; if one already exists, use it for all new
projects (no new charge):

```bash
npx zeabur@latest server list -i=false --json
```

Only if the list is empty, rent one (use `zeabur-server-catalog` + `zeabur-server-rent`):

```bash
npx zeabur@latest server catalog -i=false      # pick provider/region/plan by price
```

**Before renting, surface the exact cost and get explicit consent.** Cheapest
options at time of writing: Tencent VPS ~$3–6/mo (Tokyo/Singapore $3, Hong Kong $6).
Billing is **postpaid** — a card or balance must exist at
**zeabur.com/account/billing** (browser step the user does) or rent/provision fails.

```bash
npx zeabur@latest server rent --provider <code> --region <id> --plan <name> -y -i=false --debug
```

**Gotcha:** the first `npx zeabur … rent` can hang on npx init with no output.
Run it with live output (background), and if it sits at 0% with no output for
>2–3 min, kill it and retry — the retry provisions normally. Wait for
`ProvisioningStatus: READY` / `VMStatus: RUNNING` via `server list`.

---

## Part 2 · Deploy a new project (repeatable, fast)

With Part 1 done, each new project is just this. Reuse the **existing** server.

### 1. Local git → private GitHub repo

```bash
cd <project-dir>
printf '.DS_Store\n.idea/\n.vscode/\n' > .gitignore
git init -b main && git add -A && git commit -m "Initial commit"
gh repo create <repo-name> --private --source=. --remote=origin --push
```

### 2. Create a Zeabur project ON THE EXISTING SERVER

Region MUST be `server-<server-id>` (get the id from `server list`). Use `zeabur-project-create`.

```bash
npx zeabur@latest project create -n "<name>" -r "server-<server-id>" -i=false --json
PROJECT_ID=$(npx zeabur@latest project list -i=false --json | jq -r '.[]|select(.Name=="<name>")|.ID')
```

Get the environment id (needed for the domain step). Read it from the project
dashboard URL `?envID=...`, or the API. Most deploy commands default to the first
environment if `--env-id` is omitted.

### 3. Git-deploy (auto-redeploy on push) — use `zeabur-deploy`

```bash
REPO_ID=$(npx zeabur@latest service search-repo <repo-name> --json -i=false | jq -r '.[0].ID')
npx zeabur@latest service deploy --json -i=false \
  --project-id $PROJECT_ID --template GIT --repo-id $REPO_ID \
  --branch-name main --name <name>
# returns the service id — save it
```

If `search-repo` is empty → go back to Part 1 step 4 (GitHub not linked).

### 4. Bind a free public domain — use `zeabur-domain-url`

```bash
npx zeabur@latest domain create -g=true --domain <prefix> \
  --id <service-id> --env-id <env-id> -y -i=false --json
# -> https://<prefix>.zeabur.app   (must include -g=true AND -i=false)
```

### 5. Test the push-to-live loop (proves three-way sync)

```bash
# add a harmless marker, e.g. <!-- sync-test --> in index.html
git add -A && git commit -m "sync test" && git push
# confirm a NEW deployment auto-triggered from the commit:
npx zeabur@latest deployment list --service-id <service-id> --env-id <env-id> -i=false --json
# then poll the URL until the marker appears:
until curl -s https://<prefix>.zeabur.app | grep -q "sync-test"; do sleep 5; done
```

A new `BUILDING` deployment whose `commitSHA` matches your push = webhook works.

### 6. Record the IDs in the project's `CLAUDE.md`

So future sessions don't re-discover them:

```markdown
## Zeabur Deployment
- Project ID / Environment ID / Service ID: …
- Server: <name> (id …, ip …)
- Public URL: https://<prefix>.zeabur.app
- Deploy type: Git (auto-redeploy on push to main)
```

---

## Gotchas (the real value — check here first when stuck)

| Symptom | Cause / Fix |
|---|---|
| `git push` → "Password authentication is not supported" | `gh` token not wired to git. Run **`gh auth setup-git`**. |
| `service search-repo` returns `[]` | Zeabur account not **OAuth-linked** to GitHub (`githubID: null`). Link via Settings → 整合 → Github → 验证. App install alone is not enough. |
| `gh auth status` says logged-out after the user "logged in" | Login ran in a throwaway/sandboxed shell. Re-run in a real terminal; verify `~/.config/gh/hosts.yml` exists. |
| `project create` fails / silent | Missing region, or "Shared clusters are deprecated." Must rent a server; region = `server-<server-id>`. Run with `--debug` to see the real error (plain/`--json` runs can swallow it). |
| Don't know valid region codes | Don't hardcode old codes. Use `server list` (region = `server-<id>`) or the catalog. |
| `domain create` opens an interactive prompt | Add **`-i=false`** and **`-g=true`** for a generated `.zeabur.app` domain. |
| `npx zeabur … rent` hangs with no output | npx init stall. Run with live output in background; kill after ~2–3 min idle and retry. |
| "rented successfully" but no balance/card | Postpaid: it accrues and later suspends/owes. Confirm balance/card at zeabur.com/account/billing. Never rent without explicit consent. |
| Static site won't build | Bare `index.html` is auto-detected as `planType: static`. No config needed; if a stack is misdetected, check `zeabur-deployment-logs`. |

## Interactive steps that REQUIRE the user (cannot be automated)

1. `gh auth login` (browser/TTY)
2. Zeabur GitHub **OAuth authorize** + App install (browser)
3. Adding a **payment method / balance** (browser)
4. **Consent to rent a paid server** (chat)

For each, hand the user the exact command/URL, wait for confirmation, then verify
from your side before continuing.
