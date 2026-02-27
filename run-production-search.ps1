# Collaboration Scout - Production Search Workflow
# Full end-to-end: search -> analyze -> generate briefs -> export

param(
    [string]$Query = "vector database",
    [int]$Days = 180,
    [int]$Stars = 10,
    [int]$MaxStars = 500,
    [int]$Top = 50,
    [string]$Language = "typescript",
    [double]$OverlapThreshold = 0.70,
    [int]$HistoryCandidates = 100,
    [double]$MinScore = 0.65,
    [int]$MaxBriefs = 30,
    [string]$OutputDir = "./output",
    # Your own repo (e.g. "myorg/myrepo") - exempt from diversity dedup, appears in every brief
    [string]$OwnRepo = ""
)

# Helper: run a pnpm script silently and return its output lines
function Run-Pnpm {
    param([string]$ScriptArgs)
    $output = cmd /c "pnpm $ScriptArgs 2>&1"
    return $output
}

# Helper: run a pnpm script with LIVE output via temp-file polling, return all lines at end
function Run-Pnpm-Live {
    param([string]$ScriptArgs)
    $tempFile = [System.IO.Path]::GetTempFileName()
    $proc = Start-Process -FilePath "cmd" `
        -ArgumentList "/c pnpm $ScriptArgs > `"$tempFile`" 2>&1" `
        -NoNewWindow -PassThru

    $lastCount = 0
    while (-not $proc.HasExited) {
        Start-Sleep -Milliseconds 600
        $lines = Get-Content $tempFile -ErrorAction SilentlyContinue
        if ($lines -and $lines.Count -gt $lastCount) {
            for ($i = $lastCount; $i -lt $lines.Count; $i++) {
                $line = $lines[$i]
                if ($line -match '"message"') {
                    try {
                        $j = $line | ConvertFrom-Json -ErrorAction Stop
                        $ts = ([datetime]$j.timestamp).ToString("HH:mm:ss")
                        $color = if ($j.level -eq "error") { "Red" } elseif ($j.level -eq "warn") { "Yellow" } else { "Gray" }
                        Write-Host "  [$ts] $($j.message)" -ForegroundColor $color
                    } catch { }
                }
            }
            $lastCount = $lines.Count
        }
    }

    # Flush any remaining lines after exit
    $lines = Get-Content $tempFile -ErrorAction SilentlyContinue
    if ($lines) {
        for ($i = $lastCount; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ($line -match '"message"') {
                try {
                    $j = $line | ConvertFrom-Json -ErrorAction Stop
                    $ts = ([datetime]$j.timestamp).ToString("HH:mm:ss")
                    $color = if ($j.level -eq "error") { "Red" } else { "Gray" }
                    Write-Host "  [$ts] $($j.message)" -ForegroundColor $color
                } catch { }
            }
        }
    }

    Remove-Item $tempFile -ErrorAction SilentlyContinue
    return $lines
}

# Helper: extract the LAST multi-line JSON block from mixed log output
# The summary JSON is always the last thing printed, and starts with a standalone "{"
function Extract-Json {
    param([string[]]$Lines)
    # Find the last line that is just "{" (multi-line pretty-printed JSON)
    $jsonStart = -1
    for ($i = $Lines.Length - 1; $i -ge 0; $i--) {
        if ($Lines[$i].Trim() -eq "{") {
            $jsonStart = $i
            break
        }
    }
    if ($jsonStart -lt 0) { return "" }

    $json = ""
    $depth = 0
    for ($i = $jsonStart; $i -lt $Lines.Length; $i++) {
        $json += $Lines[$i] + "`n"
        $depth += ($Lines[$i].ToCharArray() | Where-Object { $_ -eq '{' } | Measure-Object).Count
        $depth -= ($Lines[$i].ToCharArray() | Where-Object { $_ -eq '}' } | Measure-Object).Count
        if ($depth -le 0 -and $i -gt $jsonStart) { break }
    }
    return $json.Trim()
}

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "Collaboration Scout - Production Search Workflow" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

# STEP 1: Verify Setup
Write-Host "[1/5] Verifying configuration..." -ForegroundColor Yellow
$doctorOut = Run-Pnpm "doctor"
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Doctor check failed." -ForegroundColor Red
    $doctorOut | Write-Host
    exit 1
}
Write-Host "[OK] Configuration verified" -ForegroundColor Green
Write-Host ""

# STEP 2: Scout (GitHub search + README hydration + LLM analysis)
Write-Host "[2/5] Running Scout (search + hydrate + analyze)..." -ForegroundColor Yellow
Write-Host "  Query: '$Query'" -ForegroundColor Gray
Write-Host "  Top: $Top, Stars: $Stars-$MaxStars, Days: $Days, Lang: $Language" -ForegroundColor Gray
Write-Host ""

function Run-Scout {
    param([int]$StarsMin, [int]$StarsMax, [string]$Lang)
    $args = "scout:run --query ""$Query"" --days $Days --stars $StarsMin --max-stars $StarsMax --top $Top"
    if ($Lang -ne "") { $args += " --lang $Lang" }
    return Run-Pnpm-Live $args
}

$scoutOut = Run-Scout -StarsMin $Stars -StarsMax $MaxStars -Lang $Language
$scoutJsonStr = Extract-Json -Lines $scoutOut

if ([string]::IsNullOrEmpty($scoutJsonStr)) {
    Write-Host "ERROR: Scout failed - no JSON output found" -ForegroundColor Red
    exit 1
}

try { $scoutJson = $scoutJsonStr | ConvertFrom-Json; $RUN_ID = $scoutJson.run_id } catch {
    Write-Host "ERROR: Could not parse scout output as JSON" -ForegroundColor Red
    exit 1
}

# Auto-retry with looser thresholds if nothing found
if ($scoutJson.repos_found -eq 0) {
    $retryStars = [math]::Max(1, [math]::Floor($Stars / 2))
    Write-Host ""
    Write-Host "  [!] No repos found. Retrying with Stars=$retryStars and no language filter..." -ForegroundColor Yellow
    Write-Host ""
    $scoutOut = Run-Scout -StarsMin $retryStars -StarsMax $MaxStars -Lang ""
    $scoutJsonStr = Extract-Json -Lines $scoutOut
    try { $scoutJson = $scoutJsonStr | ConvertFrom-Json; $RUN_ID = $scoutJson.run_id } catch { }
}

# If still nothing, bail cleanly
if ($scoutJson.repos_found -eq 0) {
    Write-Host ""
    Write-Host "[SKIP] No repos found after retry. Try a broader query." -ForegroundColor Yellow
    exit 0
}

if ([string]::IsNullOrEmpty($RUN_ID)) {
    Write-Host "ERROR: No run_id in scout output" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[OK] Scout complete. Run ID: $RUN_ID" -ForegroundColor Green
Write-Host "  Repos found: $($scoutJson.repos_found), Analyzed: $($scoutJson.analyzed), Failed: $($scoutJson.failed)" -ForegroundColor Gray
Write-Host ""

# STEP 3: Generate Briefs
Write-Host "[3/5] Generating collaboration briefs..." -ForegroundColor Yellow
Write-Host "  Overlap threshold: $OverlapThreshold, History candidates: $HistoryCandidates" -ForegroundColor Gray
Write-Host "  Min score: $MinScore, Max briefs: $MaxBriefs" -ForegroundColor Gray
Write-Host ""

$briefsArgs = "briefs:generate --run-id $RUN_ID --min-score $MinScore --max-briefs $MaxBriefs --overlap-threshold $OverlapThreshold --history-candidates $HistoryCandidates"
if ($OwnRepo -ne "") { $briefsArgs += " --own-repo ""$OwnRepo""" }
$briefsOut = Run-Pnpm $briefsArgs
$briefsOut | Write-Host

$briefsJsonStr = Extract-Json -Lines $briefsOut
if ([string]::IsNullOrEmpty($briefsJsonStr)) {
    Write-Host "ERROR: Briefs generation failed" -ForegroundColor Red
    exit 1
}

try {
    $briefsJson = $briefsJsonStr | ConvertFrom-Json
} catch {
    Write-Host "ERROR: Could not parse briefs output as JSON" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[OK] Briefs complete" -ForegroundColor Green
Write-Host "  Generated: $($briefsJson.briefs_generated), Shortlisted: $($briefsJson.briefs_shortlisted), Failed: $($briefsJson.failed)" -ForegroundColor Gray
Write-Host "  History injected: $($briefsJson.history_candidates_injected), Pairs rejected (overlap): $($briefsJson.pairs_rejected_overlap)" -ForegroundColor Gray
Write-Host ""

# STEP 4: Export to Markdown
Write-Host "[4/5] Exporting briefs to Markdown..." -ForegroundColor Yellow

$exportArgs = "briefs:export --run-id $RUN_ID --out $OutputDir --top-opportunities 3"
$exportOut = Run-Pnpm $exportArgs
$exportOut | Write-Host

$exportJsonStr = Extract-Json -Lines $exportOut
if ([string]::IsNullOrEmpty($exportJsonStr)) {
    Write-Host "ERROR: Export failed" -ForegroundColor Red
    exit 1
}

try {
    $exportJson = $exportJsonStr | ConvertFrom-Json
    $outDir = $exportJson.outDir
} catch {
    Write-Host "ERROR: Could not parse export output" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[OK] Exported to: $outDir" -ForegroundColor Green
Write-Host ""

# STEP 5: Display Results
Write-Host "[5/5] Results Summary" -ForegroundColor Yellow
Write-Host ""

$indexPath = Join-Path $outDir "index.md"
if (Test-Path $indexPath) {
    Write-Host "--- BRIEF INDEX ---" -ForegroundColor Cyan
    Get-Content $indexPath | Select-Object -First 40
    Write-Host ""
}

Write-Host "--- OUTPUT FILES ---" -ForegroundColor Cyan
$topFiles = Get-ChildItem $outDir -Filter "TOP_OPPORTUNITY_*.md" -ErrorAction SilentlyContinue
if ($topFiles) {
    $topFiles | ForEach-Object {
        Write-Host "  * $($_.Name)  ($([math]::Round($_.Length / 1KB, 1)) KB)" -ForegroundColor Green
    }
} else {
    Write-Host "  (no top opportunity files - try lowering -MinScore)" -ForegroundColor Yellow
}

$briefCount = (Get-ChildItem (Join-Path $outDir "briefs") -Filter "*.md" -ErrorAction SilentlyContinue | Measure-Object).Count
Write-Host "  * $briefCount files in briefs/ folder" -ForegroundColor Green
Write-Host ""

Write-Host "--- NEXT STEPS ---" -ForegroundColor Cyan
Write-Host "  View TOP_OPPORTUNITY_1.md:" -ForegroundColor Yellow
Write-Host "    cat '$outDir\TOP_OPPORTUNITY_1.md'" -ForegroundColor Gray
Write-Host ""
Write-Host "  View outreach templates:" -ForegroundColor Yellow
Write-Host "    Get-ChildItem '$outDir\briefs' -Filter '*_outreach.md' | Get-Content" -ForegroundColor Gray
Write-Host ""
Write-Host "  Run another search (previous repos auto-included):" -ForegroundColor Yellow
Write-Host "    .\run-production-search.ps1 -Query 'rag framework'" -ForegroundColor Gray
Write-Host ""

Write-Host "=================================================" -ForegroundColor Green
Write-Host "*** Workflow Complete! ***" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green
