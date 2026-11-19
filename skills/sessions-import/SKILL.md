---
name: sessions-import
description: Import the Claude desktop Code-tab sessions of every other account used on this computer into the current account, keeping the most advanced copy when a session exists in several accounts. Use when the user types /sessions-import or asks to import/merge sessions from another account.
---

# Import sessions from other accounts

Session metadata lives in `%LOCALAPPDATA%\Claude-Data\<app>\claude-code-sessions\<account>\<org>\local_*.json`
(conversations themselves are in `~/.claude/projects`, shared by all accounts, so only metadata is copied).
The current account/org come from `CLAUDE_CODE_ACCOUNT_UUID` / `CLAUDE_CODE_ORGANIZATION_UUID`.

1. Dry run, and show the user the summary line(s):
   ```
   powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.claude\skills\sessions-import\import-sessions.ps1" -DryRun
   ```
2. If nothing would be added or updated, say so and stop. Otherwise run it for real (same command without `-DryRun`).
   - New sessions are copied; a session present in both places is replaced only if the other copy is more advanced
     (`lastActivityAt`), and the replaced file is backed up under `claude-code-sessions\_import-backup\<date>`.
   - The running session's own file is never touched. Nothing is deleted from the other accounts.
3. Tell the user to fully quit Claude (tray icon → Quit) and reopen it: the app only reads the list at startup.
