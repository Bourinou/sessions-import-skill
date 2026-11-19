# sessions-import-skill

A Claude Code skill for the Claude desktop app (Windows): import the Code-tab sessions of every other account used on this computer into the account you are signed in with.

| Skill | What it does |
|---|---|
| `/sessions-import` | Copies the session list of all other accounts into the current one. When a session exists in several accounts, keeps the most advanced copy (latest activity) and backs up the replaced file. Never touches the running session, never deletes anything. Dry run first, then import. |

Restart Claude (tray icon → Quit) after an import: the app reads the session list at startup.

## Install

```bash
git clone https://github.com/Bourinou/sessions-import-skill
cp -r sessions-import-skill/skills/* ~/.claude/skills/
```
