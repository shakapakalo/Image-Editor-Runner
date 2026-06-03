"""
Statsig ID generator for reverse interfaces.

PR #567 fix applied: prefix changed from "e:" to "x1:" to match
what real browsers send as the Statsig evaluation fallback value.
"""

import base64
import random
import string

from app.core.logger import logger
from app.core.config import get_config


class StatsigGenerator:
    """Statsig ID generator for reverse interfaces."""

    @staticmethod
    def _rand(length: int, alphanumeric: bool = False) -> str:
        """Generate random string."""
        chars = (
            string.ascii_lowercase + string.digits
            if alphanumeric
            else string.ascii_lowercase
        )
        return "".join(random.choices(chars, k=length))

    @staticmethod
    def gen_id() -> str:
        """
        Generate Statsig ID.

        The real browser's fetch interceptor tries to evaluate Statsig gates
        for each request. When the SDK is not yet initialised it catches the
        error and falls back to:
            catch(e) { t = btoa("x1:" + e) }
        The prefix MUST be "x1:" — anything else (e.g. the old "e:") is
        rejected by Grok's anti-bot rules with HTTP 403.

        Returns:
            Base64 encoded ID.
        """
        dynamic = get_config("app.dynamic_statsig")

        if dynamic:
            logger.debug("Generating dynamic Statsig ID")

            rand_var = "".join(random.choices(string.ascii_lowercase, k=random.randint(1, 8)))

            if random.choice([True, False]):
                rand = StatsigGenerator._rand(5, alphanumeric=True)
                message = f"x1:TypeError: Cannot read properties of null (reading 'children['{rand}']')"
            else:
                rand = StatsigGenerator._rand(10)
                message = (
                    f"x1:TypeError: Cannot read properties of undefined (reading '{rand}')"
                )

            return base64.b64encode(message.encode()).decode()

        logger.debug("Generating static Statsig ID")
        return base64.b64encode(
            b"x1:TypeError: Cannot read properties of undefined (reading 'childNodes')"
        ).decode()


__all__ = ["StatsigGenerator"]
