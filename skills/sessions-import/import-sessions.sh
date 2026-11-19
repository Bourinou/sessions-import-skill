#!/usr/bin/env bash
# Imports Claude desktop Code-tab sessions from every other account into the current one (Linux/macOS).
# Same session in several places -> keeps the most advanced copy (lastActivityAt, then file time).
# Usage: import-sessions.sh [--dry-run] [--root DIR] [--account UUID] [--org UUID]
set -euo pipefail

target_account="${CLAUDE_CODE_ACCOUNT_UUID:-}"
target_org="${CLAUDE_CODE_ORGANIZATION_UUID:-}"
current="${CLAUDE_CODE_HOST_SESSION_ID:-}"
dry_run=0
roots=()

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) dry_run=1 ;;
        --root) roots+=("$2"); shift ;;
        --account) target_account="$2"; shift ;;
        --org) target_org="$2"; shift ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

[ -n "$target_account" ] && [ -n "$target_org" ] || { echo "Target account/org unknown: pass --account and --org." >&2; exit 1; }

if [ ${#roots[@]} -eq 0 ]; then
    shopt -s nullglob
    for d in "${XDG_CONFIG_HOME:-$HOME/.config}"/Claude*/claude-code-sessions \
             "${XDG_DATA_HOME:-$HOME/.local/share}"/Claude*/claude-code-sessions \
             "$HOME/Library/Application Support"/Claude*/claude-code-sessions; do
        roots+=("$d")
    done
    shopt -u nullglob
fi
[ ${#roots[@]} -gt 0 ] || { echo "No claude-code-sessions folder found: pass --root DIR." >&2; exit 1; }

# Progress of a session file in ms: first of lastActivityAt/lastTurnEdgeAt/createdAt, else file mtime.
progress() {
    local k v
    for k in lastActivityAt lastTurnEdgeAt createdAt; do
        v=$(grep -o "\"$k\":[0-9]*" "$1" | head -n 1 | cut -d: -f2 || true)
        [ -n "$v" ] && { echo "$v"; return; }
    done
    v=$(stat -c %Y "$1" 2>/dev/null || stat -f %m "$1")
    echo $((v * 1000))
}

for root in "${roots[@]}"; do
    target="$root/$target_account/$target_org"
    sources=$(find "$root" -mindepth 3 -maxdepth 3 -type f -name 'local_*.json' \
        ! -path "$root/$target_account/*" ! -path "$root/_import-backup/*")
    if [ -z "$sources" ]; then echo "[$root] no other account sessions"; continue; fi

    backup="$root/_import-backup/$(date +%Y%m%d-%H%M%S)"
    added=0 updated=0 kept=0 skipped=0
    [ $dry_run -eq 1 ] || mkdir -p "$target"

    # One line per file "name<TAB>progress<TAB>path", then keep the highest progress per name.
    best_list=$(while IFS= read -r f; do
            printf '%s\t%s\t%s\n' "${f##*/}" "$(progress "$f")" "$f"
        done <<< "$sources" | sort -t "$(printf '\t')" -k1,1 -k2,2nr | awk -F '\t' '!seen[$1]++')

    while IFS="$(printf '\t')" read -r name best_p best; do
        if [ -n "$current" ] && [ "$name" = "$current.json" ]; then skipped=$((skipped + 1)); continue; fi
        dst="$target/$name"
        if [ -e "$dst" ]; then
            if [ "$best_p" -le "$(progress "$dst")" ]; then kept=$((kept + 1)); continue; fi
            if [ $dry_run -eq 0 ]; then
                mkdir -p "$backup"
                cp -p "$dst" "$backup/$name"
                cp -p "$best" "$dst"
            fi
            updated=$((updated + 1)); echo "  updated: $name"
        else
            [ $dry_run -eq 1 ] || cp -p "$best" "$dst"
            added=$((added + 1))
        fi
    done <<< "$best_list"

    mode=$([ $dry_run -eq 1 ] && echo "DRY RUN" || echo "DONE")
    echo "[$mode] $root -> $target_account/$target_org : added $added, updated $updated (older copies backed up), already up to date $kept, current session skipped $skipped"
    if [ $updated -gt 0 ] && [ $dry_run -eq 0 ]; then echo "  backup: $backup"; fi
done
