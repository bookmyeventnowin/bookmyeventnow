"""
Venue Detail & Booking Page Object — BookMyEvent Now
Covers: Venue detail → Date picker → Guest count → Confirm booking
"""

from appium.webdriver.common.appiumby import AppiumBy
from pages.base_page import BasePage
import logging

logger = logging.getLogger(__name__)


class BookingPage(BasePage):
    """
    Page Object for the Venue Detail and Date Selection screen.
    Handles date picker, guest count selector, and booking summary.
    """

    # ──────────────────────────────────────────────
    # Locators — Venue Detail
    # ──────────────────────────────────────────────

    LBL_VENUE_NAME = (AppiumBy.ID, "com.bookmyeventnow.app:id/tv_venue_detail_name")
    LBL_VENUE_ADDRESS = (AppiumBy.ID, "com.bookmyeventnow.app:id/tv_venue_address")
    LBL_VENUE_PRICE = (AppiumBy.ID, "com.bookmyeventnow.app:id/tv_venue_detail_price")
    LBL_VENUE_CAPACITY = (AppiumBy.ID, "com.bookmyeventnow.app:id/tv_venue_capacity")
    LBL_VENUE_RATING = (AppiumBy.ID, "com.bookmyeventnow.app:id/tv_venue_detail_rating")
    BTN_BOOK_NOW = (AppiumBy.ID, "com.bookmyeventnow.app:id/btn_book_now")
    BTN_BACK = (AppiumBy.ID, "com.bookmyeventnow.app:id/iv_back")

    # ──────────────────────────────────────────────
    # Locators — Date Picker
    # ──────────────────────────────────────────────

    BTN_SELECT_DATES = (AppiumBy.ID, "com.bookmyeventnow.app:id/btn_select_dates")
    LBL_CHECK_IN_DATE = (AppiumBy.ID, "com.bookmyeventnow.app:id/tv_check_in_date")
    LBL_CHECK_OUT_DATE = (AppiumBy.ID, "com.bookmyeventnow.app:id/tv_check_out_date")

    # Date Picker Calendar
    CALENDAR_VIEW = (AppiumBy.ID, "com.bookmyeventnow.app:id/calendar_view")
    BTN_NEXT_MONTH = (AppiumBy.ID, "com.bookmyeventnow.app:id/btn_next_month")
    BTN_PREV_MONTH = (AppiumBy.ID, "com.bookmyeventnow.app:id/btn_prev_month")
    BTN_CONFIRM_DATES = (AppiumBy.ID, "com.bookmyeventnow.app:id/btn_confirm_dates")

    # ──────────────────────────────────────────────
    # Locators — Guest Count & Extras
    # ──────────────────────────────────────────────

    ETF_GUEST_COUNT = (AppiumBy.ID, "com.bookmyeventnow.app:id/et_guest_count")
    BTN_GUEST_INCREMENT = (AppiumBy.ID, "com.bookmyeventnow.app:id/btn_guest_plus")
    BTN_GUEST_DECREMENT = (AppiumBy.ID, "com.bookmyeventnow.app:id/btn_guest_minus")
    LBL_GUEST_COUNT_VALUE = (AppiumBy.ID, "com.bookmyeventnow.app:id/tv_guest_count")

    # ──────────────────────────────────────────────
    # Locators — Booking Summary
    # ──────────────────────────────────────────────

    LBL_TOTAL_PRICE = (AppiumBy.ID, "com.bookmyeventnow.app:id/tv_total_price")
    LBL_BOOKING_DURATION = (AppiumBy.ID, "com.bookmyeventnow.app:id/tv_booking_duration")
    LBL_SUMMARY_VENUE = (AppiumBy.ID, "com.bookmyeventnow.app:id/tv_summary_venue_name")
    LBL_SUMMARY_DATES = (AppiumBy.ID, "com.bookmyeventnow.app:id/tv_summary_dates")
    BTN_PROCEED_PAYMENT = (AppiumBy.ID, "com.bookmyeventnow.app:id/btn_proceed_payment")
    BTN_CONFIRM_BOOKING = (AppiumBy.ID, "com.bookmyeventnow.app:id/btn_confirm_booking")

    # ──────────────────────────────────────────────
    # Actions — Venue Detail
    # ──────────────────────────────────────────────

    def is_venue_detail_displayed(self):
        """Check if venue detail page is loaded."""
        result = self.is_displayed(self.LBL_VENUE_NAME) and \
                 self.is_displayed(self.BTN_BOOK_NOW)
        logger.info(f"Venue detail page displayed: {result}")
        return result

    def get_venue_name(self):
        """Return the venue name on detail page."""
        return self.get_text(self.LBL_VENUE_NAME)

    def get_venue_price(self):
        """Return displayed price."""
        return self.get_text(self.LBL_VENUE_PRICE)

    def tap_book_now(self):
        """Tap Book Now to open date picker / booking flow."""
        logger.info("Tapping 'Book Now' button")
        self.tap(self.BTN_BOOK_NOW)

    # ──────────────────────────────────────────────
    # Actions — Date Picker
    # ──────────────────────────────────────────────

    def is_date_picker_displayed(self):
        """Check if calendar / date picker is visible."""
        return self.is_displayed(self.CALENDAR_VIEW)

    def select_date_by_text(self, date_text: str):
        """
        Select a date from the calendar by its text representation.
        e.g. '1', '15', '30'
        """
        logger.info(f"Selecting date: {date_text}")
        date_locator = (
            AppiumBy.XPATH,
            f'//android.view.View[@content-desc="{date_text}"]',
        )
        self.tap(date_locator)

    def select_check_in_date(self, day: str):
        """Tap check-in date on calendar."""
        logger.info(f"Setting check-in date: day {day}")
        self.select_date_by_text(day)

    def select_check_out_date(self, day: str):
        """Tap check-out date on calendar."""
        logger.info(f"Setting check-out date: day {day}")
        self.select_date_by_text(day)

    def tap_next_month(self):
        """Navigate to next month on calendar."""
        self.tap(self.BTN_NEXT_MONTH)

    def confirm_dates(self):
        """Tap the confirm dates / Apply button."""
        logger.info("Confirming selected dates")
        self.tap(self.BTN_CONFIRM_DATES)

    def get_selected_check_in(self):
        """Return the selected check-in date text."""
        return self.get_text(self.LBL_CHECK_IN_DATE)

    def get_selected_check_out(self):
        """Return the selected check-out date text."""
        return self.get_text(self.LBL_CHECK_OUT_DATE)

    # ──────────────────────────────────────────────
    # Actions — Guest Count
    # ──────────────────────────────────────────────

    def set_guest_count(self, count: int):
        """
        Set guest count by tapping '+' button N times.
        Assumes default is 1.
        """
        logger.info(f"Setting guest count to: {count}")
        for _ in range(count - 1):
            self.tap(self.BTN_GUEST_INCREMENT)

    def get_guest_count(self):
        """Return current guest count value."""
        return self.get_text(self.LBL_GUEST_COUNT_VALUE)

    # ──────────────────────────────────────────────
    # Actions — Booking Confirmation
    # ──────────────────────────────────────────────

    def is_booking_summary_displayed(self):
        """Check if booking summary section is visible."""
        return self.is_displayed(self.LBL_TOTAL_PRICE)

    def get_total_price(self):
        """Return total price shown in booking summary."""
        return self.get_text(self.LBL_TOTAL_PRICE)

    def get_summary_dates(self):
        """Return date range text from summary."""
        return self.get_text(self.LBL_SUMMARY_DATES)

    def tap_confirm_booking(self):
        """Tap the final Confirm / Book button."""
        logger.info("Tapping 'Confirm Booking' button")
        try:
            self.tap(self.BTN_CONFIRM_BOOKING)
        except Exception:
            # Fallback to proceed payment button
            self.tap(self.BTN_PROCEED_PAYMENT)

    def scroll_to_confirm_button(self):
        """Scroll down to reach the confirm booking button."""
        self.scroll_down()
        self.scroll_down()
