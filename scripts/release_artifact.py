"""Validate the exact bytes a developer or publisher is about to distribute."""
import hashlib
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCAL_ROJO = str(ROOT / ".tools/rojo/rojo")


def verify(payload, rojo):
    if not payload.startswith(b"<roblox!\x89\xff\r\n\x1a\n"):
        raise ValueError("Expected a binary Roblox place")
    with tempfile.TemporaryDirectory(prefix="freight-release-") as directory:
        binary = Path(directory) / "candidate.rbxl"
        xml = binary.with_suffix(".rbxlx")
        for output in (binary, xml):
            subprocess.run([rojo, "build", "-o", str(output)], cwd=ROOT, check=True,
                           stdout=subprocess.DEVNULL)
        if binary.read_bytes() != payload:
            raise ValueError("Artifact differs from the current production project")
        scripts = [item for item in ET.parse(xml).iter("Item")
                   if item.get("class") in ("Script", "LocalScript", "ModuleScript")]
        if not scripts:
            raise ValueError("Empty source inventory")
        for item in scripts:
            source = item.findtext('./Properties/*[@name="Source"]') or ""
            for marker in ("FreightTestAction", "EndTest(", "QA PASS"):
                if marker in source:
                    raise ValueError(f"Test hook in release: {marker}")
    return {"sha256": hashlib.sha256(payload).hexdigest(), "scripts": len(scripts),
            "matchesProductionProject": True}
