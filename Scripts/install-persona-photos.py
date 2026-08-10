#!/usr/bin/env python3
"""Install swipe-deck portrait photos into the app's asset catalog.

Each photo becomes a `Persona<Name>.imageset` that `DemoRoster` picks up by
name — the deck resolves art through `DemoRoster.asset(_:)`, so a name with no
imageset simply falls back to a monogram tile rather than rendering blank.

Usage:

    python3 Scripts/install-persona-photos.py \
        --elon ~/Desktop/elon.jpg \
        --sam ~/Desktop/sam.jpg \
        --donald ~/Desktop/trump.jpg \
        --julian ~/Desktop/julian.jpg \
        --evan ~/Desktop/evan.jpg \
        --eric ~/Desktop/eric.jpg

Every flag is optional; only what you pass gets installed. Images are
normalised to JPEG and capped on the long edge, since the originals are far
larger than a phone-sized card needs and go straight into the app bundle.

Note on the public figures: these are press photographs owned by whoever shot
them, used here as parody in a local demo. Sort out rights before shipping this
anywhere public.
"""
import argparse
import json
import pathlib
import shutil
import subprocess
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
CATALOG = REPO / "App/Resources/WingmanApp/Assets.xcassets"
MAX_EDGE = 1400

PEOPLE = ["elon", "sam", "donald", "julian", "evan", "eric"]


def install(person: str, source: pathlib.Path) -> None:
    if not source.exists():
        sys.exit(f"no such file: {source}")

    name = f"Persona{person.capitalize()}"
    folder = CATALOG / f"{name}.imageset"
    if folder.exists():
        shutil.rmtree(folder)
    folder.mkdir(parents=True)

    destination = folder / f"{name}.jpg"
    # sips both converts (HEIC/PNG/WebP in, JPEG out) and resizes in one pass.
    subprocess.run(
        ["sips", "-s", "format", "jpeg", "-Z", str(MAX_EDGE),
         str(source), "--out", str(destination)],
        check=True, capture_output=True,
    )

    (folder / "Contents.json").write_text(
        json.dumps(
            {
                "images": [{"filename": destination.name, "idiom": "universal"}],
                "info": {"author": "xcode", "version": 1},
            },
            indent=2,
        )
        + "\n"
    )

    size = destination.stat().st_size // 1024
    print(f"  {name:<16} {size} KB")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    for person in PEOPLE:
        parser.add_argument(f"--{person}", type=pathlib.Path)
    args = parser.parse_args()

    chosen = [(p, getattr(args, p)) for p in PEOPLE if getattr(args, p)]
    if not chosen:
        parser.error("pass at least one photo, e.g. --julian path/to/julian.jpg")

    print(f"installing into {CATALOG.relative_to(REPO)}")
    for person, source in chosen:
        install(person, source.expanduser())

    print("\nRun `xcodegen generate` is not needed — asset catalogs are")
    print("folder-referenced. Just rebuild.")


if __name__ == "__main__":
    main()
