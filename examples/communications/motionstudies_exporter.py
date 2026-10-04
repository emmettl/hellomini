#!/usr/bin/env python3
"""Expose the existing Motion Studies observer as bounded Prometheus metrics.

Read-only upstream; serves loopback only. No secrets in arguments or output.
Feed states describe the last completed check; observer_state is the read-time assessment.
"""
import argparse
from datetime import datetime
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import math
import os
import re
import time
from urllib.error import HTTPError
from urllib.parse import urlsplit
from urllib.request import Request, build_opener, HTTPRedirectHandler

LIMIT = 2_000_000
STATES = {"healthy": 0, "waiting": 1, "degraded": 2, "paused": 3, "unknown": 4, "setup-required": 4}
ID = re.compile(r"^[a-zA-Z0-9._-]{1,100}$")


def timestamp(value):
    try:
        if not isinstance(value, str) or len(value) > 40:
            return None
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        return parsed.timestamp() if parsed.tzinfo is not None else None
    except (ValueError, OverflowError):
        return None


def current(stamp, now):
    return stamp is not None and math.isfinite(stamp) and -30 <= now - stamp <= 180


def render(status, now):
    if status.get("schemaVersion") != 1 or status.get("kind") != "feed-observer-status":
        raise ValueError("Unsupported observer response")
    state = status.get("state")
    if state not in ("healthy", "degraded", "unknown"):
        raise ValueError("Invalid observer state")
    assessed = timestamp(status.get("assessedAt"))
    check = status.get("lastCheck") or {}
    if not isinstance(check, dict):
        raise ValueError("Invalid check")
    completed = timestamp(check.get("completedAt"))
    report = check.get("report") or {}
    if not isinstance(report, dict):
        raise ValueError("Invalid report")
    producer = timestamp(report.get("producerGeneratedAt"))
    available = (current(assessed, now) and current(completed, now)
                 and current(producer, now) and not status.get("failedAt")
                 and not check.get("sourceError") and state != "unknown"
                 and report.get("telemetry", {}).get("state") == "current")
    lines = ["# HELP motionstudies_exporter_up Observer HTTP response decoded successfully.",
             "# TYPE motionstudies_exporter_up gauge", "motionstudies_exporter_up 1",
             "# HELP motionstudies_observer_state Current observer assessment: 0 healthy, 2 degraded, 4 unknown.",
             "# TYPE motionstudies_observer_state gauge",
             f"motionstudies_observer_state {STATES[state] if available else 4}"]
    for metric, value in [("observer_check", completed), ("producer", producer)]:
        lines += [f"# TYPE motionstudies_{metric}_timestamp_seconds gauge",
                  f"motionstudies_{metric}_timestamp_seconds {value or 0}"]
    lines += ["# HELP motionstudies_feed_state Last completed check: 0 healthy, 1 waiting, 2 degraded, 3 paused, 4 unknown. Unavailable evidence forces unknown.",
              "# TYPE motionstudies_feed_state gauge"]
    feeds = report.get("feeds", [])
    if not isinstance(feeds, list) or len(feeds) > 128:
        raise ValueError("Invalid feed list")
    seen = set()
    for feed in feeds:
        name = feed.get("feedId")
        if not isinstance(name, str) or not ID.fullmatch(name) or name in seen:
            raise ValueError("Invalid feed identity")
        seen.add(name)
        code = STATES.get(feed.get("state"), 4) if available else 4
        if available and feed.get("configuredState") == "paused":
            code = 3
        lines.append(f'motionstudies_feed_state{{feed="{name}"}} {code}')
    return "\n".join(lines) + "\n"


class NoRedirects(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def fetch(url):
    headers = {"Accept": "application/json",
               "User-Agent": "HelloMini-MotionStudiesReceiver/0.5.0"}
    for env, header in [("FEED_READ_TOKEN", "Authorization"),
                        ("CF_ACCESS_CLIENT_ID", "CF-Access-Client-Id"),
                        ("CF_ACCESS_CLIENT_SECRET", "CF-Access-Client-Secret")]:
        value = os.environ.get(env)
        if value:
            if "\n" in value or "\r" in value or len(value) > 4096:
                raise ValueError("Invalid credential")
            headers[header] = "Bearer " + value if header == "Authorization" else value
    request = Request(url, headers=headers)
    try:
        response = build_opener(NoRedirects()).open(request, timeout=10)
    except HTTPError as error:
        # The observer intentionally returns a valid unhealthy report with HTTP 503.
        if error.code != 503:
            raise
        response = error
    with response:
        data = response.read(LIMIT + 1)
    if len(data) > LIMIT:
        raise ValueError("Response too large")
    return json.loads(data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", required=True, help="HTTPS observer status URL (no credentials)")
    parser.add_argument("--port", type=int, default=9469)
    args = parser.parse_args()
    url = urlsplit(args.url)
    if (url.scheme != "https" or not url.hostname or url.username or url.password
            or url.query or url.fragment or not 1 <= args.port <= 65535):
        parser.error("Use an HTTPS status URL without credentials, query or fragment, and a valid port")

    class Handler(BaseHTTPRequestHandler):
        cached = None
        cached_at = 0.0
        def do_GET(self):
            if self.path != "/metrics":
                self.send_error(404)
                return
            try:
                # Never renew the evidence timestamp. Age cached content on every scrape.
                if time.monotonic() - Handler.cached_at >= 30 or Handler.cached is None:
                    Handler.cached = None
                    Handler.cached = fetch(args.url)
                    Handler.cached_at = time.monotonic()
                output = render(Handler.cached, time.time())
            except Exception:
                Handler.cached = None
                output = ("# TYPE motionstudies_exporter_up gauge\nmotionstudies_exporter_up 0\n"
                          "# TYPE motionstudies_observer_state gauge\nmotionstudies_observer_state 4\n")
            data = output.encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        def log_message(self, *args):
            pass  # Never log credential-bearing upstream exceptions or URLs.

    print(f"Read-only metrics exporter listening on 127.0.0.1:{args.port}", flush=True)
    HTTPServer(("127.0.0.1", args.port), Handler).serve_forever()


if __name__ == "__main__":
    main()
