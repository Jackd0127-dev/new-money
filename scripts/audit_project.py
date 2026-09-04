#!/usr/bin/env python3
"""Check explicit Xcode source membership without resolving packages or reading app data."""

from collections import Counter
import json
from pathlib import Path
import subprocess
import sys
import xml.etree.ElementTree as ET


def main() -> int:
    repository = Path(__file__).resolve().parents[1]
    project_root = repository / "NewMoneyIPhone"
    project = project_root / "NewMoneyIPhone.xcodeproj"
    parsed = subprocess.check_output(
        ["plutil", "-convert", "json", "-o", "-", str(project / "project.pbxproj")],
        text=True,
    )
    document = json.loads(parsed)
    objects = document["objects"]
    paths: dict[str, Path] = {}
    errors: list[str] = []

    def visit(identifier: str, parent: Path) -> None:
        entry = objects[identifier]
        source_tree = entry.get("sourceTree", "<group>")
        if source_tree == "BUILT_PRODUCTS_DIR":
            return
        base = project_root if source_tree == "SOURCE_ROOT" else parent
        path = base / entry.get("path", "")
        if entry["isa"] == "PBXGroup":
            for child in entry.get("children", []):
                visit(child, path)
        elif entry["isa"] == "PBXFileReference":
            paths[identifier] = path.resolve()
            if not path.exists():
                errors.append(f"Missing project reference: {path.relative_to(repository)}")

    visit(objects[document["rootObject"]]["mainGroup"], project_root)
    expected_roots = {
        "NewMoneyIPhone": project_root / "NewMoney",
        "NewMoneyIPhoneTests": project_root / "NewMoneyTests",
    }
    for target in (entry for entry in objects.values() if entry["isa"] == "PBXNativeTarget"):
        name = target["name"]
        if name not in expected_roots:
            continue
        sources: list[Path] = []
        for phase_id in target["buildPhases"]:
            phase = objects[phase_id]
            if phase["isa"] != "PBXSourcesBuildPhase":
                continue
            for build_file_id in phase["files"]:
                file_id = objects[build_file_id]["fileRef"]
                if file_id in paths:
                    sources.append(paths[file_id])
                else:
                    errors.append(f"Unresolved source reference in {name}: {file_id}")
        for path, count in Counter(sources).items():
            if count > 1:
                errors.append(f"Duplicate source in {name}: {path.relative_to(repository)}")
        expected = {path.resolve() for path in expected_roots[name].rglob("*.swift")}
        for path in sorted(expected - set(sources)):
            errors.append(f"Missing {name} source membership: {path.relative_to(repository)}")
        for path in sorted(set(sources) - expected):
            errors.append(f"Unexpected {name} source membership: {path}")
        print(f"{name}: {len(sources)} source members, {len(expected)} Swift files")

    for scheme in sorted((project / "xcshareddata" / "xcschemes").glob("*.xcscheme")):
        ET.parse(scheme)
    json.loads((project / "project.xcworkspace/xcshareddata/swiftpm/Package.resolved").read_text())
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print("Project references, source membership, shared schemes, and package lockfile are valid.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
