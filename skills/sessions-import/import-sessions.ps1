# Imports Claude desktop Code-tab sessions from every other account into the current one.
# Same session in several places -> keeps the most advanced copy (lastActivityAt, then file time).
param(
    [string]$TargetAccount = $env:CLAUDE_CODE_ACCOUNT_UUID,
    [string]$TargetOrg = $env:CLAUDE_CODE_ORGANIZATION_UUID,
    [string]$CurrentSession = $env:CLAUDE_CODE_HOST_SESSION_ID,
    [string]$Root,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'

if (-not $TargetAccount -or -not $TargetOrg) { throw "Target account/org unknown: pass -TargetAccount and -TargetOrg." }

if ($Root) { $roots = @(Get-Item $Root) } else {
    $roots = @(Get-ChildItem "$env:LOCALAPPDATA\Claude-Data\*\claude-code-sessions" -Directory -ErrorAction SilentlyContinue) +
             @(Get-Item "$env:APPDATA\Claude\claude-code-sessions" -ErrorAction SilentlyContinue) | Where-Object { $_ }
}
if (-not $roots) { throw "No claude-code-sessions folder found: pass -Root DIR." }

function Get-Progress($file) {
    try {
        $j = Get-Content $file.FullName -Raw | ConvertFrom-Json
        foreach ($k in 'lastActivityAt', 'lastTurnEdgeAt', 'createdAt') { if ($j.$k) { return [double]$j.$k } }
    } catch { }
    return [double]([DateTimeOffset]$file.LastWriteTimeUtc).ToUnixTimeMilliseconds()
}

foreach ($root in $roots) {
    $target = Join-Path $root.FullName "$TargetAccount\$TargetOrg"
    $sources = Get-ChildItem $root.FullName -Directory | Where-Object { $_.Name -ne $TargetAccount -and $_.Name -ne '_import-backup' } |
        ForEach-Object { Get-ChildItem $_.FullName -Directory } |
        ForEach-Object { Get-ChildItem $_.FullName -File -Filter 'local_*.json' }
    if (-not $sources) { "[$($root.FullName)] no other account sessions"; continue }

    # Best copy per session id among the other accounts
    $best = @{}
    foreach ($f in $sources) {
        $p = Get-Progress $f
        if (-not $best.ContainsKey($f.Name) -or $p -gt $best[$f.Name].P) { $best[$f.Name] = @{ F = $f; P = $p } }
    }

    $backup = Join-Path $root.FullName "_import-backup\$(Get-Date -Format yyyyMMdd-HHmmss)"
    $added = 0; $updated = 0; $kept = 0; $skippedCurrent = 0
    if (-not $DryRun) { New-Item -ItemType Directory -Force $target | Out-Null }

    foreach ($name in $best.Keys) {
        if ($CurrentSession -and $name -eq "$CurrentSession.json") { $skippedCurrent++; continue }
        $src = $best[$name]; $dst = Join-Path $target $name
        if (Test-Path $dst) {
            if ($src.P -le (Get-Progress (Get-Item $dst))) { $kept++; continue }
            if (-not $DryRun) {
                New-Item -ItemType Directory -Force $backup | Out-Null
                Copy-Item $dst (Join-Path $backup $name)
                Copy-Item $src.F.FullName $dst -Force
            }
            $updated++; "  updated: $name"
        } else {
            if (-not $DryRun) { Copy-Item $src.F.FullName $dst }
            $added++
        }
    }
    $mode = if ($DryRun) { 'DRY RUN' } else { 'DONE' }
    "[$mode] $($root.FullName) -> $TargetAccount/$TargetOrg : added $added, updated $updated (older copies backed up), already up to date $kept, current session skipped $skippedCurrent"
    if ($updated -and -not $DryRun) { "  backup: $backup" }
}
