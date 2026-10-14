// Writes the offline map style for the app: the Protomaps "light" basemap reading the bundled
// malta.pmtiles, with fonts and sprites from the app bundle, plus the depth contours and dive sites
// written by ../make_data.py. "{ASSETS}" is replaced at runtime by the URL of the bundled data folder
// (shared/data, copied into each app). Run: node make_style.mjs ../../data/style.json
import { writeFileSync } from "node:fs";
import { layers, namedFlavor } from "@protomaps/basemaps";

// Contour colour from light cyan in the shallows to dark navy at depth.
const contourColor = ["interpolate", ["linear"], ["get", "depth"],
  5, "#5cc8dc", 20, "#2a8fd0", 50, "#1f5aa8", 100, "#1c3a82", 200, "#14255a"];
const medium = ["Noto Sans Medium"];

const contourLayers = [
  {
    id: "contours", type: "line", source: "contours",
    layout: { "line-join": "round" },
    paint: {
      "line-color": contourColor,
      "line-width": ["case", ["in", ["get", "depth"], ["literal", [10, 20, 30, 40, 50, 100, 200]]], 1.5, 0.8],
      "line-opacity": 0.9,
    },
  },
  {
    id: "contour-labels", type: "symbol", source: "contours", minzoom: 11,
    layout: {
      "symbol-placement": "line", "symbol-spacing": 300,
      "text-field": ["to-string", ["get", "depth"]], "text-font": medium, "text-size": 10,
    },
    paint: { "text-color": contourColor, "text-halo-color": "#ffffff", "text-halo-width": 1.5 },
  },
];

// Our own extra map lines (../../enrichment/map.geojson), e.g. underwater tunnels the basemap leaves out.
const extraLayers = [
  {
    id: "extra-tunnels", type: "line", source: "extras", filter: ["==", ["get", "kind"], "tunnel"],
    layout: { "line-cap": "round" },
    paint: {
      "line-color": "#1f6fd1",
      "line-width": ["interpolate", ["linear"], ["zoom"], 13, 2, 17, 5],
      "line-dasharray": [1.5, 1],
    },
  },
  {
    id: "extra-tunnel-labels", type: "symbol", source: "extras", filter: ["==", ["get", "kind"], "tunnel"],
    minzoom: 15,
    layout: {
      "symbol-placement": "line", "text-field": ["get", "name"], "text-font": medium, "text-size": 11,
    },
    paint: { "text-color": "#1f6fd1", "text-halo-color": "#ffffff", "text-halo-width": 1.5 },
  },
];

const siteLayers = [
  {
    id: "site-clusters", type: "circle", source: "sites", filter: ["has", "point_count"],
    paint: {
      "circle-color": "#0a84ff", "circle-radius": ["step", ["get", "point_count"], 15, 10, 19],
      "circle-stroke-color": "#ffffff", "circle-stroke-width": 2,
    },
  },
  {
    id: "site-cluster-count", type: "symbol", source: "sites", filter: ["has", "point_count"],
    layout: { "text-field": ["get", "point_count_abbreviated"], "text-font": medium, "text-size": 13,
              "text-allow-overlap": true },
    paint: { "text-color": "#ffffff" },
  },
  {
    id: "sites", type: "circle", source: "sites", filter: ["!", ["has", "point_count"]],
    paint: {
      "circle-color": ["match", ["get", "type"], "wreck", "#5e5ce6", "cave", "#a2845e", "#0a84ff"],
      "circle-radius": 8, "circle-stroke-color": "#ffffff", "circle-stroke-width": 2,
    },
  },
  {
    id: "site-labels", type: "symbol", source: "sites", filter: ["!", ["has", "point_count"]], minzoom: 11,
    layout: {
      "text-field": ["get", "name"], "text-font": medium, "text-size": 12,
      "text-anchor": "top", "text-offset": [0, 1], "text-optional": true,
    },
    paint: { "text-color": "#1c1c1e", "text-halo-color": "#ffffff", "text-halo-width": 1.5 },
  },
];

const base = layers("protomaps", namedFlavor("light"), { lang: "en" });
// Contours go under the basemap's labels; dive sites on top of everything.
const firstSymbol = base.findIndex((l) => l.type === "symbol");

const style = {
  version: 8,
  glyphs: "{ASSETS}/fonts/{fontstack}/{range}.pbf",
  sprite: "{ASSETS}/sprites/light",
  sources: {
    protomaps: {
      type: "vector",
      url: "pmtiles://{ASSETS}/malta.pmtiles",
      attribution: "© OpenStreetMap",
    },
    contours: { type: "geojson", data: "{ASSETS}/malta-contours.geojson" },
    extras: { type: "geojson", data: "{ASSETS}/malta-extras.geojson" },
    sites: { type: "geojson", data: "{ASSETS}/malta-dive-sites.geojson", cluster: true,
             clusterRadius: 40, clusterMaxZoom: 13 },
  },
  layers: [...base.slice(0, firstSymbol), ...contourLayers, ...base.slice(firstSymbol), ...extraLayers, ...siteLayers],
};

const out = process.argv[2] ?? "style.json";
writeFileSync(out, JSON.stringify(style));
const fonts = new Set(style.layers.flatMap((l) => {
  const f = l.layout?.["text-font"];
  return Array.isArray(f) && typeof f[0] === "string" ? [f.join(",")] : [];
}));
console.log(`Wrote ${out}: ${style.layers.length} layers; fonts: ${[...fonts].join(" | ")}`);
