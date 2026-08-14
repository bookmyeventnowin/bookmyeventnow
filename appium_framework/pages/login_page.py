"""
Login Page Object — BookMyEvent Now
Covers: Launch → Login screen → Dashboard
"""

from appium.webdriver.common.appiumby import AppiumBy
from pages.base_page import BasePage
import logging

logger = logging.getLogger(__name__)


class LoginPage(BasePage):
    """
    Page Object for the Login Screen.
    Locators use resource-id (preferred for Android stability).
    """

    # ──────────────────────────────────────────────
    # Locators
    # ──────────────────────────────────────────────

    # Splash / Launch
    SPLASH_LOGO = (AppiumBy.ID, "com.bookmyeventnow.app:id/iv_splash_logo")

    # Login Screen
    LBL_WELCOME = (AppiumBy.ID, "com.bookmyeventnow.app:id/tv_welcome_title")
    ETF_EMAIL = (AppiumBy.ID, "com.bookmyeventnow.app:id/et_login_email")
    ETF_PASSWORD = (AppiumBy.ID, "com.bookmyeventnow.app:id/et_login_password")
    BTN_LOGIN = (AppiumBy.ID, "com.bookmyeventnow.app:id/btn_login")
    BTN_FORGOT_PASSWORD = (AppiumBy.ID, "com.bookmyeventnow.app:id/tv_forgot_password")
    LNK_REGISTER = (AppiumBy.ID, "com.bookmyeventnow.app:id/tv_register")

    # Error / Validation
    LBL_ERROR_TOAST = (AppiumBy.XPATH, "//android.widget.Toast")
    LBL_EMAIL_ERROR = (AppiumBy.ID, "com.bookmyeventnow.app:id/tv_email_error")
    LBL_PASSWORD_ERROR = (AppiumBy.ID, "com.bookmyeventnow.app:id/tv_password_error")

    # Post-login indicator
    LBL_HOME_TITLE = (AppiumBy.ID, "com.bookmyeventnow.app:id/tv_home_title")
    IV_USER_AVATAR = (AppiumBy.ID, "com.bookmyeventnow.app:id/iv_user_avatar")

    # ──────────────────────────────────────────────
    # Actions
    # ──────────────────────────────────────────────

    def wait_for_splash_to_disappear(self):
        """Wait until splash screen finishes loading."""
        logger.info("Waiting for splash screen to disappear...")
        self.wait_for_element_to_disappear(self.SPLASH_LOGO, timeout=10)

    def is_login_screen_displayed(self):
        """Verify login screen is visible."""
        result = self.is_displayed(self.ETF_EMAIL)
        logger.info(f"Login screen displayed: {result}")
        return result

    def enter_email(self, email: str):
        """Enter email address into login field."""
        self.enter_text(self.ETF_EMAIL, email)
        self.hide_keyboard()

    def enter_password(self, password: str):
        """Enter password into password field."""
        self.enter_text(self.ETF_PASSWORD, password)
        self.hide_keyboard()

    def tap_login_button(self):
        """Tap the Login / Sign In button."""
        self.tap(self.BTN_LOGIN)
        logger.info("Tapped Login button")

    def login(self, email: str, password: str):
        """
        High-level action: enter credentials and tap login.
        Returns True if login was successful (home screen visible).
        """
        logger.info(f"Attempting login with email: {email}")
        self.enter_email(email)
        self.enter_password(password)
        self.tap_login_button()

    def is_login_successful(self):
        """
        Verify successful login by checking home screen indicator.
        Returns True if user avatar or home title is visible.
        """
        success = self.is_displayed(self.IV_USER_AVATAR, timeout=15) or \
                  self.is_displayed(self.LBL_HOME_TITLE, timeout=15)
        logger.info(f"Login successful: {success}")
        return success

    def get_email_validation_error(self):
        """Return email field validation error message."""
        return self.get_text(self.LBL_EMAIL_ERROR)

    def get_password_validation_error(self):
        """Return password field validation error message."""
        return self.get_text(self.LBL_PASSWORD_ERROR)

    def get_toast_message(self):
        """Capture toast notification message."""
        try:
            return self.get_text(self.LBL_ERROR_TOAST)
        except Exception:
            return ""
