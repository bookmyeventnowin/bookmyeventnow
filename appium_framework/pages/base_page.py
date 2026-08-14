"""
Base Page Object — BookMyEvent Now
All page objects inherit from this class.
Framework : Appium + Python + pytest (POM)
"""

import time
import logging
from appium.webdriver.common.appiumby import AppiumBy
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import (
    TimeoutException,
    NoSuchElementException,
    ElementNotVisibleException,
)

logger = logging.getLogger(__name__)


class BasePage:
    """
    Base class for all Page Objects.
    Provides reusable helper methods for element interaction.
    """

    def __init__(self, driver):
        self.driver = driver
        self.wait = WebDriverWait(driver, 20)
        self.short_wait = WebDriverWait(driver, 10)

    # ──────────────────────────────────────────────
    # Element Finders
    # ──────────────────────────────────────────────

    def find_element(self, locator):
        """Wait for an element to be present and return it."""
        try:
            return self.wait.until(EC.presence_of_element_located(locator))
        except TimeoutException:
            logger.error(f"Element NOT found: {locator}")
            raise

    def find_clickable(self, locator):
        """Wait for element to be clickable and return it."""
        try:
            return self.wait.until(EC.element_to_be_clickable(locator))
        except TimeoutException:
            logger.error(f"Element NOT clickable: {locator}")
            raise

    def find_visible(self, locator):
        """Wait for element to be visible and return it."""
        try:
            return self.wait.until(EC.visibility_of_element_located(locator))
        except TimeoutException:
            logger.error(f"Element NOT visible: {locator}")
            raise

    def find_all(self, locator):
        """Return list of all matching elements."""
        return self.driver.find_elements(*locator)

    # ──────────────────────────────────────────────
    # Element Actions
    # ──────────────────────────────────────────────

    def tap(self, locator):
        """Tap / click on element."""
        element = self.find_clickable(locator)
        element.click()
        logger.info(f"Tapped: {locator}")

    def enter_text(self, locator, text):
        """Clear field and enter text."""
        element = self.find_element(locator)
        element.clear()
        element.send_keys(text)
        logger.info(f"Entered '{text}' into {locator}")

    def get_text(self, locator):
        """Return visible text of element."""
        element = self.find_visible(locator)
        text = element.text
        logger.info(f"Got text '{text}' from {locator}")
        return text

    def is_displayed(self, locator, timeout=5):
        """Check if element is displayed (non-blocking)."""
        try:
            WebDriverWait(self.driver, timeout).until(
                EC.visibility_of_element_located(locator)
            )
            return True
        except TimeoutException:
            return False

    def is_element_present(self, locator):
        """Returns True if element exists in DOM."""
        return len(self.driver.find_elements(*locator)) > 0

    # ──────────────────────────────────────────────
    # Scroll Helpers
    # ──────────────────────────────────────────────

    def scroll_down(self):
        """Scroll down on the screen."""
        size = self.driver.get_window_size()
        start_x = size["width"] // 2
        start_y = int(size["height"] * 0.8)
        end_y = int(size["height"] * 0.2)
        self.driver.swipe(start_x, start_y, start_x, end_y, 500)
        logger.info("Scrolled down")

    def scroll_up(self):
        """Scroll up on the screen."""
        size = self.driver.get_window_size()
        start_x = size["width"] // 2
        start_y = int(size["height"] * 0.2)
        end_y = int(size["height"] * 0.8)
        self.driver.swipe(start_x, start_y, start_x, end_y, 500)
        logger.info("Scrolled up")

    def scroll_to_text(self, text):
        """Scroll until text is visible (UiAutomator2 specific)."""
        self.driver.find_element(
            AppiumBy.ANDROID_UIAUTOMATOR,
            f'new UiScrollable(new UiSelector().scrollable(true)).scrollIntoView(new UiSelector().text("{text}"))',
        )
        logger.info(f"Scrolled to text: '{text}'")

    # ──────────────────────────────────────────────
    # Wait Helpers
    # ──────────────────────────────────────────────

    def wait_for_seconds(self, seconds):
        """Static wait — use sparingly."""
        time.sleep(seconds)

    def wait_for_element_to_disappear(self, locator, timeout=15):
        """Wait until element is no longer visible."""
        try:
            WebDriverWait(self.driver, timeout).until(
                EC.invisibility_of_element_located(locator)
            )
            logger.info(f"Element disappeared: {locator}")
        except TimeoutException:
            logger.warning(f"Element still visible after {timeout}s: {locator}")

    # ──────────────────────────────────────────────
    # Screenshot
    # ──────────────────────────────────────────────

    def take_screenshot(self, name="screenshot"):
        """Save screenshot to reports folder."""
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        path = f"reports/screenshots/{name}_{timestamp}.png"
        self.driver.save_screenshot(path)
        logger.info(f"Screenshot saved: {path}")
        return path

    def hide_keyboard(self):
        """Dismiss on-screen keyboard if present."""
        try:
            self.driver.hide_keyboard()
        except Exception:
            pass
