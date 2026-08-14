"""
conftest.py — BookMyEvent Now Appium Test Suite
Global fixtures: Appium driver setup, test data, teardown, screenshots on failure.
"""

import json
import os
import time
import pytest
import logging
from appium import webdriver
from appium.options import UiAutomator2Options

# ──────────────────────────────────────────────
# Logging Configuration
# ──────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)

# ──────────────────────────────────────────────
# Config Loader
# ──────────────────────────────────────────────

CONFIG_PATH = os.path.join(os.path.dirname(__file__), "config", "caps.json")


def load_config() -> dict:
    """Load capabilities and test data from caps.json."""
    with open(CONFIG_PATH, "r") as f:
        return json.load(f)


# ──────────────────────────────────────────────
# Session-scoped Config Fixture
# ──────────────────────────────────────────────

@pytest.fixture(scope="session")
def config():
    """Return the full config dictionary (session-scoped)."""
    return load_config()


@pytest.fixture(scope="session")
def test_data(config):
    """Expose test_data section of caps.json."""
    return config["test_data"]


# ──────────────────────────────────────────────
# Appium Driver Fixture (function-scoped)
# ──────────────────────────────────────────────

@pytest.fixture(scope="function")
def driver(config):
    """
    Initialize and yield an Appium driver for each test function.
    Automatically quits after each test (pass or fail).
    """
    android_caps = config["android"]
    server = config["appium_server"]
    timeouts = config["timeouts"]

    options = UiAutomator2Options()
    options.platform_name = android_caps["platformName"]
    options.device_name = android_caps["deviceName"]
    options.platform_version = android_caps["platformVersion"]
    options.app_package = android_caps["appPackage"]
    options.app_activity = android_caps["appActivity"]
    options.automation_name = android_caps["automationName"]
    options.no_reset = android_caps["noReset"]
    options.full_reset = android_caps["fullReset"]
    options.new_command_timeout = android_caps["newCommandTimeout"]
    options.auto_grant_permissions = android_caps["autoGrantPermissions"]

    appium_url = (
        f"http://{server['host']}:{server['port']}{server['base_path']}"
    )
    logger.info(f"Connecting to Appium server: {appium_url}")

    _driver = webdriver.Remote(
        command_executor=appium_url,
        options=options,
    )
    _driver.implicitly_wait(timeouts["implicit_wait"])

    logger.info("Appium driver initialized successfully")
    yield _driver

    logger.info("Quitting Appium driver")
    _driver.quit()


# ──────────────────────────────────────────────
# Screenshot on Failure Hook
# ──────────────────────────────────────────────

@pytest.hookimpl(tryfirst=True, hookwrapper=True)
def pytest_runtest_makereport(item, call):
    """
    Capture screenshot automatically on test FAILURE.
    Attaches to Allure report if allure-pytest is installed.
    """
    outcome = yield
    report = outcome.get_result()

    if report.when == "call" and report.failed:
        driver_fixture = item.funcargs.get("driver")
        if driver_fixture:
            timestamp = time.strftime("%Y%m%d_%H%M%S")
            test_name = item.name.replace(" ", "_")
            screenshot_dir = os.path.join("reports", "screenshots")
            os.makedirs(screenshot_dir, exist_ok=True)
            screenshot_path = os.path.join(
                screenshot_dir, f"FAIL_{test_name}_{timestamp}.png"
            )
            driver_fixture.save_screenshot(screenshot_path)
            logger.error(f"Test FAILED. Screenshot saved: {screenshot_path}")

            # Allure attachment (optional)
            try:
                import allure
                with open(screenshot_path, "rb") as img:
                    allure.attach(
                        img.read(),
                        name=f"Failure Screenshot - {test_name}",
                        attachment_type=allure.attachment_type.PNG,
                    )
            except ImportError:
                pass


# ──────────────────────────────────────────────
# Reports Directory Setup
# ──────────────────────────────────────────────

@pytest.fixture(scope="session", autouse=True)
def setup_report_dirs():
    """Create report directories before test session starts."""
    os.makedirs("reports/screenshots", exist_ok=True)
    os.makedirs("reports/html", exist_ok=True)
    os.makedirs("reports/allure-results", exist_ok=True)
    logger.info("Report directories ready")
    yield
