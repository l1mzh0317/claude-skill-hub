# claude-skill-hub  (brand: alpha137 内部工作台)

Static, data-driven internal workstation with three tabbed collections (all-Chinese UI, dark terminal theme):
- **技能 / Skills** — download & restore reusable Claude Code skills (`skills.json` + `skills/<name>/`).
- **演示 / Demos** — gallery of live deployed pages with screenshots (`demos.json` + `demos/<name>.jpg`).
- **服务 / Services** — internal online services launcher (`services.json`; currently empty → "服务陆续接入中" empty state).

Internal tool: external-facing bits (GitHub links, "restore anywhere", demo source links) are intentionally removed.
Built and deployed with the `zeabur-github-deploy` skill it hosts. Repo name stays `claude-skill-hub`.

## Three-way sync
Local git → GitHub (public, source of truth) → Zeabur auto-deploys on push to `main`.
- Add a skill: create `skills/<name>/` (+ `files.txt`), add an entry to `skills.json`, `git push`.
- Add a demo: screenshot the live page to `demos/<name>.jpg`, add an entry to `demos.json`, `git push`.
- Add a service: add an entry to `services.json` (`name/title/description/url/status/tags`), `git push`.
  (Find deployed sites + their domains via the Zeabur API: `project ... { services { name domains { domain } } }`.)

## GitHub
- Repo: https://github.com/l1mzh0317/claude-skill-hub (public)
- Branch: `main`

## Zeabur Deployment (reuses the shared HK server — no extra charge)
- Project ID: `6a250f56f1be9943f1f9a0ef`
- Environment ID: `6a250f5695b39806d284ac9b`
- Service ID: `6a250f91f1be9943f1f9a116`
- Server: Tencent Hong Kong 2C/2GB (shared, ID `6a24f81824701a8493345df4`)
- Public URL: https://claude-skill-hub.zeabur.app
- Deploy type: Git (auto-redeploy on push to `main`)

## Restore a skill anywhere
    curl -fsSL https://claude-skill-hub.zeabur.app/install.sh | bash -s <skill-name>
Writes only into `~/.claude/skills/<name>/`.
