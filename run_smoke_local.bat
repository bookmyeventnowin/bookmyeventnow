@echo off
REM ─────────────────────────────────────────────────────────────────────────
REM  BookMyEventNow — Smoke Test Runner (Windows Batch)
REM  Double-click this file to run all Flutter tests locally.
REM ─────────────────────────────────────────────────────────────────────────

title BookMyEventNow — Smoke Tests

echo.
echo ══════════════════════════════════════════════════
echo   BookMyEventNow — Smoke Test Runner
echo ══════════════════════════════════════════════════
echo.

REM Check Flutter installed
where flutter >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Flutter not found in PATH.
    echo         Install from: https://flutter.dev/docs/get-started/install
    pause
    exit /b 1
)

echo [INFO] Flutter found:
flutter --version
echo.

cd /d "%~dp0"

REM ── UNIT TESTS ─────────────────────────────────────
echo ── UNIT TESTS ─────────────────────────────────────
echo.

echo [1/5] fee_utils_test...
flutter test test/unit/fee_utils_test.dart --reporter expanded
if %ERRORLEVEL% NEQ 0 ( echo    FAILED & set UNIT_FAIL=1 ) else ( echo    PASSED )

echo.
echo [2/5] booking_model_test...
flutter test test/unit/booking_model_test.dart --reporter expanded
if %ERRORLEVEL% NEQ 0 ( echo    FAILED & set UNIT_FAIL=1 ) else ( echo    PASSED )

echo.
echo [3/5] user_role_storage_test...
flutter test test/unit/user_role_storage_test.dart --reporter expanded
if %ERRORLEVEL% NEQ 0 ( echo    FAILED & set UNIT_FAIL=1 ) else ( echo    PASSED )

echo.
echo [4/5] booking_repository_test...
flutter test test/unit/booking_repository_test.dart --reporter expanded
if %ERRORLEVEL% NEQ 0 ( echo    FAILED & set UNIT_FAIL=1 ) else ( echo    PASSED )

REM ── WIDGET TESTS ───────────────────────────────────
echo.
echo ── WIDGET TESTS ───────────────────────────────────
echo.
echo [5/5] login_page_test...
flutter test test/widget/login_page_test.dart --reporter expanded
if %ERRORLEVEL% NEQ 0 ( echo    FAILED & set WIDGET_FAIL=1 ) else ( echo    PASSED )

REM ── INTEGRATION TESTS ──────────────────────────────
echo.
echo ── INTEGRATION TESTS ──────────────────────────────
flutter devices 2>&1 | findstr /i "emulator device android" >nul
if %ERRORLEVEL% EQU 0 (
    echo Device found. Running integration tests...
    flutter test integration_test/auth_flow_test.dart --reporter expanded
    flutter test integration_test/booking_flow_test.dart --reporter expanded
    flutter test integration_test/vendor_flow_test.dart --reporter expanded
    flutter test integration_test/playstore_compliance_test.dart --reporter expanded
) else (
    echo [SKIP] No emulator/device found. Start one to run integration tests.
)

REM ── DONE ───────────────────────────────────────────
echo.
echo ══════════════════════════════════════════════════
if defined UNIT_FAIL   ( echo   UNIT TESTS   : FAILED )   else ( echo   UNIT TESTS   : PASSED )
if defined WIDGET_FAIL ( echo   WIDGET TESTS : FAILED )   else ( echo   WIDGET TESTS : PASSED )
echo ══════════════════════════════════════════════════
echo.
echo Results logged. QA Agent will update KAN-1 in Jira.
pause
