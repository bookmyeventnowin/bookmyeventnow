# ─────────────────────────────────────────────────────────────────────────────
# BookMyEventNow — Smoke Test Runner (PowerShell)
# Runs: Unit + Widget + Integration tests, saves JSON results for QA Agent
# Usage: Right-click → Run with PowerShell  OR  .\run_smoke_local.ps1
# ─────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Continue"
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ResultsDir  = "$ProjectRoot\.qa\results"
$ReportFile  = "$ResultsDir\smoke_results.json"
$LogFile     = "$ResultsDir\smoke_run.log"

New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null

$RunAt     = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$StartTime = Get-Date

Write-Host ""
Write-Host "══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  BookMyEventNow — Smoke Test Run" -ForegroundColor Cyan
Write-Host "  $RunAt" -ForegroundColor Cyan
Write-Host "══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# ── Verify Flutter ────────────────────────────────────────────────────────────
$flutterPath = (Get-Command flutter -ErrorAction SilentlyContinue)?.Source
if (-not $flutterPath) {
    Write-Host "❌ Flutter not found in PATH." -ForegroundColor Red
    Write-Host "   Please install Flutter: https://flutter.dev/docs/get-started/install" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

$flutterVersion = (flutter --version 2>&1 | Select-String "Flutter").Line
Write-Host "✅ Flutter found: $flutterVersion" -ForegroundColor Green

# ── Check device ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "📱 Connected devices:" -ForegroundColor Yellow
flutter devices 2>&1

# ── Helper function ───────────────────────────────────────────────────────────
$Results = @()

function Run-FlutterTest {
    param(
        [string]$TestId,
        [string]$Name,
        [string]$Suite,
        [string]$TestPath,
        [string]$DeviceId = ""
    )

    Write-Host ""
    Write-Host "▶ [$TestId] $Name ..." -ForegroundColor Yellow

    $t0  = Get-Date
    if ($DeviceId) {
        $raw = flutter test $TestPath --device-id $DeviceId --reporter expanded 2>&1
    } else {
        $raw = flutter test $TestPath --reporter expanded 2>&1
    }
    $t1       = Get-Date
    $duration = [math]::Round(($t1 - $t0).TotalSeconds, 2)
    $output   = $raw -join "`n"

    # Detect pass/fail
    $passed = ($output -match "All tests passed") -or ($output -match "✓") -and -not ($output -match "FAILED") -and -not ($output -match "Some tests failed")
    $failed = ($output -match "Some tests failed") -or ($output -match "FAILED") -or ($LASTEXITCODE -ne 0)

    $status = if ($failed) { "FAILED" } elseif ($passed) { "PASSED" } else { "UNKNOWN" }

    # Count individual test lines
    $passCount = ([regex]::Matches($output, "✓|[+]\s+\d+")).Count
    $failCount = ([regex]::Matches($output, "✗|FAILED")).Count

    $icon = if ($status -eq "PASSED") { "✅" } else { "❌" }
    Write-Host "  $icon $status  (${duration}s)" -ForegroundColor $(if ($status -eq "PASSED") { "Green" } else { "Red" })

    if ($status -eq "FAILED") {
        Write-Host "  ── Failure output ──" -ForegroundColor Red
        $output -split "`n" | Where-Object { $_ -match "FAILED|Error|Exception|expect" } | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    }

    return @{
        id         = $TestId
        name       = $Name
        suite      = $Suite
        path       = $TestPath
        status     = $status
        duration   = $duration
        pass_count = $passCount
        fail_count = $failCount
        log        = $output
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# UNIT TESTS
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "━━━ UNIT TESTS ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

Set-Location $ProjectRoot

$Results += Run-FlutterTest "UT-001" "fee_utils_test"           "unit"   "test/unit/fee_utils_test.dart"
$Results += Run-FlutterTest "UT-002" "booking_model_test"       "unit"   "test/unit/booking_model_test.dart"
$Results += Run-FlutterTest "UT-003" "user_role_storage_test"   "unit"   "test/unit/user_role_storage_test.dart"
$Results += Run-FlutterTest "UT-004" "booking_repository_test"  "unit"   "test/unit/booking_repository_test.dart"

# ─────────────────────────────────────────────────────────────────────────────
# WIDGET TESTS
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "━━━ WIDGET TESTS ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

$Results += Run-FlutterTest "WT-001" "login_page_test" "widget" "test/widget/login_page_test.dart"

# ─────────────────────────────────────────────────────────────────────────────
# INTEGRATION TESTS  (requires emulator — skip if no device)
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "━━━ INTEGRATION TESTS ━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

$devices = flutter devices 2>&1
$hasDevice = $devices -match "emulator|device|android"

if ($hasDevice) {
    $deviceId = (flutter devices 2>&1 | Select-String "• " | Select-Object -First 1) -replace ".*• (\S+) .*", '$1'
    Write-Host "  Using device: $deviceId" -ForegroundColor Yellow

    $Results += Run-FlutterTest "IT-001" "auth_flow_test"              "integration" "integration_test/auth_flow_test.dart"              $deviceId
    $Results += Run-FlutterTest "IT-002" "booking_flow_test"           "integration" "integration_test/booking_flow_test.dart"            $deviceId
    $Results += Run-FlutterTest "IT-003" "vendor_flow_test"            "integration" "integration_test/vendor_flow_test.dart"             $deviceId
    $Results += Run-FlutterTest "IT-004" "playstore_compliance_test"   "integration" "integration_test/playstore_compliance_test.dart"    $deviceId
} else {
    Write-Host "  ⚠️  No device/emulator detected — skipping integration tests" -ForegroundColor Yellow
    Write-Host "     Start an emulator and re-run to include integration tests" -ForegroundColor Yellow
    $Results += @{ id="IT-001"; name="auth_flow_test";            suite="integration"; status="SKIPPED"; duration=0; log="No device connected" }
    $Results += @{ id="IT-002"; name="booking_flow_test";         suite="integration"; status="SKIPPED"; duration=0; log="No device connected" }
    $Results += @{ id="IT-003"; name="vendor_flow_test";          suite="integration"; status="SKIPPED"; duration=0; log="No device connected" }
    $Results += @{ id="IT-004"; name="playstore_compliance_test"; suite="integration"; status="SKIPPED"; duration=0; log="No device connected" }
}

# ─────────────────────────────────────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────────────────────────────────────
$EndTime      = Get-Date
$TotalSeconds = [math]::Round(($EndTime - $StartTime).TotalSeconds, 2)
$Passed       = ($Results | Where-Object { $_.status -eq "PASSED" }).Count
$Failed       = ($Results | Where-Object { $_.status -eq "FAILED" }).Count
$Skipped      = ($Results | Where-Object { $_.status -eq "SKIPPED" }).Count
$Total        = $Results.Count
$PassRate     = if ($Total -gt 0) { [math]::Round(($Passed / ($Total - $Skipped)) * 100) } else { 0 }

Write-Host ""
Write-Host "══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  RESULTS: $Passed Passed | $Failed Failed | $Skipped Skipped | ${TotalSeconds}s" -ForegroundColor $(if ($Failed -gt 0) { "Red" } else { "Green" })
Write-Host "  Pass Rate: ${PassRate}%" -ForegroundColor $(if ($PassRate -eq 100) { "Green" } elseif ($PassRate -ge 70) { "Yellow" } else { "Red" })
Write-Host "══════════════════════════════════════════════════" -ForegroundColor Cyan

# ─────────────────────────────────────────────────────────────────────────────
# SAVE JSON RESULTS  (QA Agent reads this to update Jira)
# ─────────────────────────────────────────────────────────────────────────────
$JsonResults = @{
    run_at          = $RunAt
    story           = "KAN-1"
    flutter_version = $flutterVersion
    total           = $Total
    passed          = $Passed
    failed          = $Failed
    skipped         = $Skipped
    pass_rate       = "${PassRate}%"
    total_duration  = $TotalSeconds
    results         = $Results | ForEach-Object {
        @{
            id       = $_.id
            name     = $_.name
            suite    = $_.suite
            status   = $_.status
            duration = $_.duration
            log      = ($_.log | Out-String).Trim() | Select-Object -First 1
        }
    }
} | ConvertTo-Json -Depth 5

$JsonResults | Out-File -FilePath $ReportFile -Encoding utf8
Write-Host ""
Write-Host "📄 Results saved → $ReportFile" -ForegroundColor Green
Write-Host "   QA Agent will auto-read this and update KAN-1 in Jira." -ForegroundColor Cyan
Write-Host ""

if ($Failed -gt 0) {
    Write-Host "❌ $Failed test(s) FAILED. Check logs above." -ForegroundColor Red
    exit 1
} else {
    Write-Host "✅ All tests passed! Ready for Jira update." -ForegroundColor Green
    exit 0
}
