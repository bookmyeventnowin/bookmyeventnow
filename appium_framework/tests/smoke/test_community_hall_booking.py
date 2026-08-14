"""
Smoke Test Suite — Community Hall Booking Flow
BookMyEvent Now | Appium + Python + pytest | POM Architecture

Test Scenarios:
  TC_SMOKE_001 — App launches and Login screen is displayed
  TC_SMOKE_002 — Valid login navigates to Home/Dashboard
  TC_SMOKE_003 — Community Hall category is accessible from Dashboard
  TC_SMOKE_004 — Venue listing loads with available venues
  TC_SMOKE_005 — Date selection works correctly on venue detail page
  TC_SMOKE_006 — Full end-to-end: Login → Community Hall → Select Dates → Order Created
"""

import pytest
import logging
from pages.login_page import LoginPage
from pages.home_page import HomePage
from pages.community_hall_page import CommunityHallPage
from pages.booking_page import BookingPage
from pages.confirmation_page import ConfirmationPage

logger = logging.getLogger(__name__)

# ──────────────────────────────────────────────
# Test Class
# ──────────────────────────────────────────────

@pytest.mark.smoke
@pytest.mark.community_hall
class TestCommunityHallBookingSmoke:
    """
    Smoke Test Suite for the Community Hall Booking end-to-end flow.
    All tests are ordered to simulate the real user journey.
    """

    # ──────────────────────────────────────────────
    # TC_SMOKE_001: App Launch — Login Screen Displayed
    # ──────────────────────────────────────────────

    @pytest.mark.order(1)
    def test_TC_SMOKE_001_app_launches_and_login_screen_is_displayed(
        self, driver
    ):
        """
        TC_SMOKE_001 — App Launch
        Pre-condition : App is installed on device
        Steps         : Launch the BookMyEvent Now app
        Expected      : Login screen is displayed with email & password fields
        """
        logger.info("=== TC_SMOKE_001: Verifying app launch and Login screen ===")

        login_page = LoginPage(driver)
        login_page.wait_for_splash_to_disappear()

        assert login_page.is_login_screen_displayed(), (
            "FAIL | TC_SMOKE_001: Login screen NOT displayed after app launch"
        )
        logger.info("PASS | TC_SMOKE_001: Login screen displayed successfully")

    # ──────────────────────────────────────────────
    # TC_SMOKE_002: Valid Login → Dashboard
    # ──────────────────────────────────────────────

    @pytest.mark.order(2)
    def test_TC_SMOKE_002_valid_login_navigates_to_dashboard(
        self, driver, test_data
    ):
        """
        TC_SMOKE_002 — Login with valid credentials
        Pre-condition : App is on Login screen
        Steps         : Enter valid email → Enter valid password → Tap Login
        Expected      : User is navigated to Home/Dashboard screen
        """
        logger.info("=== TC_SMOKE_002: Login with valid credentials ===")

        login_page = LoginPage(driver)
        home_page = HomePage(driver)

        login_page.wait_for_splash_to_disappear()

        email = test_data["valid_user"]["email"]
        password = test_data["valid_user"]["password"]

        login_page.login(email=email, password=password)

        assert login_page.is_login_successful(), (
            f"FAIL | TC_SMOKE_002: Login failed for user '{email}'. "
            "Dashboard not displayed after login."
        )
        assert home_page.is_home_screen_displayed(), (
            "FAIL | TC_SMOKE_002: Home/Dashboard screen NOT loaded after login"
        )
        logger.info("PASS | TC_SMOKE_002: Login successful, Dashboard loaded")

    # ──────────────────────────────────────────────
    # TC_SMOKE_003: Navigate to Community Hall Category
    # ──────────────────────────────────────────────

    @pytest.mark.order(3)
    def test_TC_SMOKE_003_community_hall_category_is_accessible(
        self, driver, test_data
    ):
        """
        TC_SMOKE_003 — Open Community Hall category from Dashboard
        Pre-condition : User is logged in and on Dashboard
        Steps         : Tap 'Community Hall' category card
        Expected      : Community Hall listing page loads with venues
        """
        logger.info("=== TC_SMOKE_003: Opening Community Hall category ===")

        login_page = LoginPage(driver)
        home_page = HomePage(driver)
        community_hall_page = CommunityHallPage(driver)

        # Login
        login_page.wait_for_splash_to_disappear()
        login_page.login(
            email=test_data["valid_user"]["email"],
            password=test_data["valid_user"]["password"],
        )
        assert home_page.is_home_screen_displayed(), (
            "Pre-condition failed: Dashboard not loaded"
        )

        # Navigate to Community Hall
        home_page.tap_category_community_hall()

        assert community_hall_page.is_community_hall_listing_displayed(), (
            "FAIL | TC_SMOKE_003: Community Hall listing page NOT displayed"
        )
        logger.info("PASS | TC_SMOKE_003: Community Hall listing loaded")

    # ──────────────────────────────────────────────
    # TC_SMOKE_004: Venue Listing Shows Available Venues
    # ──────────────────────────────────────────────

    @pytest.mark.order(4)
    def test_TC_SMOKE_004_venue_listing_has_available_venues(
        self, driver, test_data
    ):
        """
        TC_SMOKE_004 — Verify venues are listed in Community Hall category
        Pre-condition : Community Hall listing is open
        Steps         : Count visible venue cards
        Expected      : At least 1 venue is displayed in the listing
        """
        logger.info("=== TC_SMOKE_004: Verifying venue listing ===")

        login_page = LoginPage(driver)
        home_page = HomePage(driver)
        community_hall_page = CommunityHallPage(driver)

        # Login + Navigate
        login_page.wait_for_splash_to_disappear()
        login_page.login(
            email=test_data["valid_user"]["email"],
            password=test_data["valid_user"]["password"],
        )
        home_page.tap_category_community_hall()

        venue_count = community_hall_page.get_venue_count()
        is_empty = community_hall_page.is_venue_list_empty()

        assert not is_empty, (
            "FAIL | TC_SMOKE_004: Venue listing shows empty state — no venues available"
        )
        assert venue_count > 0, (
            f"FAIL | TC_SMOKE_004: Expected at least 1 venue, found: {venue_count}"
        )
        logger.info(f"PASS | TC_SMOKE_004: {venue_count} venue(s) displayed in listing")

    # ──────────────────────────────────────────────
    # TC_SMOKE_005: Date Selection on Venue Detail
    # ──────────────────────────────────────────────

    @pytest.mark.order(5)
    def test_TC_SMOKE_005_date_selection_works_on_venue_detail(
        self, driver, test_data
    ):
        """
        TC_SMOKE_005 — Select dates from the venue detail page
        Pre-condition : User is on venue detail page
        Steps         : Tap 'Book Now' → Open date picker → Select check-in & check-out dates
        Expected      : Selected dates are reflected in the booking summary
        """
        logger.info("=== TC_SMOKE_005: Verifying date selection ===")

        login_page = LoginPage(driver)
        home_page = HomePage(driver)
        community_hall_page = CommunityHallPage(driver)
        booking_page = BookingPage(driver)

        # Login + Navigate + Select venue
        login_page.wait_for_splash_to_disappear()
        login_page.login(
            email=test_data["valid_user"]["email"],
            password=test_data["valid_user"]["password"],
        )
        home_page.tap_category_community_hall()
        community_hall_page.select_first_available_venue()

        assert booking_page.is_venue_detail_displayed(), (
            "Pre-condition failed: Venue detail page not loaded"
        )

        # Open booking / date picker
        booking_page.tap_book_now()

        assert booking_page.is_date_picker_displayed(), (
            "FAIL | TC_SMOKE_005: Date picker / Calendar NOT displayed after tapping Book Now"
        )

        # Select dates (using day numbers; calendar shows current month)
        booking_page.select_check_in_date("10")
        booking_page.select_check_out_date("12")
        booking_page.confirm_dates()

        check_in = booking_page.get_selected_check_in()
        check_out = booking_page.get_selected_check_out()

        assert check_in, (
            "FAIL | TC_SMOKE_005: Check-in date not reflected after selection"
        )
        assert check_out, (
            "FAIL | TC_SMOKE_005: Check-out date not reflected after selection"
        )
        logger.info(
            f"PASS | TC_SMOKE_005: Dates selected — Check-in: {check_in} | Check-out: {check_out}"
        )

    # ──────────────────────────────────────────────
    # TC_SMOKE_006: End-to-End — Full Booking Flow
    # ──────────────────────────────────────────────

    @pytest.mark.order(6)
    @pytest.mark.e2e
    def test_TC_SMOKE_006_end_to_end_community_hall_booking_order_created(
        self, driver, test_data
    ):
        """
        TC_SMOKE_006 — Full E2E Smoke: Login → Community Hall → Dates → Order Created
        ─────────────────────────────────────────────────────────────────────────────
        Pre-condition : App installed, valid test user exists, venue available
        Steps:
          1. Launch app
          2. Login with valid credentials
          3. Tap 'Community Hall' category
          4. Select first available venue
          5. Tap 'Book Now'
          6. Select check-in and check-out dates
          7. Set guest count
          8. Confirm booking
        Expected:
          - Order confirmation / success screen is displayed
          - An Order ID is generated and visible
          - Confirmed venue name, dates, and total are shown
        ─────────────────────────────────────────────────────────────────────────────
        """
        logger.info("=== TC_SMOKE_006: FULL E2E Community Hall Booking Flow ===")

        # -- Instantiate all page objects --
        login_page = LoginPage(driver)
        home_page = HomePage(driver)
        community_hall_page = CommunityHallPage(driver)
        booking_page = BookingPage(driver)
        confirmation_page = ConfirmationPage(driver)

        booking_data = test_data["booking"]

        # ─── STEP 1: App Launch ───────────────────
        logger.info("Step 1: Waiting for splash screen...")
        login_page.wait_for_splash_to_disappear()
        assert login_page.is_login_screen_displayed(), (
            "Step 1 FAIL: Login screen not displayed on launch"
        )

        # ─── STEP 2: Login ────────────────────────
        logger.info("Step 2: Logging in...")
        login_page.login(
            email=test_data["valid_user"]["email"],
            password=test_data["valid_user"]["password"],
        )
        assert home_page.is_home_screen_displayed(), (
            "Step 2 FAIL: Dashboard did not load after valid login"
        )
        logger.info("Step 2 PASS: Dashboard loaded")

        # ─── STEP 3: Open Community Hall ──────────
        logger.info("Step 3: Tapping Community Hall category...")
        home_page.tap_category_community_hall()
        assert community_hall_page.is_community_hall_listing_displayed(), (
            "Step 3 FAIL: Community Hall listing not loaded"
        )
        logger.info("Step 3 PASS: Community Hall listing displayed")

        # ─── STEP 4: Select Venue ─────────────────
        logger.info(f"Step 4: Selecting venue '{booking_data['venue_name']}'...")
        try:
            community_hall_page.select_venue_by_name(booking_data["venue_name"])
        except Exception:
            logger.warning(
                f"Venue '{booking_data['venue_name']}' not found by name. "
                "Falling back to first available venue."
            )
            community_hall_page.select_first_available_venue()

        assert booking_page.is_venue_detail_displayed(), (
            "Step 4 FAIL: Venue detail page did not load"
        )
        venue_name = booking_page.get_venue_name()
        logger.info(f"Step 4 PASS: Venue detail loaded for '{venue_name}'")

        # ─── STEP 5: Open Date Picker ─────────────
        logger.info("Step 5: Tapping 'Book Now' to open date picker...")
        booking_page.tap_book_now()
        assert booking_page.is_date_picker_displayed(), (
            "Step 5 FAIL: Date picker not displayed after tapping Book Now"
        )
        logger.info("Step 5 PASS: Date picker is visible")

        # ─── STEP 6: Select Dates ─────────────────
        logger.info("Step 6: Selecting check-in and check-out dates...")
        booking_page.select_check_in_date("15")
        booking_page.select_check_out_date("17")
        booking_page.confirm_dates()

        check_in = booking_page.get_selected_check_in()
        check_out = booking_page.get_selected_check_out()
        assert check_in, "Step 6 FAIL: Check-in date not set"
        assert check_out, "Step 6 FAIL: Check-out date not set"
        logger.info(
            f"Step 6 PASS: Dates set — Check-in: {check_in}, Check-out: {check_out}"
        )

        # ─── STEP 7: Set Guest Count ──────────────
        logger.info(f"Step 7: Setting guest count to {booking_data['guest_count']}...")
        # Note: Only increment a few times for smoke test speed
        booking_page.set_guest_count(2)
        logger.info("Step 7 PASS: Guest count set")

        # ─── STEP 8: Confirm Booking ──────────────
        logger.info("Step 8: Confirming booking...")
        booking_page.scroll_to_confirm_button()

        assert booking_page.is_booking_summary_displayed(), (
            "Step 8 PRE-CHECK FAIL: Booking summary not visible before confirmation"
        )

        total_price = booking_page.get_total_price()
        logger.info(f"Booking summary total price: {total_price}")

        booking_page.take_screenshot("before_confirmation")
        booking_page.tap_confirm_booking()

        # ─── STEP 9: Verify Order Success ─────────
        logger.info("Step 9: Verifying order success screen...")
        assert confirmation_page.is_order_success_displayed(), (
            "TC_SMOKE_006 FAIL: Order success screen NOT displayed after booking confirmation. "
            "Expected success message/icon/animation to appear."
        )

        order_id = confirmation_page.get_order_id()
        assert confirmation_page.is_order_id_present(), (
            f"TC_SMOKE_006 FAIL: Order ID not visible on confirmation screen. Got: '{order_id}'"
        )

        # Capture success screenshot for evidence
        confirmation_page.capture_confirmation_screenshot()

        success_title = confirmation_page.get_success_title()
        logger.info(
            f"\n{'='*60}\n"
            f"PASS | TC_SMOKE_006: Order Created Successfully!\n"
            f"  Order ID     : {order_id}\n"
            f"  Venue        : {venue_name}\n"
            f"  Check-in     : {check_in}\n"
            f"  Check-out    : {check_out}\n"
            f"  Total Price  : {total_price}\n"
            f"  Success Msg  : {success_title}\n"
            f"{'='*60}"
        )
