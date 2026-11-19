"""Check a release artifact and the production source inventory without publishing."""
import argparse
import json
from pathlib import Path

from release_artifact import LOCAL_ROJO, ROOT, verify


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifact", type=Path, default=ROOT / "dist/Blackout Freight Progression Preview.rbxl")
    parser.add_argument("--rojo", default=LOCAL_ROJO)
    args = parser.parse_args()
    result = verify(args.artifact.read_bytes(), args.rojo)
    print(json.dumps({"artifact": str(args.artifact), **result}, indent=2))


if __name__ == "__main__":
    main()
