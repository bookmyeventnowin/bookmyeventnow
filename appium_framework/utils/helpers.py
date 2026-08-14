"""
Test Helpers — BookMyEvent Now Appium Suite
Common utility functions for test data, date calculation, and reporting.
"""

import json
import os
import time
import logging
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)


def get_future_date(days_ahead: int = 7, fmt: str = "%d") -> str:
    """
    Return a future date offset by `days_ahead` from today.
    Default format returns the day number only (for calendar selection).
    """
    future = datetime.today() + timedelta(days=days_ahead)
    return future.strftime(fmt)


def get_date_range(check_in_offset: int = 7, check_out_offset: int = 9):
    """
    Returns (check_in_day, check_out_day) as day-number strings.
    Used for calendar date picker interaction.
    """
    check_in_day = get_future_date(check_in_offset)
    check_out_day = get_future_date(check_out_offset)
    logger.info(
        f"Date range: Check-in day={check_in_day}, Check-out day={check_out_day}"
    )
    return check_in_day, check_out_day


def load_test_data(filename: str = "caps.json") -> dict:
    """Load test data from the config directory."""
    config_path = os.path.join(
        os.path.dirname(os.path.dirname(__file__)), "config", filename
    )
    with open(config_path, "r") as f:
        return json.load(f)


def generate_timestamp(fmt: str = "%Y%m%d_%H%M%S") -> str:
    """Return current timestamp formatted as string."""
    return datetime.now().strftime(fmt)


def wait_and_retry(func, retries: int = 3, delay: float = 1.5):
    """
    Retry a function call up to `retries` times with `delay` between attempts.
    Raises last exception if all retries fail.
    """
    last_exception = None
    for attempt in range(1, retries + 1):
        try:
            return func()
        except Exception as e:
            last_exception = e
            logger.warning(
                f"Retry {attempt}/{retries} failed: {e}. Waiting {delay}s..."
            )
            time.sleep(delay)
    raise last_exception


def assert_text_contains(actual: str, expected: str, field: str = "field"):
    """
    Assert that `actual` contains `expected` (case-insensitive).
    Provides clear failure messages for test reports.
    """
    assert expected.lower() in actual.lower(), (
        f"Assertion FAIL | {field}: expected to contain '{expected}', got '{actual}'"
    )
    logger.info(f"PASS | {field} contains '{expected}'")


def extract_order_id_from_text(text: str) -> str:
    """
    Extract order ID from a string like 'Order #BME-2026-00123'.
    Returns the ID portion or the full text if pattern not matched.
    """
    import re
    match = re.search(r"(BME[-\s]?\d+|#[\w-]+|\d{6,})", text)
    if match:
        return match.group(0)
    return text.strip()
