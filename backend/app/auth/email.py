"""Password-reset email delivery via Resend. Isolated so it's easy to test
and so the rest of the auth module doesn't care how (or whether) the email
actually gets sent."""

from __future__ import annotations

import httpx

from ..config import settings


async def send_reset_email(*, to: str, reset_url: str) -> None:
    """Send the password-reset link. If RESEND_API_KEY isn't configured, logs
    the link instead of sending — keeps the feature fully testable before a
    real email provider is wired up, without ever failing the request."""
    if not settings.resend_api_key:
        print(f"[email] RESEND_API_KEY unset — password reset link for {to}: {reset_url}")
        return

    async with httpx.AsyncClient(timeout=10) as client:
        res = await client.post(
            "https://api.resend.com/emails",
            headers={"Authorization": f"Bearer {settings.resend_api_key}"},
            json={
                "from": settings.email_from,
                "to": [to],
                "subject": "Reset your password",
                "html": (
                    f"<p>Someone requested a password reset for your account.</p>"
                    f'<p><a href="{reset_url}">Click here to set a new password</a>. '
                    f"This link expires in 1 hour.</p>"
                    f"<p>If you didn't request this, you can safely ignore this email.</p>"
                ),
            },
        )
        if res.status_code >= 400:
            print(f"[email] Resend API error ({res.status_code}): {res.text}")
