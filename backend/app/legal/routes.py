from __future__ import annotations

from fastapi import APIRouter
from fastapi.responses import HTMLResponse

router = APIRouter(prefix="/legal", tags=["legal"])

_CONTACT_EMAIL = "mdfaizanrasheed123@gmail.com"
_APP_NAME = "Learning with Game"

_STYLE = """
<style>
  body { font-family: -apple-system, Segoe UI, Roboto, Arial, sans-serif; max-width: 720px;
         margin: 40px auto; padding: 0 20px; line-height: 1.6; color: #1a1a2e; }
  h1 { font-size: 26px; }
  h2 { font-size: 18px; margin-top: 28px; }
  a { color: #0d9488; }
  .updated { color: #666; font-size: 13px; }
</style>
"""


@router.get("/privacy", response_class=HTMLResponse)
async def privacy_policy() -> HTMLResponse:
    return HTMLResponse(f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Privacy Policy — {_APP_NAME}</title>{_STYLE}</head>
<body>
<h1>Privacy Policy</h1>
<p class="updated">Last updated: 2026-09-02</p>

<p>{_APP_NAME} ("the app") is an Islamic-learning quiz app. This page explains what
information the app collects and how it's used.</p>

<h2>What we collect</h2>
<ul>
  <li><strong>Registered accounts:</strong> email address, display name, and (if you
    provide it) gender.</li>
  <li><strong>Guest accounts:</strong> only a display name — no email is collected at all.</li>
  <li><strong>Gameplay data:</strong> your quiz answers, scores, XP, streaks, achievement
    progress, and multiplayer match history.</li>
  <li><strong>Social features:</strong> your friend connections (added via a friend code)
    and any friend challenges you take part in.</li>
  <li><strong>User-submitted content:</strong> any question you submit through the
    "contribute a question" feature, which an admin reviews before it's shown to other
    players.</li>
</ul>

<h2>What we don't do</h2>
<p>We don't run any advertising or analytics SDK, don't track you across other apps or
websites, and don't sell your data to anyone. Your password is never stored in plain
text — only a salted hash.</p>

<h2>How your data is used</h2>
<p>Solely to run the app itself: authenticating you, tracking your progress, ranking
leaderboards, and matching you with other players. Your hosting provider's standard
server logs (e.g. IP address, for abuse prevention) may be retained briefly as part of
normal infrastructure operation.</p>

<h2>Deleting your data</h2>
<p>You can permanently delete your account and all associated data at any time from the
app: open your Profile screen and use "Delete Account" in the Danger Zone section. This
immediately and permanently removes your account — there is no recovery. You can also
request deletion by emailing us at the address below.</p>

<h2>Children</h2>
<p>This app is educational and family-friendly, but is not specifically directed at
children under 13, and registration requires an email address.</p>

<h2>Contact</h2>
<p>Questions about this policy or your data: <a href="mailto:{_CONTACT_EMAIL}">{_CONTACT_EMAIL}</a></p>
</body></html>""")


@router.get("/terms", response_class=HTMLResponse)
async def terms_of_service() -> HTMLResponse:
    return HTMLResponse(f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Terms of Service — {_APP_NAME}</title>{_STYLE}</head>
<body>
<h1>Terms of Service</h1>
<p class="updated">Last updated: 2026-09-02</p>

<p>By using {_APP_NAME}, you agree to the following terms.</p>

<h2>Acceptable use</h2>
<p>Play fairly, don't attempt to cheat, exploit, or disrupt the service for other users,
and don't submit content that is abusive, illegal, or infringes someone else's rights.
Accounts that violate this may be suspended or removed.</p>

<h2>User-submitted content</h2>
<p>Questions submitted through the "contribute a question" feature are reviewed by an
admin before they're shown to other players; we may edit, reject, or remove submitted
or in-game content at our discretion.</p>

<h2>No warranty</h2>
<p>The app is provided "as is," without warranty of any kind. We don't guarantee
uninterrupted or error-free operation.</p>

<h2>Changes</h2>
<p>These terms may be updated from time to time; continued use of the app after a
change means you accept the updated terms.</p>

<h2>Contact</h2>
<p><a href="mailto:{_CONTACT_EMAIL}">{_CONTACT_EMAIL}</a></p>
</body></html>""")
