"""Publish the checked release artifact to the existing Blackout Freight place."""
import argparse
import getpass
import hashlib
import json
import sys
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import HTTPRedirectHandler, Request, build_opener


PLACE = Path(__file__).resolve().parents[1] / "dist" / "Blackout Freight Closed Test.rbxl"
URL = (
    "https://apis.roblox.com/universes/v1/10775560304/"
    "places/111633787401180/versions?versionType=Published"
)


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--publish", action="store_true", help="Upload after prompting for a scoped key")
    args = parser.parse_args()
    payload = PLACE.read_bytes()
    if not payload.startswith(b"<roblox!\x89\xff\r\n\x1a\n") or len(payload) > 100 * 1024**2:
        parser.error("Expected a Roblox binary place of at most 100 MB")
    print(f"{PLACE.name} · {len(payload)} bytes · SHA-256 {hashlib.sha256(payload).hexdigest()}")
    print("Target: Blackout Freight · universe 10775560304 · start place 111633787401180")
    if not args.publish:
        return 0
    if not sys.stdin.isatty():
        parser.error("Run --publish in a terminal so the API key can be entered privately")
    key = getpass.getpass("Scoped Roblox Open Cloud API key: ").strip()
    if not key:
        parser.error("No API key entered")
    request = Request(URL, data=payload, headers={
        "Content-Type": "application/octet-stream", "x-api-key": key,
    }, method="POST")
    try:
        with build_opener(NoRedirect()).open(request, timeout=45) as response:
            version = json.load(response).get("versionNumber")
    except HTTPError as error:
        print(f"Roblox returned HTTP {error.code}. Check Version History before retrying.", file=sys.stderr)
        return 1
    except (URLError, TimeoutError, ValueError, AttributeError):
        print("Publication not confirmed. Check Version History before retrying.", file=sys.stderr)
        return 1
    if not isinstance(version, int):
        print("No version number returned. Check Version History before retrying.", file=sys.stderr)
        return 1
    print(f"Published version {version}. Verify it in Creator Hub → Version History.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
