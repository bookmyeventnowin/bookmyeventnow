"""
Order Confirmation Page Object — BookMyEvent Now
Covers: Success screen → Order ID → Navigate to My Bookings
"""

from appium.webdriver.common.appiumby import AppiumBy
from pages.base_page import BasePage
import logging

logger = logging.getLogger(__name__)


class ConfirmationPage(BasePage):
    """
    Page Object for the Order Confirmation / Success screen.
    Validates booking was created successfully.
    """

    # ──────────────────────────────────────────────
    # Locators
    # ──────────────────────────────────────────────

    # Success Screen
    IV_SUCCESS_ICON = (AppiumBy.ID, "com.bookmyeventnow.app:id/iv_success_icon")
    LBL_SUCCESS_TITLE = (AppiumBy.ID, "com.bookmyeventnow.app:id/tv_success_title")
    LBL_SUCCESS_MESSAGE = (AppiumBy.ID, "com.bookmyeventnow.app:id/tv_success_message")
    LBL_ORDER_ID = (AppiumBy.ID, "com.bookmyeventnow.app:id/tv_order_id")
    LBL_BOOKING_REFERENCE = (
        AppiumBy.ID,
        "com.bookmyeventnow.app:id/tv_booking_reference",
    )

    # Confirmation Details
    LBL_CONFIRMED_VENUE = (
        AppiumBy.ID,
        "com.bookmyeventnow.app:id/tv_confirmed_venue_name",
    )
    LBL_CONFIRMED_DATES = (
        AppiumBy.ID,
        "com.bookmyeventnow.app:id/tv_confirmed_dates",
    )
    LBL_CONFIRMED_GUESTS = (
        AppiumBy.ID,
        "com.bookmyeventnow.app:id/tv_confirmed_guests",
    )
    LBL_CONFIRMED_TOTAL = (
        AppiumBy.ID,
        "com.bookmyeventnow.app:id/tv_confirmed_total_price",
    )

    # CTA Buttons
    BTN_VIEW_BOOKING = (AppiumBy.ID, "com.bookmyeventnow.app:id/btn_view_booking")
    BTN_BACK_TO_HOME = (AppiumBy.ID, "com.bookmyeventnow.app:id/btn_back_to_home")
    BTN_DOWNLOAD_RECEIPT = (
        AppiumBy.ID,
        "com.bookmyeventnow.app:id/btn_download_receipt",
    )

    # Lottie animation (success animation)
    LOTTIE_SUCCESS = (AppiumBy.ID, "com.bookmyeventnow.app:id/lottie_success")

    # ──────────────────────────────────────────────
    # Actions
    # ──────────────────────────────────────────────

    def is_order_success_displayed(self):
        """
        Primary assertion — check if the success screen is visible.
        Returns True if success icon OR success title is displayed.
        """
        success = (
            self.is_displayed(self.IV_SUCCESS_ICON, timeout=20)
            or self.is_displayed(self.LBL_SUCCESS_TITLE, timeout=20)
            or self.is_displayed(self.LOTTIE_SUCCESS, timeout=20)
        )
        logger.info(f"Order success screen displayed: {success}")
        return success

    def get_success_title(self):
        """Return the success title text (e.g. 'Booking Confirmed!')."""
        return self.get_text(self.LBL_SUCCESS_TITLE)

    def get_success_message(self):
        """Return the success body message."""
        return self.get_text(self.LBL_SUCCESS_MESSAGE)

    def get_order_id(self):
        """Return the order/booking ID string."""
        order_id = self.get_text(self.LBL_ORDER_ID)
        logger.info(f"Order ID: {order_id}")
        return order_id

    def get_booking_reference(self):
        """Return booking reference number."""
        return self.get_text(self.LBL_BOOKING_REFERENCE)

    def get_confirmed_venue_name(self):
        """Return venue name shown on confirmation."""
        return self.get_text(self.LBL_CONFIRMED_VENUE)

    def get_confirmed_dates(self):
        """Return confirmed date range text."""
        return self.get_text(self.LBL_CONFIRMED_DATES)

    def get_confirmed_total(self):
        """Return total amount confirmed."""
        return self.get_text(self.LBL_CONFIRMED_TOTAL)

    def is_order_id_present(self):
        """Check if an order ID is visible (non-empty)."""
        try:
            order_id = self.get_order_id()
            return bool(order_id and order_id.strip())
        except Exception:
            return False

    def tap_view_booking(self):
        """Navigate to My Bookings detail view."""
        logger.info("Tapping 'View Booking' button")
        self.tap(self.BTN_VIEW_BOOKING)

    def tap_back_to_home(self):
        """Navigate back to home screen."""
        logger.info("Tapping 'Back to Home' button")
        self.tap(self.BTN_BACK_TO_HOME)

    def tap_download_receipt(self):
        """Download booking receipt/PDF."""
        self.tap(self.BTN_DOWNLOAD_RECEIPT)

    def capture_confirmation_screenshot(self):
        """Take screenshot of the confirmation page for test evidence."""
        return self.take_screenshot("order_confirmation_success")
