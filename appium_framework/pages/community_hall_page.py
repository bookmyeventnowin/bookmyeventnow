"""
Community Hall Listing Page Object — BookMyEvent Now
Covers: Category listing → Venue detail selection
"""

from appium.webdriver.common.appiumby import AppiumBy
from pages.base_page import BasePage
import logging

logger = logging.getLogger(__name__)


class CommunityHallPage(BasePage):
    """
    Page Object for the Community Hall category listing screen.
    Handles venue list, filters, and navigating to a venue detail.
    """

    # ──────────────────────────────────────────────
    # Locators
    # ──────────────────────────────────────────────

    # Page Header
    LBL_PAGE_TITLE = (AppiumBy.ID, "com.bookmyeventnow.app:id/tv_category_title")
    BTN_BACK = (AppiumBy.ID, "com.bookmyeventnow.app:id/iv_back")

    # Filter / Sort
    BTN_FILTER = (AppiumBy.ID, "com.bookmyeventnow.app:id/btn_filter")
    BTN_SORT = (AppiumBy.ID, "com.bookmyeventnow.app:id/btn_sort")
    LBL_RESULT_COUNT = (AppiumBy.ID, "com.bookmyeventnow.app:id/tv_result_count")

    # Venue List (RecyclerView)
    RV_VENUE_LIST = (AppiumBy.ID, "com.bookmyeventnow.app:id/rv_venue_list")
    VENUE_CARD_FIRST = (
        AppiumBy.XPATH,
        "(//androidx.recyclerview.widget.RecyclerView[@resource-id='com.bookmyeventnow.app:id/rv_venue_list']"
        "//android.view.ViewGroup)[1]",
    )
    VENUE_NAME_LABEL = (AppiumBy.ID, "com.bookmyeventnow.app:id/tv_venue_name")
    VENUE_PRICE_LABEL = (AppiumBy.ID, "com.bookmyeventnow.app:id/tv_venue_price")
    VENUE_RATING_LABEL = (AppiumBy.ID, "com.bookmyeventnow.app:id/tv_venue_rating")
    VENUE_AVAILABILITY_BADGE = (
        AppiumBy.ID,
        "com.bookmyeventnow.app:id/tv_availability_badge",
    )

    # Empty State
    IV_EMPTY_STATE = (AppiumBy.ID, "com.bookmyeventnow.app:id/iv_empty_state")
    LBL_EMPTY_MESSAGE = (AppiumBy.ID, "com.bookmyeventnow.app:id/tv_empty_message")

    # ──────────────────────────────────────────────
    # Actions
    # ──────────────────────────────────────────────

    def is_community_hall_listing_displayed(self):
        """Confirm Community Hall listing page is loaded."""
        result = self.is_displayed(self.RV_VENUE_LIST) or \
                 self.is_displayed(self.LBL_PAGE_TITLE)
        logger.info(f"Community Hall listing displayed: {result}")
        return result

    def get_page_title(self):
        """Return page title text."""
        return self.get_text(self.LBL_PAGE_TITLE)

    def get_venue_count(self):
        """Return the number of venue cards currently displayed."""
        venues = self.find_all(self.VENUE_NAME_LABEL)
        count = len(venues)
        logger.info(f"Venue count visible: {count}")
        return count

    def get_result_count_text(self):
        """Return result count label text (e.g. '12 venues found')."""
        return self.get_text(self.LBL_RESULT_COUNT)

    def select_first_available_venue(self):
        """Tap the first venue card in the listing."""
        logger.info("Selecting first available venue in Community Hall listing")
        self.tap(self.VENUE_CARD_FIRST)

    def select_venue_by_name(self, venue_name: str):
        """
        Scroll until the named venue is visible and tap it.
        """
        logger.info(f"Selecting venue: {venue_name}")
        self.scroll_to_text(venue_name)
        locator = (
            AppiumBy.XPATH,
            f'//android.widget.TextView[@text="{venue_name}"]',
        )
        self.tap(locator)

    def is_venue_list_empty(self):
        """Check if the empty state is shown (no venues available)."""
        return self.is_displayed(self.IV_EMPTY_STATE)

    def tap_back(self):
        """Navigate back to home screen."""
        self.tap(self.BTN_BACK)

    def apply_filter(self):
        """Open the filter panel."""
        self.tap(self.BTN_FILTER)
        logger.info("Opened filter panel")

    def get_first_venue_name(self):
        """Return the name text of the first venue card."""
        venues = self.find_all(self.VENUE_NAME_LABEL)
        if venues:
            return venues[0].text
        return None
