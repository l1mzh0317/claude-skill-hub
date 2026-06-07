# Claude Skill Hub

A tiny static site with two collections, switchable by tab:

- **Skills** — reusable [Claude Code](https://claude.com/claude-code) skills for download and one-line restore.
- **Demos** — a gallery of live web pages deployed to the server, each with a screenshot thumbnail.

**Live:** https://claude-skill-hub.zeabur.app

## Use a skill

Restore any skill onto a machine with one line:

```bash
curl -fsSL https://claude-skill-hub.zeabur.app/install.sh | bash -s zeabur-github-deploy
```

This downloads the skill's files into `~/.claude/skills/<name>/`. Nothing else is touched.

Or grab the file from the website and drop it into `~/.claude/skills/<name>/` yourself.

## How it works

Data-driven static site — no build step:

```
claude-skill-hub/
├── index.html       # tabbed UI: reads skills.json + demos.json
├── skills.json      # the skill catalog (metadata)
├── demos.json       # the demo gallery catalog (metadata)
├── install.sh       # one-line installer/restorer
├── skills/
│   └── <name>/
│       ├── files.txt   # this skill's file list (source of truth for install.sh)
│       └── SKILL.md    # the skill itself
└── demos/
    └── <name>.jpg      # screenshot thumbnail for a demo card
```

## Add a new skill

1. `mkdir skills/<name>/`, drop in `SKILL.md` (and any extra files).
2. List every file in `skills/<name>/files.txt` (one per line).
3. Add a metadata entry to `skills.json`.
4. `git push` — Zeabur auto-redeploys.

## Add a new demo

1. Screenshot the live page (e.g. headless Chrome: `chrome --headless=new --window-size=1280,720 --screenshot=demos/<name>.png <url>`), optimize to `demos/<name>.jpg`.
2. Add a metadata entry to `demos.json` (`title`, `description`, `url`, optional `repo`, `thumb`, `tags`).
3. `git push` — Zeabur auto-redeploys and the card appears under the **Demos** tab.

## Deployment

Local ↔ GitHub ↔ Zeabur three-way sync (auto-redeploy on push to `main`), set up with the `zeabur-github-deploy` skill that this hub itself hosts.
