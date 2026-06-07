# claude-skill-hub

Static, data-driven hub to download & restore reusable Claude Code skills.
Built and deployed with the `zeabur-github-deploy` skill it hosts.

## Three-way sync
Local git → GitHub (public, source of truth) → Zeabur auto-deploys on push to `main`.
Add a skill: create `skills/<name>/` (+ `files.txt` listing its files), add an entry to
`skills.json`, then `git push`.

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
