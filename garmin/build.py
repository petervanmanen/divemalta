#!/usr/bin/env python3
"""Build a transparent Garmin map (DiveSitesEurope.img) from europe-dive-sites.geojson with mkgmap.

Around Malta the OSM sites are replaced by the curated sites the apps use (shared/sites/*.json):
those have been checked, merged and researched, and include sites that aren't in OSM.

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
SITES = os.path.join(HERE, "..", "shared", "sites")
from gather_sites import BOUNDS as MALTA  # noqa: E402  (south, north, west, east)


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


def in_malta(lat, lon):
    south, north, west, east = MALTA
    return south <= lat <= north and west <= lon <= east


def osm_points(src):
    with open(src) as f:
        features = json.load(f)["features"]
    for feat in features:
        props = feat["properties"]
        lon, lat = feat["geometry"]["coordinates"]
        # Dive sites only; dive centres, shops and clubs are left out. Malta comes from shared/sites.
        if props["kind"] == "site" and not is_centre_like(props["tags"]) and not in_malta(lat, lon):
            yield lat, lon, name_for(props["tags"])


def curated_points():
    for path in sorted(glob.glob(os.path.join(SITES, "*.json"))):
        if os.path.basename(path).startswith("_"):
            continue
        with open(path) as f:
            site = json.load(f)
        details = [d for d in (site.get("maxDepth"), site.get("type"), site.get("entry")) if d]
        name = f"{site['name']} ({', '.join(details)})" if details else site["name"]
        yield site["lat"], site["lon"], name


def write_osm(dst, points):
    with open(dst, "w", encoding="utf-8") as out:
        out.write("<?xml version='1.0' encoding='UTF-8'?>\n<osm version='0.6' generator='dive-sites'>\n")
        for i, (lat, lon, name) in enumerate(points, 1):
            out.write(f"<node id='-{i}' version='1' lat='{lat}' lon='{lon}'>")
            out.write("<tag k='dive' v='site'/>")
            if name:
                out.write(f"<tag k='name' v={quoteattr(name)}/>")
            out.write("</node>\n")
        out.write("</osm>\n")


def main():
    os.chdir(HERE)
    build = os.path.join(HERE, "build")
    shutil.rmtree(build, ignore_errors=True)
    os.makedirs(build)
    osm, curated = list(osm_points("europe-dive-sites.geojson")), list(curated_points())
    write_osm(os.path.join(build, "dive-sites.osm"), osm + curated)
    print(f"Wrote {len(osm)} OSM and {len(curated)} curated Malta dive sites to build/dive-sites.osm",
          file=sys.stderr)

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
