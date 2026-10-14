"""Rules for reading OSM dive-site tags (shared in spirit with the Garmin map builder)."""
import re

DEPTH_KEYS = ["scuba_diving:maxdepth", "maxdepth", "wreck:depth", "scuba_diving:depth", "depth"]
TYPE_WORDS = {"wall", "wreck", "cave", "reef", "rocks", "quarry", "lake", "drift", "training", "attraction", "boat"}
ENTRY_WORDS = {"shore": "shore", "boat": "boat", "stair": "shore", "steps": "shore", "pier": "shore",
               "ladder": "shore", "beach": "shore"}


# Clubs, schools and shops that OSM tags as dive sites rather than dive centres.
CENTRE_NAME = re.compile(
    r"(div(e|ing)|scuba|tauch|duik|plong|buceo|immersion|sub)\w*[\s-]*"
    r"(cent(er|re|ro)|club|school|shop|base|centrum|zentrum|schule|basis|winkel|verein|klub|vereniging)"
    r"|tauchschule|tauchbasis|tauchsport|duikschool|duikcentrum|tauchcenter|tauchclub", re.I)


def is_centre_like(tags):
    return (any(k in tags for k in ("club", "shop", "office", "craft"))
            or tags.get("leisure") in ("sports_centre", "swimming_pool", "fitness_centre")
            or bool(CENTRE_NAME.search(tags.get("name", ""))))


def depth_of(tags):
    """'30', '30m', '30 m', '5-30' -> '30m' / '5-30m'; anything else is dropped."""
    for key in DEPTH_KEYS:
        v = tags.get(key, "").strip().lower().replace(" ", "").replace(",", ".")
        v = v[:-1] if v.endswith("m") else v
        if v and all(part.replace(".", "", 1).isdigit() for part in v.split("-")):
            return v + "m"
    return None


def site_type(tags):
    for t in tags.get("scuba_diving:type", "").split(";"):
        if t.strip() in TYPE_WORDS:
            return t.strip()
    if tags.get("historic") == "wreck" or tags.get("seamark:type") == "wreck":
        return "wreck"
    return {"reef": "reef", "cave_entrance": "cave"}.get(tags.get("natural"))


def entry_of(tags):
    for e in tags.get("scuba_diving:entry", "").split(";"):
        if e.strip() in ENTRY_WORDS:
            return ENTRY_WORDS[e.strip()]
    for e in ("boat", "shore"):
        if tags.get(f"scuba_diving:entry:{e}") == "yes":
            return e
    return None
