#!/usr/bin/env python3
"""Build a transparent Garmin map (DiveSitesEurope.img) from europe-dive-sites.geojson with mkgmap.

Copy the .img into the GARMIN folder of the watch (see README). It lies on top of the watch's own
map, so the dive sites show up there and can be found under Find > Points of Interest.
"""
import glob
import json
import os
import shutil
import subprocess
import sys
from xml.sax.saxutils import quoteattr

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "shared", "tools"))
from osm_rules import depth_of, entry_of, is_centre_like, site_type  # noqa: E402  (shared with the apps)
JAVA = shutil.which("java", path="/opt/homebrew/opt/openjdk/bin") or "java"
OUT = "DiveSitesEurope.img"


def find_mkgmap():
    jars = sorted(glob.glob(os.path.join(HERE, "tools", "mkgmap-r*", "mkgmap.jar")))
    if not jars:
        sys.exit("mkgmap not found: unpack mkgmap from https://www.mkgmap.org.uk into garmin/tools/")
    return jars[-1]


def name_for(tags):
    name = tags.get("name") or tags.get("name:en") or tags.get("scuba_diving:name") or ""
    # A Garmin watch only reliably shows the name, so put depth, site type and entry in it:
    # "Zeelandbrug (30m, wreck, shore)".
    details = [d for d in (depth_of(tags), site_type(tags), entry_of(tags)) if d]
    if details:
        name = f"{name or 'Dive site'} ({', '.join(details)})"
    return name


def write_osm(src, dst):
    with open(src) as f:
        # Dive sites only; dive centres, shops and clubs are left out.
        features = [x for x in json.load(f)["features"]
                    if x["properties"]["kind"] == "site" and not is_centre_like(x["properties"]["tags"])]
    with open(dst, "w", encoding="utf-8") as out:
        out.write("<?xml version='1.0' encoding='UTF-8'?>\n<osm version='0.6' generator='dive-sites'>\n")
        for i, feat in enumerate(features, 1):
            lon, lat = feat["geometry"]["coordinates"]
            out.write(f"<node id='-{i}' version='1' lat='{lat}' lon='{lon}'>")
            out.write("<tag k='dive' v='site'/>")
            name = name_for(feat["properties"]["tags"])
            if name:
                out.write(f"<tag k='name' v={quoteattr(name)}/>")
            out.write("</node>\n")
        out.write("</osm>\n")
    return len(features)


def main():
    os.chdir(HERE)
    build = os.path.join(HERE, "build")
    shutil.rmtree(build, ignore_errors=True)
    os.makedirs(build)
    n = write_osm("europe-dive-sites.geojson", os.path.join(build, "dive-sites.osm"))
    print(f"Wrote {n} dive sites to build/dive-sites.osm", file=sys.stderr)

    subprocess.run([
        JAVA, "-jar", find_mkgmap(),
        f"--output-dir={build}",
        f"--style-file={os.path.join(HERE, 'style')}",
        "--family-id=5870", "--product-id=1", "--mapname=58700001",
        "--family-name=OSM Dive Sites Europe", "--series-name=OSM Dive Sites Europe",
        "--description=OSM Dive Sites Europe",
        "--copyright-message=Map data (c) OpenStreetMap contributors, ODbL",
        "--transparent", "--draw-priority=31",
        "--code-page=1252", "--lower-case", "--index", "--gmapsupp",
        os.path.join(build, "dive-sites.osm"),
    ], check=True)
    shutil.move(os.path.join(build, "gmapsupp.img"), os.path.join(HERE, OUT))
    print(f"Built {OUT} ({os.path.getsize(OUT) // 1024} KB)", file=sys.stderr)


if __name__ == "__main__":
    main()
