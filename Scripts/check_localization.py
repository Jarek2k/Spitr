#!/usr/bin/env python3
"""
Fails if any user-facing code string is missing from the String Catalogs.

Complements the LocalizationCatalogTests unit test: that test guarantees every
*catalog* entry is translated into every language; this script guarantees every
*code* string actually made it into the catalog in the first place (a string the
compiler extracted but nobody added to Localizable.xcstrings would silently fall
back to German in all other languages).

Run AFTER a build (it reads the compiler's .stringsdata):
    xcodebuild -scheme Spitr build && python3 Scripts/check_localization.py

Exit code 1 on any gap, so it can gate CI.
"""

import json
import glob
import os
import re
import sys
import subprocess

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Keys that need no translation: pure numbers / bare format specifiers.
TRIVIAL = re.compile(r"^(%([0-9$]*)(@|lld|ld|d|f|lf)|\s)*$")


def derived_data_objroot():
    """Locate the build's intermediates dir (where .stringsdata live)."""
    pattern = os.path.expanduser(
        "~/Library/Developer/Xcode/DerivedData/Spitr-*/Build/Intermediates.noindex/Spitr.build"
    )
    matches = glob.glob(pattern)
    if not matches:
        sys.exit("No build intermediates found — run `xcodebuild -scheme Spitr build` first.")
    return max(matches, key=os.path.getmtime)


def extracted_keys():
    """Map table name ('Localizable' | 'InfoPlist') -> set of keys from our code."""
    objroot = derived_data_objroot()
    tables = {}
    for path in glob.glob(os.path.join(objroot, "**", "*.stringsdata"), recursive=True):
        if os.path.basename(path).startswith("ExtractedAppShortcuts"):
            continue
        try:
            data = json.load(open(path))
        except Exception:
            continue
        for table, entries in data.get("tables", {}).items():
            for entry in entries:
                tables.setdefault(table, set()).add(entry["key"])
    return tables


def catalog_keys(name):
    path = os.path.join(REPO, "Spitr", name)
    return set(json.load(open(path)).get("strings", {}).keys())


def main():
    extracted = extracted_keys()
    problems = []

    checks = [
        ("Localizable", "Localizable.xcstrings"),
        ("InfoPlist", "InfoPlist.xcstrings"),
    ]
    for table, catalog in checks:
        in_code = {k for k in extracted.get(table, set()) if not TRIVIAL.match(k)}
        in_catalog = catalog_keys(catalog)
        missing = sorted(in_code - in_catalog)
        for key in missing:
            problems.append(f"  [{catalog}] im Code, aber nicht im Catalog: {key!r}")

    if problems:
        print("FEHLENDE Katalog-Einträge:\n" + "\n".join(problems))
        print(f"\n{len(problems)} Lücke(n) — füge sie in Scripts/gen_localization.py hinzu und führe es aus.")
        sys.exit(1)

    print("OK — jeder benutzersichtbare Code-String ist im Catalog.")


if __name__ == "__main__":
    main()
