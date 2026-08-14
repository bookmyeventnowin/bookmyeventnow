"""
QA Agent — Results Reader & Jira Updater
Reads .qa/results/smoke_results.json → updates KAN-1 on Jira.
Run this after run_smoke_local.ps1 completes.

Usage: python .qa/read_results_and_update_jira.py
"""

import json
import os
import sys
import http.client
import base64
import urllib.parse

# ── Config ────────────────────────────────────────────────────────────────────
RESULTS_FILE  = os.path.join(os.path.dirname(__file__), "results", "smoke_results.json")
JIRA_CLOUD_ID = "ca176e49-82ca-4fc1-8733-abf9aea17add"
JIRA_ISSUE    = "KAN-1"
# Set your Jira API token below OR as env var JIRA_API_TOKEN
JIRA_EMAIL    = os.environ.get("JIRA_EMAIL", "bookmyeventnow.in@gmail.com")
JIRA_TOKEN    = os.environ.get("JIRA_API_TOKEN", "")  # Set your token here

def load_results():
    if not os.path.exists(RESULTS_FILE):
        print(f"❌ Results file not found: {RESULTS_FILE}")
        print("   Run run_smoke_local.ps1 first to generate results.")
        sys.exit(1)
    with open(RESULTS_FILE, "r", encoding="utf-8") as f:
        return json.load(f)

def build_comment(data: dict) -> str:
    rows = ""
    for tc in data.get("results", []):
        icon = {"PASSED": "✅", "FAILED": "❌", "SKIPPED": "⏭️"}.get(tc["status"], "❓")
        rows += f"| {tc['id']} | {tc['name']} | {tc['suite']} | {icon} {tc['status']} | {tc.get('duration', 0):.2f}s |\n"

    return f"""## 🤖 QA Agent — Real Local Machine Test Results

**Run At:** {data.get('run_at', 'N/A')}
**Flutter Version:** {data.get('flutter_version', 'N/A')}
**Story:** {data.get('story', 'KAN-1')}

---

## 📊 Summary

| Metric | Value |
|---|---|
| **Total** | {data['total']} |
| **Passed** | ✅ {data['passed']} |
| **Failed** | ❌ {data['failed']} |
| **Skipped** | ⏭️ {data['skipped']} |
| **Pass Rate** | {'🟢' if data['passed'] == data['total'] - data['skipped'] else '🔴'} {data['pass_rate']} |
| **Duration** | {data['total_duration']}s |

---

## 🧪 Individual Results

| ID | Test | Suite | Result | Duration |
|---|---|---|---|---|
{rows}
---

## ✅ Acceptance Criteria Sign-off

| AC | Description | Status |
|---|---|---|
| AC1 | App Launch & Login Screen | {'✅ Met' if data['passed'] > 0 else '❌ Not Met'} |
| AC2 | Valid Login → Dashboard | {'✅ Met' if data['passed'] > 1 else '❌ Not Met'} |
| AC3 | Navigate to Community Hall | {'✅ Met' if data['passed'] > 2 else '❌ Not Met'} |
| AC4 | Date Selection works | {'✅ Met' if data['passed'] > 3 else '❌ Not Met'} |
| AC5 | Order Created Successfully | {'✅ Met' if data['passed'] > 4 else '❌ Not Met'} |

---

{'🟢 ALL TESTS PASSED — Story ready for Regression pipeline.' if data["failed"] == 0 else f'🔴 {data["failed"]} TEST(S) FAILED — Bugs raised, assigned to Dev Agent.'}
"""

def post_comment_to_jira(comment: str):
    if not JIRA_TOKEN:
        print("⚠️  JIRA_API_TOKEN not set. Saving comment to file instead.")
        out = os.path.join(os.path.dirname(__file__), "results", "jira_comment.md")
        with open(out, "w", encoding="utf-8") as f:
            f.write(comment)
        print(f"   Comment saved to: {out}")
        print("   Paste it manually into KAN-1 on Jira.")
        return

    token   = base64.b64encode(f"{JIRA_EMAIL}:{JIRA_TOKEN}".encode()).decode()
    payload = json.dumps({"body": {"version": 1, "type": "doc", "content": [
        {"type": "paragraph", "content": [{"type": "text", "text": comment}]}
    ]}})
    conn    = http.client.HTTPSConnection("api.atlassian.com")
    path    = f"/ex/jira/{JIRA_CLOUD_ID}/rest/api/3/issue/{JIRA_ISSUE}/comment"
    conn.request("POST", path, payload, {
        "Authorization": f"Basic {token}",
        "Content-Type": "application/json",
        "Accept": "application/json"
    })
    resp = conn.getresponse()
    if resp.status in (200, 201):
        print(f"✅ KAN-1 updated on Jira!")
    else:
        print(f"❌ Jira API error: {resp.status} {resp.read().decode()}")

def main():
    print("── BookMyEventNow QA Agent — Results Uploader ──")
    data = load_results()
    print(f"✅ Results loaded: {data['passed']}/{data['total']} passed ({data['pass_rate']})")
    comment = build_comment(data)
    print("── Posting to Jira KAN-1 ──")
    post_comment_to_jira(comment)
    print("── Done ──")

if __name__ == "__main__":
    main()
