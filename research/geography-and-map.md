# Geography and Map Method

## The shape of the town (mental model)
- Town center and Common: roughly the middle-south of town, at the northeast tip of **Bare Hill Pond**.
- **West**: Still River village and the **Nashua River / Oxbow** floodplain, with a ridge above it (Prospect Hill, Fruitlands, St. Benedict's).
- **Northwest**: **Devens** (old Shabikin), with Mirror Lake and the fusion lab.
- **Northeast**: the **Shaker Village** along Shaker Road and South Shaker Road.
- **East**: orchard country and **Pinnacle Road / Oak Ridge Observatory**.
- **South**: Bare Hill Pond, Bare Hill sanctuary, and the Bolton line.
- **Route 2** crosses the north of town. **Route 110/111** (Ayer Road and Massachusetts Avenue) run through it. **I-495** clips the southeast corner. [General]

## Data extraction (scripts/geography.py)
- The Overpass API returned 406 errors and timed out, and a single OSM API call over the whole area exceeded the 50,000-node limit.
- The fix was to fetch **16 small tiles** from `https://api.openstreetmap.org/api/0.6/map?bbox=…`, cache them in `.map-cache/`, then merge and deduplicate.
- Roads are kept by `highway=*` class. Water comes from `natural=water`, waterways, and reservoirs. Multipolygon relations are assembled into closed **outer** and **inner (island)** rings. Bare Hill Pond's 15 islands survive this step.
- Named points come from POIs and polygon centroids.
- **Output**: `browser-after-dark/assets/geography.json`, with bounds [−71.66, 42.46, −71.54, 42.58]. It holds 884 road features, 180 water features, 15 islands, and 72 landmarks. It is licensed under ODbL 1.0 and requires attribution: "© OpenStreetMap contributors."

## Projection used in the game
Equirectangular, with longitude scaled by cos(latitude) so shapes are not stretched. North is up.

```
x = 240 + (lon + 71.596) * cos(42.5°) * 4500
y = 185 - (lat - 42.516) * 4500
```

- The map is a 480×370 logical pixel grid, centered at (−71.596, 42.516).
- The Common's landmarks are less than 300 m apart, so the game draws a **magnified inset**, labeled as such, at roughly x 337–466, y 268–354. The main map stays geographically true.

## Accuracy notes
- Landmark pins use real OSM coordinates. Two story locations are nudged slightly for readability: the pond pin (−71.5895, 42.4950) and the Oxbow pin (−71.6280, 42.4995).
- Building interiors and scene art are invented and are not floor plans.
- The bounding box includes parts of Ayer, Shirley, Bolton, Boxborough, and Lancaster. That is why some street and pond names do not belong to Harvard.
