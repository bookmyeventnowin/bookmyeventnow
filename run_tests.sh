#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# BookMyEventNow — Test Runner Script
# ─────────────────────────────────────────────────────────────────────────────
# Usage:
#   chmod +x run_tests.sh
#   ./run_tests.sh [unit|widget|integration|all]
#
# Requirements:
#   - Flutter SDK installed and in PATH
#   - Android emulator or physical device (for integration tests)
#   - Firebase emulator (optional, recommended for CI)
# ─────────────────────────────────────────────────────────────────────────────

set -e  # Exit on first failure

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

DEVICE_ID="${DEVICE_ID:-emulator-5554}"

print_header() {
  echo ""
  echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}  $1${NC}"
  echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
}

run_unit_tests() {
  print_header "Unit Tests"
  echo -e "${YELLOW}Running fee_utils_test...${NC}"
  flutter test test/unit/fee_utils_test.dart --reporter expanded

  echo -e "${YELLOW}Running booking_model_test...${NC}"
  flutter test test/unit/booking_model_test.dart --reporter expanded

  echo -e "${YELLOW}Running user_role_storage_test...${NC}"
  flutter test test/unit/user_role_storage_test.dart --reporter expanded

  echo -e "${YELLOW}Running booking_repository_test...${NC}"
  flutter test test/unit/booking_repository_test.dart --reporter expanded

  echo -e "${GREEN}✅ Unit tests complete${NC}"
}

run_widget_tests() {
  print_header "Widget Tests"
  echo -e "${YELLOW}Running login_page_test...${NC}"
  flutter test test/widget/login_page_test.dart --reporter expanded
  echo -e "${GREEN}✅ Widget tests complete${NC}"
}

run_integration_tests() {
  print_header "Integration Tests (device: $DEVICE_ID)"

  echo -e "${YELLOW}Running auth_flow_test...${NC}"
  flutter test integration_test/auth_flow_test.dart \
    --device-id "$DEVICE_ID" --reporter expanded

  echo -e "${YELLOW}Running booking_flow_test...${NC}"
  flutter test integration_test/booking_flow_test.dart \
    --device-id "$DEVICE_ID" --reporter expanded

  echo -e "${YELLOW}Running vendor_flow_test...${NC}"
  flutter test integration_test/vendor_flow_test.dart \
    --device-id "$DEVICE_ID" --reporter expanded

  echo -e "${YELLOW}Running playstore_compliance_test...${NC}"
  flutter test integration_test/playstore_compliance_test.dart \
    --device-id "$DEVICE_ID" --reporter expanded

  echo -e "${GREEN}✅ Integration tests complete${NC}"
}

run_all() {
  run_unit_tests
  run_widget_tests
  run_integration_tests
}

case "${1:-all}" in
  unit)        run_unit_tests ;;
  widget)      run_widget_tests ;;
  integration) run_integration_tests ;;
  all)         run_all ;;
  *)
    echo -e "${RED}Unknown option: $1${NC}"
    echo "Usage: ./run_tests.sh [unit|widget|integration|all]"
    exit 1
    ;;
esac

echo ""
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}  All selected tests passed! ✅${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
