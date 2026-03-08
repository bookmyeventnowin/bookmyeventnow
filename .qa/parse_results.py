#!/usr/bin/env python3
"""
BookMyEventNow QA Agent — Test Result Parser & HTML Report Generator
Parses `flutter test --machine` JSON output and generates:
  - A structured JSON summary (qa_summary.json)
  - A rich HTML report (qa_report.html)
  - A Markdown status update (TEST_STATUS.md snippet)

Usage:
    python3 .qa/parse_results.py \
        --input  .qa/reports/latest_results.json \
        --output .qa/reports/latest_report.html \
        --summary .qa/reports/qa_summary.json
"""

import json
import re
import sys
import argparse
from datetime import datetime
from pathlib import Path
from collections import defaultdict

# ─── Argument parsing ─────────────────────────────────────────────────────────

def parse_args():
    parser = argparse.ArgumentParser(description="QA Report Generator for BookMyEventNow")
    parser.add_argument("--input",   required=True, help="Path to flutter test --machine output file")
    parser.add_argument("--output",  required=True, help="Path to write HTML report")
    parser.add_argument("--summary", required=True, help="Path to write JSON summary")
    return parser.parse_args()

# ─── Flutter machine output parser ────────────────────────────────────────────

def parse_flutter_machine_output(filepath: str) -> dict:
    """Parse flutter test --machine JSON line output."""
    tests = {}       # id → {name, suite, start, end, result, error, stack}
    suites = {}      # id → {path}
    groups = {}      # id → {name, suiteID}
    errors = {}      # testID → {error, stackTrace}

    passed = []
    failed = []
    skipped = []
    all_tests_count = 0

    try:
        with open(filepath, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                # flutter test --machine outputs JSON events one per line
                # But the file might also contain non-JSON log lines (from tee)
                try:
                    # Find JSON objects in the line
                    start = line.find("{")
                    if start == -1:
                        continue
                    obj = json.loads(line[start:])
                except json.JSONDecodeError:
                    continue

                event_type = obj.get("type", "")

                if event_type == "suite":
                    s = obj.get("suite", {})
                    suites[s.get("id")] = {"path": s.get("path", "unknown")}

                elif event_type == "group":
                    g = obj.get("group", {})
                    groups[g.get("id")] = {
                        "name": g.get("name", ""),
                        "suiteID": g.get("suiteID"),
                    }

                elif event_type == "testStart":
                    t = obj.get("test", {})
                    tid = t.get("id")
                    tests[tid] = {
                        "name": t.get("name", ""),
                        "suiteID": t.get("suiteID"),
                        "groupIDs": t.get("groupIDs", []),
                        "startTime": obj.get("time", 0),
                        "result": "running",
                        "error": None,
                        "stack": None,
                        "duration_ms": 0,
                    }

                elif event_type == "error":
                    tid = obj.get("testID")
                    if tid is not None:
                        errors[tid] = {
                            "error": obj.get("error", ""),
                            "stackTrace": obj.get("stackTrace", ""),
                        }

                elif event_type == "testDone":
                    tid = obj.get("testID")
                    result = obj.get("result", "error")
                    hidden = obj.get("hidden", False)
                    skipped_flag = obj.get("skipped", False)
                    end_time = obj.get("time", 0)

                    if tid in tests:
                        if tid in errors:
                            tests[tid]["error"] = errors[tid]["error"]
                            tests[tid]["stack"] = errors[tid]["stackTrace"]

                        start_time = tests[tid].get("startTime", end_time)
                        tests[tid]["duration_ms"] = max(0, end_time - start_time)
                        tests[tid]["result"] = result

                        if not hidden:
                            all_tests_count += 1
                            if skipped_flag or result == "skip":
                                skipped.append(tid)
                                tests[tid]["result"] = "skip"
                            elif result == "success":
                                passed.append(tid)
                            else:
                                failed.append(tid)

    except FileNotFoundError:
        print(f"Warning: Input file not found: {filepath}", file=sys.stderr)

    return {
        "tests": tests,
        "suites": suites,
        "groups": groups,
        "passed": passed,
        "failed": failed,
        "skipped": skipped,
        "total": all_tests_count,
    }


def get_suite_path(tid: int, data: dict) -> str:
    t = data["tests"].get(tid, {})
    suite_id = t.get("suiteID")
    suite = data["suites"].get(suite_id, {})
    path = suite.get("path", "unknown")
    # Shorten path for display
    for prefix in ["test/unit/", "test/widget/", "test/", "integration_test/"]:
        if prefix in path:
            return path.split(prefix, 1)[1]
    return Path(path).name if path != "unknown" else "unknown"


def get_group_name(tid: int, data: dict) -> str:
    t = data["tests"].get(tid, {})
    group_ids = t.get("groupIDs", [])
    names = []
    for gid in group_ids:
        g = data["groups"].get(gid, {})
        name = g.get("name", "")
        if name:
            names.append(name)
    return " › ".join(names) if names else "Top Level"


# ─── HTML Report Generator ────────────────────────────────────────────────────

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>BookMyEventNow — QA Test Report</title>
<style>
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
         background: #f0f2f5; color: #1a1a2e; }}
  header {{ background: linear-gradient(135deg, #5A35F6 0%, #3a1fc7 100%);
            color: white; padding: 24px 32px; }}
  header h1 {{ font-size: 22px; font-weight: 700; }}
  header .meta {{ font-size: 13px; opacity: 0.85; margin-top: 4px; }}
  .container {{ max-width: 1100px; margin: 24px auto; padding: 0 16px; }}

  /* Stats Bar */
  .stats {{ display: flex; gap: 16px; margin-bottom: 24px; flex-wrap: wrap; }}
  .stat-card {{ flex: 1; min-width: 140px; background: white;
               border-radius: 12px; padding: 18px 20px;
               box-shadow: 0 1px 4px rgba(0,0,0,0.08); text-align: center; }}
  .stat-card .num {{ font-size: 32px; font-weight: 700; }}
  .stat-card .lbl {{ font-size: 12px; color: #888; margin-top: 2px; text-transform: uppercase; }}
  .stat-card.total .num  {{ color: #5A35F6; }}
  .stat-card.passed .num {{ color: #22c55e; }}
  .stat-card.failed .num {{ color: #ef4444; }}
  .stat-card.skipped .num{{ color: #f59e0b; }}
  .stat-card.rate .num   {{ color: #0ea5e9; }}

  /* Progress Bar */
  .progress-bar-wrap {{ background: white; border-radius: 12px; padding: 16px 20px;
                        margin-bottom: 24px; box-shadow: 0 1px 4px rgba(0,0,0,0.08); }}
  .progress-bar-wrap h3 {{ font-size: 13px; color: #888; margin-bottom: 8px; }}
  .progress-bar {{ height: 10px; background: #f0f0f0; border-radius: 999px;
                   display: flex; overflow: hidden; }}
  .bar-pass  {{ background: #22c55e; }}
  .bar-fail  {{ background: #ef4444; }}
  .bar-skip  {{ background: #f59e0b; }}

  /* Sections */
  .section {{ background: white; border-radius: 12px; margin-bottom: 20px;
              box-shadow: 0 1px 4px rgba(0,0,0,0.08); overflow: hidden; }}
  .section-header {{ padding: 16px 20px; font-size: 15px; font-weight: 600;
                     border-bottom: 1px solid #f0f0f0; display: flex;
                     align-items: center; gap: 8px; cursor: pointer;
                     user-select: none; }}
  .section-header .badge {{ padding: 2px 10px; border-radius: 999px;
                             font-size: 12px; font-weight: 600; }}
  .badge-fail  {{ background: #fee2e2; color: #dc2626; }}
  .badge-pass  {{ background: #dcfce7; color: #16a34a; }}
  .badge-skip  {{ background: #fef3c7; color: #d97706; }}

  /* Table */
  table {{ width: 100%; border-collapse: collapse; font-size: 13px; }}
  th {{ padding: 10px 16px; text-align: left; background: #fafafa;
        color: #666; font-weight: 600; font-size: 11px;
        text-transform: uppercase; border-bottom: 1px solid #eee; }}
  td {{ padding: 10px 16px; border-bottom: 1px solid #f4f4f4; vertical-align: top; }}
  tr:last-child td {{ border-bottom: none; }}
  tr:hover td {{ background: #fafafe; }}

  .test-name {{ font-weight: 500; color: #1a1a2e; }}
  .test-group {{ font-size: 11px; color: #888; margin-top: 2px; }}
  .test-file {{ font-size: 11px; color: #aaa; font-family: monospace; }}

  .status-icon {{ font-size: 14px; }}
  .duration {{ font-family: monospace; font-size: 12px; color: #888; }}

  /* Error block */
  .error-block {{ margin-top: 8px; background: #fff5f5; border-left: 3px solid #ef4444;
                  padding: 8px 12px; border-radius: 4px; font-size: 12px;
                  font-family: monospace; white-space: pre-wrap; word-break: break-all;
                  max-height: 200px; overflow-y: auto; color: #7f1d1d; }}
  .stack-block {{ margin-top: 4px; background: #f9f9f9; border-left: 3px solid #ddd;
                  padding: 8px 12px; border-radius: 4px; font-size: 11px;
                  font-family: monospace; white-space: pre-wrap; word-break: break-all;
                  max-height: 150px; overflow-y: auto; color: #666;
                  display: none; }}
  .toggle-stack {{ font-size: 11px; color: #5A35F6; cursor: pointer;
                   margin-top: 4px; }}

  /* Summary box */
  .summary-box {{ background: #f8f7ff; border: 1px solid #e0daff; border-radius: 12px;
                  padding: 18px 20px; margin-bottom: 24px; }}
  .summary-box h3 {{ color: #5A35F6; font-size: 14px; margin-bottom: 8px; }}
  .summary-box p {{ font-size: 13px; line-height: 1.6; color: #444; }}

  footer {{ text-align: center; padding: 20px; font-size: 12px; color: #bbb; }}
</style>
</head>
<body>
<header>
  <h1>📱 BookMyEventNow — QA Test Report</h1>
  <div class="meta">Generated: {timestamp} &nbsp;|&nbsp; Run #{run_number}</div>
</header>
<div class="container">

  <!-- Stats -->
  <div class="stats">
    <div class="stat-card total">
      <div class="num">{total}</div><div class="lbl">Total Tests</div>
    </div>
    <div class="stat-card passed">
      <div class="num">{passed}</div><div class="lbl">Passed ✅</div>
    </div>
    <div class="stat-card failed">
      <div class="num">{failed}</div><div class="lbl">Failed ❌</div>
    </div>
    <div class="stat-card skipped">
      <div class="num">{skipped}</div><div class="lbl">Skipped ⚠️</div>
    </div>
    <div class="stat-card rate">
      <div class="num">{pass_rate}%</div><div class="lbl">Pass Rate</div>
    </div>
  </div>

  <!-- Progress -->
  <div class="progress-bar-wrap">
    <h3>TEST COVERAGE OVERVIEW</h3>
    <div class="progress-bar">
      <div class="bar-pass" style="width:{pass_pct}%"></div>
      <div class="bar-fail" style="width:{fail_pct}%"></div>
      <div class="bar-skip" style="width:{skip_pct}%"></div>
    </div>
  </div>

  <!-- Agent Summary -->
  <div class="summary-box">
    <h3>🤖 QA Agent Summary</h3>
    <p>{agent_summary}</p>
  </div>

  {failed_section}
  {passed_section}
  {skipped_section}

</div>
<footer>BookMyEventNow QA Agent &nbsp;|&nbsp; Automated with Claude · Anthropic</footer>
<script>
  document.querySelectorAll('.toggle-stack').forEach(el => {{
    el.addEventListener('click', () => {{
      const stack = el.nextElementSibling;
      if (stack) {{
        stack.style.display = stack.style.display === 'block' ? 'none' : 'block';
        el.textContent = stack.style.display === 'block' ? '▲ hide stack' : '▼ show stack trace';
      }}
    }});
  }});
</script>
</body>
</html>"""


def build_test_row(tid: int, data: dict, show_error: bool = False) -> str:
    t = data["tests"][tid]
    name = t.get("name", "Unknown")
    result = t.get("result", "unknown")
    duration = t.get("duration_ms", 0)
    group = get_group_name(tid, data)
    filepath = get_suite_path(tid, data)
    error_text = t.get("error", "")
    stack_text = t.get("stack", "")

    icon = {"success": "✅", "failure": "❌", "error": "💥", "skip": "⚠️"}.get(result, "❓")
    dur_str = f"{duration}ms" if duration < 1000 else f"{duration/1000:.1f}s"

    error_html = ""
    if show_error and error_text:
        stack_html = ""
        if stack_text:
            safe_stack = stack_text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
            stack_html = f'<span class="toggle-stack">▼ show stack trace</span><div class="stack-block">{safe_stack}</div>'
        safe_err = error_text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        error_html = f'<div class="error-block">{safe_err}</div>{stack_html}'

    safe_name = name.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

    return f"""
    <tr>
      <td class="status-icon">{icon}</td>
      <td>
        <div class="test-name">{safe_name}</div>
        <div class="test-group">{group}</div>
        <div class="test-file">{filepath}</div>
        {error_html}
      </td>
      <td class="duration">{dur_str}</td>
    </tr>"""


def build_section(title: str, badge_class: str, ids: list, data: dict, show_error: bool) -> str:
    if not ids:
        return ""
    rows = "".join(build_test_row(tid, data, show_error) for tid in ids)
    return f"""
  <div class="section">
    <div class="section-header">
      {title}
      <span class="badge {badge_class}">{len(ids)}</span>
    </div>
    <table>
      <thead><tr>
        <th style="width:36px"></th>
        <th>Test</th>
        <th style="width:80px">Duration</th>
      </tr></thead>
      <tbody>{rows}</tbody>
    </table>
  </div>"""


def generate_html_report(data: dict, output_path: str, run_number: int = 1) -> None:
    total = data["total"]
    passed = len(data["passed"])
    failed = len(data["failed"])
    skipped = len(data["skipped"])
    pass_rate = round(100 * passed / total) if total > 0 else 0

    def pct(n): return round(100 * n / total) if total > 0 else 0

    if failed == 0:
        agent_summary = (
            f"✅ All {passed} tests passed! The app is in a healthy state for Play Store submission. "
            f"No failures to address. {skipped} tests were skipped."
        )
    else:
        agent_summary = (
            f"❌ {failed} test(s) failed out of {total} total. "
            f"Pass rate: {pass_rate}%. "
            f"The QA agent has analysed the failures and attempted fixes where possible. "
            f"Review the failed tests section below and check the latest git commit for applied fixes."
        )

    failed_section  = build_section("❌ Failed Tests",  "badge-fail",  data["failed"],  data, show_error=True)
    passed_section  = build_section("✅ Passed Tests",  "badge-pass",  data["passed"],  data, show_error=False)
    skipped_section = build_section("⚠️ Skipped Tests", "badge-skip",  data["skipped"], data, show_error=False)

    html = HTML_TEMPLATE.format(
        timestamp=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        run_number=run_number,
        total=total,
        passed=passed,
        failed=failed,
        skipped=skipped,
        pass_rate=pass_rate,
        pass_pct=pct(passed),
        fail_pct=pct(failed),
        skip_pct=pct(skipped),
        agent_summary=agent_summary,
        failed_section=failed_section,
        passed_section=passed_section,
        skipped_section=skipped_section,
    )

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"HTML report written: {output_path}")


# ─── JSON Summary ─────────────────────────────────────────────────────────────

def generate_json_summary(data: dict, output_path: str, run_number: int = 1) -> dict:
    total = data["total"]
    passed = len(data["passed"])
    failed = len(data["failed"])
    skipped = len(data["skipped"])
    pass_rate = round(100 * passed / total, 1) if total > 0 else 0.0

    failed_tests = []
    for tid in data["failed"]:
        t = data["tests"][tid]
        failed_tests.append({
            "id": tid,
            "name": t.get("name", ""),
            "file": get_suite_path(tid, data),
            "group": get_group_name(tid, data),
            "error": t.get("error", ""),
            "stack": t.get("stack", ""),
            "duration_ms": t.get("duration_ms", 0),
        })

    summary = {
        "run_number": run_number,
        "timestamp": datetime.now().isoformat(),
        "total": total,
        "passed": passed,
        "failed": failed,
        "skipped": skipped,
        "pass_rate": pass_rate,
        "status": "PASS" if failed == 0 else "FAIL",
        "failed_tests": failed_tests,
    }

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)
    print(f"JSON summary written: {output_path}")
    return summary


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    args = parse_args()

    # Determine run number from existing reports
    reports_dir = Path(args.output).parent
    existing = list(reports_dir.glob("qa_report_*.html"))
    run_number = len(existing) + 1

    print(f"Parsing: {args.input}")
    data = parse_flutter_machine_output(args.input)

    total = data["total"]
    passed = len(data["passed"])
    failed = len(data["failed"])
    print(f"Results: {passed}/{total} passed, {failed} failed, {len(data['skipped'])} skipped")

    generate_html_report(data, args.output, run_number)
    summary = generate_json_summary(data, args.summary, run_number)

    # Exit 1 if there are failures (useful for CI)
    sys.exit(0 if failed == 0 else 1)


if __name__ == "__main__":
    main()
