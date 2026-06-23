# Celestial Watchface — Garmin Venu 3

A celestial watchface that lets you pretend you're standing on **any of the 9
classical planets** in the solar system. Pick the planet in the phone settings;
the watchface then shows local sol time on that world, the day/night cycle at
the observer's spot, real stars projected through that planet's pole, and the
other planets of the solar system as they would appear in that sky.

The watch's wrist time (24-hour Earth clock you use day to day) is always shown
as analog hands in the center, colored to match the selected planet.

## What's on the face

- **Analog clock hands** — minute (white) + hour (planet-colored). No second
  hand. Shows your wrist time regardless of which planet is selected.
- **Site label at the top** — e.g. `MARS · GALE`, `JUPITER · RED SPOT`,
  `EARTH · SAN FRANCISCO`. Clearly identifies the world and the spot on it.
- **Day/night ring around the edge** — 24-hour dial showing the *selected
  planet's* day at the *observer's* location. See the table below for what the
  marker speed and arc length mean per planet.
- **Heart-rate row** at the top (❤ + bpm).
- **Compass markers** (`N`/`E`/`S`/`W`) at night, anchoring the sky to local
  cardinal directions.
- **Real stars** at night, projected through that planet's pole. Up to 8 of
  the brightest visible stars and planets get name labels (Sirius, Canopus,
  Vega, Antares, Jupiter, Saturn, …).
- **Other planets** drawn in their characteristic colors. The catalog rotates
  appropriately — Mars is visible from Jupiter, Earth is visible from Pluto, etc.
- **Phobos & Deimos** only in Mars mode (Mars has dedicated moon tracking).
- **Daytime scene** when the sun is above the horizon: sky tint, horizon glow,
  low sun, foreground hill silhouette. Tones shift per planet (Mars butterscotch,
  Earth blue, Jupiter tan-glow, etc.).

## The 9 worlds

Mode is set via Garmin Connect → watchface settings → **Observer planet**.

| # | World | Observer site | Notes on the location |
|---|---|---|---|
| 0 | Mercury | Caloris Basin (30°N, 195°E) | One of the largest impact basins in the solar system |
| 1 | Venus | Maxwell Montes (65.2°N, 3.3°E) | Tallest mountain on Venus, named after James Clerk Maxwell |
| 2 | Earth | Your last-known GPS position | Nearest of ~210 bundled cities shown in label |
| 3 | Mars | Gale Crater (−4.59°N, 137.44°E) | Curiosity rover's landing site |
| 4 | Jupiter | Great Red Spot (−22°N, 240°E) | The iconic centuries-old storm |
| 5 | Saturn | North Polar Hexagon (78°N, 0°E) | Saturn's bizarre persistent hexagonal jet stream |
| 6 | Uranus | Cloud Bands (30°N, 0°E) | Featureless atmosphere has no real landmarks — generic spot |
| 7 | Neptune | Great Dark Spot (−22°N, 0°E) | Voyager 2 spotted it in 1989; has come and gone since |
| 8 | Pluto | Tombaugh Regio (25°N, 155°E) | The famous nitrogen-ice "heart" from New Horizons |

The lat/lon use each planet's IAU-defined coordinate system (planetographic for
solid bodies, System II/III for the gas giants). Gas-giant "sites" are at
cloud-top altitude — there's no solid surface to stand on.

## What the day/night ring means per planet

The ring is always a 24-hour dial — **noon at the top, midnight at the bottom**.
The marker shows the current **local solar hour at the observer's site**. The
amber arc spans **sunrise → sunset** at that latitude. What varies between
planets is *how fast the marker moves* and *how long the arc is*.

| Planet | Solar day | Ring marker behavior | Day-arc length |
|---|---|---|---|
| Mercury | ~176 Earth days | Visually static — moves ~2° per Earth day. The ring is more a thermometer than a clock. | ~12 ring-hours (tilt is essentially 0°) |
| Venus | ~117 Earth days, retrograde | Static AND moving the opposite direction. | ~12 ring-hours (tilt 2.6°) |
| Earth | 24 Earth hours | 1:1 with your wrist clock — one ring rotation per Earth day. | Varies with lat + season; e.g. ~14.6h at SF in June |
| Mars (Gale) | 24.66 Earth hours | One full rotation per Martian sol — slightly slower than Earth. | ~12.2h today; varies with Mars's seasons |
| Jupiter | 9.93 Earth hours | **Visibly sweeps** — one rotation every ~10 Earth hours. | ~12 ring-hours (tilt 3.1°) |
| Saturn | 10.66 Earth hours | Visibly sweeps. At North Hex (78°N) the sun is up or down for years at a time — arc can be all-day or all-night. | Highly seasonal (tilt 26.7°); at high lat varies 0–24h |
| Uranus | 17.24 Earth hours, retrograde | Sweeps once per ~17 Earth hours, *backwards*. | Extreme — tilt is 98° (on its side). Equator gets near-polar lighting. |
| Neptune | 16.11 Earth hours | Sweeps once per ~16 Earth hours. | Seasonal (tilt 28.3°); at -22°N varies through the year |
| Pluto | ~6.4 Earth days | Marker moves only ~4° per Earth day. | Tilt 122° → extreme seasonal swings |

**Why some marker behavior looks "wrong":** It's accurate, not broken. Mercury
genuinely takes ~176 Earth days to complete one sunrise-to-sunrise cycle, so
the ring marker really should barely move. Uranus genuinely rotates retrograde
on its side. The face is reflecting physics, not artifact.

## Build & install

You need Garmin's free **Connect IQ SDK** (Java 18+ is a prerequisite).

1. Install the SDK Manager from <https://developer.garmin.com/connect-iq/sdk/>,
   sign in with a free Garmin account, download the latest SDK and the
   **Venu 3** device files.
2. Build:
   ```bash
   cd ~/Dropbox/Private/Projects/CelestialWatchface
   ./build.sh            # creates bin/CelestialWatchface.prg
   ./build.sh sim        # also opens the simulator with the watchface loaded
   ```
   The signing key is read from `~/.garmin/celestial/developer_key.der`
   (kept outside this synced folder so the private key never reaches the
   cloud). Override the path with `CIQ_KEY=/path/to/key.der`. The master
   `.pem` is backed up in 1Password — if the key is ever missing, restore
   it from there rather than generating a new one (a new key would break
   store updates).
3. Sideload to the watch:
   - Connect the watch by USB.
   - Copy `bin/CelestialWatchface.prg` to the watch's `GARMIN/Apps/` folder.
   - Eject, then pick "Celestial Watchface" from the watchface list.

## Phone settings

| Setting | Default | What it does |
|---|---|---|
| Observer planet | Mars (Gale) | Dropdown of all 9 worlds |
| Show Mars (Gale) time | off | Toggles a digital sol-time line (e.g. `MARS  18:42` or `JUPITER  04:23`) below the analog hands. Hidden in Earth mode. |
| Phobos phase calibration (deg) | 0 | Tweak ±180° if Phobos's modeled up/down times drift from a trusted ephemeris. Mars mode only. |
| Deimos phase calibration (deg) | 0 | Same for Deimos. |

## Project layout

```
manifest.xml           app id, targets venu3, asks for Position permission
monkey.jungle          build config
build.sh               builds a signed .prg (and can launch the sim)
source/
  CelestialApp.mc     application entry point
  CelestialView.mc    all drawing — analog hands, sky, day/night ring, site label
  Bodies.mc           orbital elements + IAU pole + rotation + landmark site
                      for the 9 worlds
  Site.mc             generic observer-on-planet astronomy: sun, sunrise/sunset,
                      LST, star catalog projection, other planets in the sky
  Stars.mc            bundled bright-star catalog (RA/Dec, name, magnitude)
  Kepler.mc           Keplerian orbital propagation (helioEcliptic helper)
  MarsMoons.mc        Phobos & Deimos topocentric positions (Mars-only feature)
  Cities.mc           ~210 world cities for Earth's nearest-city lookup
resources/
  strings/strings.xml
  drawables/launcher_icon.png
  properties/properties.xml   planetIndex, showMarsTime, phobosCal, deimosCal
  settings/settings.xml       phone-side settings UI
```

## Accuracy notes

- Star positions: ~1° accuracy (mean orbital elements; no proper motion, no
  precession since J2000). Fine at watch-screen resolution.
- Planet positions: same — Keplerian propagation from J2000 mean elements.
- Mars solar position uses the higher-precision **Mars24** algorithm
  (Allison & McEwen) for the Gale-specific MarsMoons module; the generic
  Site module uses a simpler model that's good to ~1°.
- The IAU pole + prime-meridian values bundled in Bodies are accurate as of
  the 2009 IAU Report on Cartographic Coordinates and Rotational Elements.
