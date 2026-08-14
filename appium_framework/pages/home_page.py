"""
Home / Dashboard Page Object — BookMyEvent Now
Covers: Dashboard → Category Selection
"""

from appium.webdriver.common.appiumby import AppiumBy
from pages.base_page import BasePage
import logging

logger = logging.getLogger(__name__)


class HomePage(BasePage):
    """
    Page Object for Home / Dashboard Screen.
    Contains category grid, search bar, and bottom navigation.
    """

    # ──────────────────────────────────────────────
    # Locators
    # ──────────────────────────────────────────────

    # Header
    LBL_HOME_TITLE = (AppiumBy.ID, "com.bookmyeventnow.app:id/tv_home_title")
    IV_USER_AVATAR = (AppiumBy.ID, "com.bookmyeventnow.app:id/iv_user_avatar")
    BTN_NOTIFICATION = (AppiumBy.ID, "com.bookmyeventnow.app:id/iv_notification")

    # Search Bar
    ETF_SEARCH = (AppiumBy.ID, "com.bookmyeventnow.app:id/et_search")
    BTN_SEARCH_ICON = (AppiumBy.ID, "com.bookmyeventnow.app:id/iv_search_icon")

    # Category Cards (RecyclerView)
    RV_CATEGORIES = (AppiumBy.ID, "com.bookmyeventnow.app:id/rv_categories")
    CATEGORY_COMMUNITY_HALL = (
        AppiumBy.XPATH,
        '//android.widget.TextView[@text="Community Hall"]',
    )
    CATEGORY_BANQUET_HALL = (
        AppiumBy.XPATH,
        '//android.widget.TextView[@text="Banquet Hall"]',
    )
    CATEGORY_MARRIAGE_HALL = (
        AppiumBy.XPATH,
        '//android.widget.TextView[@text="Marriage Hall"]',
    )
    CATEGORY_CONFERENCE_ROOM = (
        AppiumBy.XPATH,
        '//android.widget.TextView[@text="Conference Room"]',
    )

    # Featured / Banner
    VP_BANNER = (AppiumBy.ID, "com.bookmyeventnow.app:id/vp_featured_banner")

    # Bottom Navigation
    NAV_HOME = (AppiumBy.ID, "com.bookmyeventnow.app:id/nav_home")
    NAV_BOOKINGS = (AppiumBy.ID, "com.bookmyeventnow.app:id/nav_my_bookings")
    NAV_PROFILE = (AppiumBy.ID, "com.bookmyeventnow.app:id/nav_profile")

    # ──────────────────────────────────────────────
    # Actions
    # ──────────────────────────────────────────────

    def is_home_screen_displayed(self):
        """Verify home/dashboard screen is fully loaded."""
        result = self.is_displayed(self.LBL_HOME_TITLE) or \
                 self.is_displayed(self.RV_CATEGORIES)
        logger.info(f"Home screen displayed: {result}")
        return result

    def get_welcome_title(self):
        """Return the home screen title text."""
        return self.get_text(self.LBL_HOME_TITLE)

    def tap_category_community_hall(self):
        """Tap on Community Hall category card."""
        logger.info("Tapping on 'Community Hall' category")
        try:
            self.tap(self.CATEGORY_COMMUNITY_HALL)
        except Exception:
            # Fallback: scroll down if category not immediately visible
            self.scroll_down()
            self.tap(self.CATEGORY_COMMUNITY_HALL)

    def tap_category_by_name(self, category_name: str):
        """
        Generic category selector — tap any category by its display name.
        Uses UiAutomator scroll for reliability.
        """
        logger.info(f"Navigating to category: {category_name}")
        self.scroll_to_text(category_name)
        locator = (
            AppiumBy.XPATH,
            f'//android.widget.TextView[@text="{category_name}"]',
        )
        self.tap(locator)

    def search_for(self, keyword: str):
        """Use search bar to find a venue."""
        self.tap(self.ETF_SEARCH)
        self.enter_text(self.ETF_SEARCH, keyword)
        self.hide_keyboard()
        logger.info(f"Searched for: {keyword}")

    def tap_my_bookings(self):
        """Navigate to My Bookings tab."""
        self.tap(self.NAV_BOOKINGS)

    def tap_profile(self):
        """Navigate to Profile tab."""
        self.tap(self.NAV_PROFILE)

    def is_user_logged_in(self):
        """Confirm user is logged in via avatar or greeting."""
        return self.is_displayed(self.IV_USER_AVATAR)
