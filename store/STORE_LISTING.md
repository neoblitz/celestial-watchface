# Connect IQ Store Listing — Celestial Watchface

Copy/paste these into the fields at https://apps.garmin.com/developer when you
upload `bin/CelestialWatchface.iq`.

---

## App name
Celestial Watchface

## Category
Watch Face

## Short description (≈ one line, shown in lists)
Tell time from any of the 9 planets — real sky, sun, and day/night for each world.

## Full description

Stand on any planet in the solar system and read the time from its sky.

Celestial Watchface is an analog watch face that re-creates the real sky as seen
from a chosen world. Pick your planet in the settings and the entire face adapts:

• ANALOG TIME — minute and hour hands in the selected planet's signature color,
  showing your normal wrist time at a glance.

• DAY / NIGHT RING — a 24-hour dial around the edge showing that planet's real
  sunrise-to-sunset arc at a famous landmark, with a marker at the current local
  solar time. Watch Jupiter's ring sweep every ~10 hours, or Mercury's barely
  crawl across its 176-Earth-day "day."

• REAL STARS — the ~40 brightest stars, projected through each planet's actual
  pole orientation. The Martian sky doesn't spin around Polaris — its pole star
  is roughly Deneb — and Celestial Watchface gets this right. Bright stars are
  labeled (Sirius, Canopus, Vega, Antares…).

• THE OTHER PLANETS — see Earth, Jupiter, Saturn and the rest drift across the
  sky in their true colors, computed with real Keplerian orbital mechanics.

• THE SUN, TO SCALE — drawn at its real position and apparent size. From Mercury
  it looms huge; from Pluto it's a distant pinprick.

• LANDMARK SITES — observe from the Curiosity rover at Gale Crater on Mars,
  Jupiter's Great Red Spot, Saturn's north polar hexagon, Pluto's Tombaugh
  Regio ("the heart"), and more. On Earth, your nearest city is shown using
  your watch's GPS.

• MOONS OF MARS — when observing from Mars, Phobos and Deimos appear in the sky
  at their computed positions.

All astronomy is computed on the watch — no phone connection needed once set.

Choose your world: Mercury · Venus · Earth · Mars · Jupiter · Saturn · Uranus ·
Neptune · Pluto.

## What's New (version 1.0.0)
First release. Supports the full round-AMOLED watch family. Burn-in-safe
always-on display.

## Permissions — justification text
**Positioning (GPS):** Used only in Earth mode to show the sky, sunrise/sunset,
and nearest city for the wearer's current location. The watch's last-known
position is used; no continuous GPS tracking, and no location data leaves the
device.

## Tags / keywords
astronomy, planets, solar system, analog, stars, mars, space, celestial, sky,
day night, sun, science

## Supported devices
Auto-detected from the .iq package (22 round-AMOLED models): Venu 2 / 2S /
2 Plus / 3 / 3S / 4, Vivoactive 5 / 6, Forerunner 165 / 265 / 265S / 965 / 970,
epix Gen 2 / Pro, Fenix 8, D2 Mach 1, MARQ Gen 2.

## Settings (configured by the user in Garmin Connect)
- Observer planet (dropdown, default Mars)
- Show local solar time digital readout (toggle)
- Phobos / Deimos phase calibration (Mars only, advanced)

## Assets checklist
- [x] Store icon: store/store_icon.png (512×512)
- [x] Screenshots: screenshots/*.png (18 — day & night for all 9 planets)
- [ ] (optional) A short hero/banner image
