"""Find or remove Blackout Freight weekly leaderboard rows by participant UserId."""
import argparse
import getpass
import json
import re
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import HTTPRedirectHandler, Request, build_opener

BASE = "https://apis.roblox.com/cloud/v2/universes/10775560304/ordered-data-stores/FreightDailyWeekly_v1/scopes"
ROSTER = re.compile(r"[1-9][0-9]*(?:_[1-9][0-9]*){0,3}")


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def entries(request, scope, user_id):
    url = f"{BASE}/{scope}/entries"
    token = ""
    while True:
        query = {"maxPageSize": 100}
        if token:
            query["pageToken"] = token
        page = request("GET", f"{url}?{urlencode(query)}")
        for row in page.get("orderedDataStoreEntries", []):
            roster = row["id"]
            if ROSTER.fullmatch(roster) and str(user_id) in roster.split("_"):
                yield roster, row["value"]
        token = page.get("nextPageToken")
        if not token:
            return


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("user_id", type=int)
    parser.add_argument("--week", type=int, default=(int(time.time()) + 3 * 86400) // 604800)
    parser.add_argument("--delete-roster", help="Delete one exact roster shown by the read-only scan")
    args = parser.parse_args()
    if args.user_id <= 0 or args.week < 0:
        parser.error("Expected a positive UserId and a nonnegative week index")
    if args.delete_roster and not ROSTER.fullmatch(args.delete_roster):
        parser.error("Expected an exact underscore-separated roster from the scan")
    if not sys.stdin.isatty():
        parser.error("Use a terminal so the scoped Open Cloud key can be entered privately")
    key = getpass.getpass("Scoped Roblox Open Cloud API key: ").strip()
    if not key:
        parser.error("No API key entered")
    opener = build_opener(NoRedirect())

    def request(method, url):
        req = Request(url, method=method, headers={"x-api-key": key})
        with opener.open(req, timeout=20) as response:
            body = response.read()
            return json.loads(body) if body else None

    try:
        matches = []
        for size in range(1, 5):
            scope = f"w{args.week}_c{size}"
            matches.extend((scope, roster, seconds) for roster, seconds in entries(request, scope, args.user_id))
        for scope, roster, seconds in matches:
            print(f"{scope}  {roster}  {seconds}s")
        if not matches:
            print("No matching leaderboard entries.")
        if args.delete_roster:
            for scope, roster, _ in matches:
                if roster == args.delete_roster:
                    request("DELETE", f"{BASE}/{scope}/entries/{roster}")
                    if any(found == roster for found, _ in entries(request, scope, args.user_id)):
                        print("Entry is still present. Check for a concurrent submission.", file=sys.stderr)
                        return 1
                    print(f"Removed {scope}/{roster}")
                    return 0
            parser.error("The requested roster was not found for this UserId and week")
    except HTTPError as error:
        print(f"Roblox returned HTTP {error.code}. Check the entry before retrying.", file=sys.stderr)
        return 1
    except (URLError, TimeoutError, ValueError, KeyError, TypeError):
        print("Roblox did not confirm the operation. Check the entry before retrying.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
