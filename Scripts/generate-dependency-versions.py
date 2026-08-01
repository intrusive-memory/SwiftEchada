#!/usr/bin/env python3
"""Generate Sources/EchadaCLICore/Generated/DependencyVersions.swift.

`echada --version` reports which dependency versions are actually compiled into
the binary. Swift has no runtime access to Package.resolved, so the data has to
be baked in at build time — that is what this script does.

It pairs two sources:

  Package.swift    the *declared* requirement for each direct dependency
                   (e.g. `.upToNextMajor(from: "4.6.1")` -> `4.6.1 ..< 5.0.0`)
  Package.resolved the *resolved* version SwiftPM actually picked, which is what
                   ends up linked into the binary

Both matter. `Package.resolved` is gitignored in this repo, so without the
generated file there is no committed record of what a given release was built
against — a gap that made triaging issues #44/#55 unnecessarily hard, since the
only way to tell which SwiftProyecto a shipped binary contained was to run it
against a fixture and infer from behaviour.

Run via `make resolve` (which every build target depends on). The generated file
is committed so builds that bypass the Makefile still compile.
"""

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACKAGE_SWIFT = os.path.join(ROOT, "Package.swift")
PACKAGE_RESOLVED = os.path.join(ROOT, "Package.resolved")
OUTPUT = os.path.join(
    ROOT, "Sources", "EchadaCLICore", "Generated", "DependencyVersions.swift"
)


def next_major(version):
    parts = version.split(".")
    major = int(parts[0])
    # SwiftPM treats 0.x as its own major line only for upToNextMinor; for
    # upToNextMajor, 0.14.1 still ranges up to 1.0.0.
    return f"{major + 1}.0.0"


def next_minor(version):
    parts = (version.split(".") + ["0", "0"])[:3]
    return f"{parts[0]}.{int(parts[1]) + 1}.0"


def parse_declared(text):
    """Extract (repo_name, requirement_description) for each direct dependency.

    Only `.package(url:...)` declarations are matched. Local checkouts declared
    as `.package(name:path:)` — the `sibling()` development pattern this repo
    can be flipped into — have no version to report and are deliberately
    skipped; they also never appear in Package.resolved. If the manifest is ever
    switched to that pattern wholesale, the table would silently empty out, so
    `main()` warns when nothing matched.
    """
    declared = []
    # Collapse the manifest so multi-line `.package(...)` calls match as one unit,
    # and strip comments so commented-out URLs are never picked up.
    # `(?<!:)` keeps the `//` in `https://` from being mistaken for a comment.
    stripped = re.sub(r"(?<!:)//[^\n]*", "", text)
    flat = re.sub(r"\s+", " ", stripped)

    for match in re.finditer(r'\.package\(\s*url:\s*"([^"]+)"\s*,\s*([^)]*\))', flat):
        url, requirement = match.group(1), match.group(2)
        name = url.rstrip("/").rsplit("/", 1)[-1]
        if name.endswith(".git"):
            name = name[:-4]

        req = requirement.strip()
        described = None

        m = re.match(r'\.upToNextMajor\(\s*from:\s*"([^"]+)"', req)
        if m:
            described = f"{m.group(1)} ..< {next_major(m.group(1))}"

        if described is None:
            m = re.match(r'\.upToNextMinor\(\s*from:\s*"([^"]+)"', req)
            if m:
                described = f"{m.group(1)} ..< {next_minor(m.group(1))}"

        if described is None:
            m = re.match(r'\.exact\(\s*"([^"]+)"', req)
            if m:
                described = f"exactly {m.group(1)}"

        if described is None:
            m = re.match(r'branch:\s*"([^"]+)"', req)
            if m:
                described = f"branch {m.group(1)}"

        if described is None:
            m = re.match(r'revision:\s*"([^"]+)"', req)
            if m:
                described = f"revision {m.group(1)[:12]}"

        if described is None:
            m = re.match(r'from:\s*"([^"]+)"', req)
            if m:
                described = f"{m.group(1)} ..< {next_major(m.group(1))}"

        declared.append((name, described or req.rstrip(")").strip()))

    return declared


def parse_resolved(path):
    """Map lowercased package identity -> resolved version (or short revision)."""
    if not os.path.exists(path):
        return None
    with open(path) as handle:
        data = json.load(handle)
    resolved = {}
    for pin in data.get("pins", []):
        state = pin.get("state", {})
        version = state.get("version")
        if not version:
            revision = state.get("revision", "")
            version = revision[:12] if revision else "unknown"
        resolved[pin["identity"].lower()] = version
    return resolved


def swift_string(value):
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    with open(PACKAGE_SWIFT) as handle:
        declared = parse_declared(handle.read())

    if not declared:
        print(
            "error: no direct dependencies matched in Package.swift. Either the "
            "manifest uses only local `.package(name:path:)` declarations, or the "
            "regex has regressed. Refusing to overwrite the generated file with an "
            "empty table.",
            file=sys.stderr,
        )
        return 1

    resolved = parse_resolved(PACKAGE_RESOLVED)
    if resolved is None:
        print(
            f"warning: {PACKAGE_RESOLVED} not found — run `make resolve` first; "
            "leaving the existing generated file untouched.",
            file=sys.stderr,
        )
        return 0

    direct_identities = set()
    direct_rows = []
    for name, requirement in declared:
        identity = name.lower()
        direct_identities.add(identity)
        direct_rows.append((name, requirement, resolved.get(identity, "unresolved")))

    transitive_rows = sorted(
        (identity, version)
        for identity, version in resolved.items()
        if identity not in direct_identities
    )

    lines = [
        "// Generated by Scripts/generate-dependency-versions.py — DO NOT EDIT.",
        "//",
        "// Regenerate with `make resolve` (every build target depends on it).",
        "// Committed deliberately: Package.resolved is gitignored, so this file is",
        "// the only record in version control of what a given build links against.",
        "",
        "/// The dependency versions compiled into this binary.",
        "enum DependencyVersions {",
        "",
        "  /// A direct dependency: what Package.swift asks for, and what SwiftPM picked.",
        "  struct Direct: Sendable {",
        "    let name: String",
        "    /// The requirement declared in Package.swift, e.g. `4.6.1 ..< 5.0.0`.",
        "    let requirement: String",
        "    /// The version actually resolved and linked into this binary.",
        "    let resolved: String",
        "  }",
        "",
        "  /// Declared in Package.swift, in manifest order.",
        "  static let direct: [Direct] = [",
    ]

    for name, requirement, version in direct_rows:
        lines.append(
            f"    Direct(name: {swift_string(name)}, "
            f"requirement: {swift_string(requirement)}, "
            f"resolved: {swift_string(version)}),"
        )

    lines += [
        "  ]",
        "",
        "  /// Pulled in transitively, sorted by package identity.",
        "  static let transitive: [(name: String, resolved: String)] = [",
    ]

    for identity, version in transitive_rows:
        lines.append(
            f"    (name: {swift_string(identity)}, resolved: {swift_string(version)}),"
        )

    lines += [
        "  ]",
        "",
        "  /// Renders the dependency table appended to `echada --version`.",
        "  static func report() -> String {",
        "    var out = \"\"",
        "",
        "    let nameWidth = direct.map(\\.name.count).max() ?? 0",
        "    let reqWidth = direct.map(\\.requirement.count).max() ?? 0",
        "",
        "    out += \"\\nDirect dependencies (Package.swift):\\n\"",
        "    out += \"  \" + \"PACKAGE\".padded(to: nameWidth)",
        "    out += \"  \" + \"DECLARED\".padded(to: reqWidth)",
        "    out += \"  COMPILED\\n\"",
        "    for dependency in direct {",
        "      out += \"  \" + dependency.name.padded(to: nameWidth)",
        "      out += \"  \" + dependency.requirement.padded(to: reqWidth)",
        "      out += \"  \" + dependency.resolved + \"\\n\"",
        "    }",
        "",
        "    if !transitive.isEmpty {",
        "      let width = transitive.map(\\.name.count).max() ?? 0",
        "      out += \"\\nTransitive dependencies:\\n\"",
        "      for dependency in transitive {",
        "        out += \"  \" + dependency.name.padded(to: width)",
        "        out += \"  \" + dependency.resolved + \"\\n\"",
        "      }",
        "    }",
        "",
        "    return out",
        "  }",
        "}",
        "",
        "extension String {",
        "  /// Right-pads to `width` so the version table lines up.",
        "  fileprivate func padded(to width: Int) -> String {",
        "    count >= width ? self : self + String(repeating: \" \", count: width - count)",
        "  }",
        "}",
        "",
    ]

    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    content = "\n".join(lines)

    # Avoid rewriting an identical file so incremental builds don't churn.
    if os.path.exists(OUTPUT):
        with open(OUTPUT) as handle:
            if handle.read() == content:
                return 0

    with open(OUTPUT, "w") as handle:
        handle.write(content)

    print(
        f"Generated {os.path.relpath(OUTPUT, ROOT)} "
        f"({len(direct_rows)} direct, {len(transitive_rows)} transitive)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
