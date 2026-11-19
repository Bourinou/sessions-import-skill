# sessions-import-skill

A Claude Code skill for the Claude desktop app (Windows, Linux including Arch, macOS): import the Code-tab sessions of every other account used on this computer into the account you are signed in with.

| Skill | What it does |
|---|---|
| `/sessions-import` | Copies the session list of all other accounts into the current one. When a session exists in several accounts, keeps the most advanced copy (latest activity) and backs up the replaced file. Never touches the running session, never deletes anything. Dry run first, then import. |

Windows uses `import-sessions.ps1` (PowerShell); Linux and macOS use `import-sessions.sh` (bash, coreutils, grep, awk only — nothing to install on Arch). If the session folder is not found, both scripts accept a root folder (`-Root` / `--root`).

Restart Claude after an import: the app reads the session list at startup.

## Install

```bash
git clone https://github.com/Bourinou/sessions-import-skill
cp -r sessions-import-skill/skills/* ~/.claude/skills/
```
