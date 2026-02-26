# Purge repos above a star threshold from the database
# Removes: analyses, readmes, repo_query_links, and repos rows

param(
    [int]$MaxStars = 500,
    [switch]$DryRun = $false
)

# Load DB path from .env
$envFile = Join-Path $PSScriptRoot ".env"
$dbPath = $null
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_.Trim() -match '^CS_DB_PATH=(.+)$') {
            $raw = $Matches[1].Trim().Trim('"')
            # Resolve relative paths like ./data/... to absolute
            if ($raw.StartsWith("./") -or $raw.StartsWith(".\\")) {
                $dbPath = Join-Path $PSScriptRoot $raw.Substring(2)
            } else {
                $dbPath = $raw
            }
        }
    }
}

if (-not $dbPath) {
    Write-Host "ERROR: CS_DB_PATH not found in .env" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $dbPath)) {
    Write-Host "ERROR: Database not found at: $dbPath" -ForegroundColor Red
    exit 1
}

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "DB Purge: repos with stars > $MaxStars" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  DB: $dbPath" -ForegroundColor Gray
if ($DryRun) {
    Write-Host "  Mode: DRY RUN (no changes will be made)" -ForegroundColor Yellow
} else {
    Write-Host "  Mode: LIVE (changes will be written)" -ForegroundColor Red
}
Write-Host ""

# Build the inline Node.js script that uses better-sqlite3
$nodeScript = @"
const Database = require('better-sqlite3');
const db = new Database('$($dbPath -replace '\\', '\\\\')');

const maxStars = $MaxStars;
const dryRun = $($DryRun.ToString().ToLower());

// Find repos to purge
const toDelete = db.prepare('SELECT repo_id, full_name, stars FROM repos WHERE stars > ?').all(maxStars);

if (toDelete.length === 0) {
    console.log('No repos found with stars > ' + maxStars + '. Nothing to purge.');
    db.close();
    process.exit(0);
}

console.log('Repos to purge (' + toDelete.length + '):');
toDelete.forEach(r => console.log('  ' + r.full_name + ' (' + r.stars + ' stars)'));
console.log('');

if (dryRun) {
    console.log('DRY RUN: no changes made.');
    db.close();
    process.exit(0);
}

const ids = toDelete.map(r => r.repo_id);
const placeholders = ids.map(() => '?').join(',');

db.transaction(() => {
    const k = db.prepare('DELETE FROM keywords WHERE repo_id IN (' + placeholders + ')').run(...ids);
    const a = db.prepare('DELETE FROM analyses WHERE repo_id IN (' + placeholders + ')').run(...ids);
    const r = db.prepare('DELETE FROM readmes WHERE repo_id IN (' + placeholders + ')').run(...ids);
    const l = db.prepare('DELETE FROM repo_query_links WHERE repo_id IN (' + placeholders + ')').run(...ids);
    const p = db.prepare('DELETE FROM repos WHERE repo_id IN (' + placeholders + ')').run(...ids);

    console.log('Deleted:');
    console.log('  keywords:         ' + k.changes);
    console.log('  analyses:         ' + a.changes);
    console.log('  readmes:          ' + r.changes);
    console.log('  repo_query_links: ' + l.changes);
    console.log('  repos:            ' + p.changes);
})();

db.close();
console.log('');
console.log('Done.');
"@

# Write temp script inside project dir so node_modules is resolvable
$tempJs = Join-Path $PSScriptRoot "_purge_tmp.cjs"
$nodeScript | Out-File -FilePath $tempJs -Encoding utf8

$result = cmd /c "cd /d ""$PSScriptRoot"" && node _purge_tmp.cjs 2>&1"
$result | ForEach-Object { Write-Host $_ }

Remove-Item $tempJs -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "=================================================" -ForegroundColor Green
Write-Host "Done. Run 'pnpm briefs:generate' again to" -ForegroundColor Green
Write-Host "regenerate briefs without high-star repos." -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green
