using Toybox.Lang;

// Definitions for all 9 classical planets of the solar system.
//
// Each row bundles: orbital elements (J2000 mean Keplerian), IAU equatorial
// pole orientation, prime-meridian rotation, mean solar day length, color
// for the analog hour hand, and display name.
//
// Sources: NASA JPL planetary fact sheets, IAU 2009 Report on Cartographic
// Coordinates and Rotational Elements. Negative Wdot = retrograde rotation.
module Bodies {

    const MERCURY = 0;
    const VENUS   = 1;
    const EARTH   = 2;
    const MARS    = 3;
    const JUPITER = 4;
    const SATURN  = 5;
    const URANUS  = 6;
    const NEPTUNE = 7;
    const PLUTO   = 8;

    const NAMES = [
        "Mercury", "Venus", "Earth", "Mars",
        "Jupiter", "Saturn", "Uranus", "Neptune", "Pluto"
    ] as Lang.Array<Lang.String>;

    // Hour-hand color per planet (chosen to roughly match each body's tone).
    const COLORS = [
        0xC0B090, // Mercury: tan
        0xE8E0B0, // Venus: pale yellow-white
        0x5090E0, // Earth: blue
        0xCC4422, // Mars: rust
        0xD8B080, // Jupiter: orange-tan
        0xE0D080, // Saturn: pale yellow
        0x80D0E0, // Uranus: pale cyan
        0x4080E0, // Neptune: deep blue
        0xB89070  // Pluto: brown-tan
    ] as Lang.Array<Lang.Number>;

    // [a (AU), e, i (deg), Omega (deg), longPeri (deg), L0 (deg), Ldot (deg/day)]
    const ELEM = [
        [  0.38709927d, 0.20563593d,  7.00497902d,  48.33076593d,  77.45779628d, 252.25032350d, 4.09233444d],
        [  0.72333566d, 0.00677672d,  3.39467605d,  76.67984255d, 131.60246718d, 181.97909950d, 1.60213034d],
        [  1.00000261d, 0.01671123d, -0.00001531d,   0.0d,        102.93768193d, 100.46457166d, 0.98560910d],
        [  1.52371034d, 0.09339410d,  1.84969142d,  49.55953891d, -23.94362959d,  -4.55343205d, 0.52403840d],
        [  5.20288700d, 0.04838624d,  1.30439695d, 100.47390909d,  14.72847983d,  34.39644051d, 0.08308529d],
        [  9.53667594d, 0.05386179d,  2.48599187d, 113.66242448d,  92.59887831d,  49.95424423d, 0.03344414d],
        [ 19.18916464d, 0.04725744d,  0.77263783d,  74.01692503d, 170.95427630d, 313.23810451d, 0.01172834d],
        [ 30.06992276d, 0.00859048d,  1.77004347d, 131.78422574d,  44.96476227d, -55.12002969d, 0.00598103d],
        [ 39.48211675d, 0.24882730d, 17.14001206d, 110.30393684d, 224.06891629d, 238.92903833d, 0.00396857d]
    ] as Lang.Array<Lang.Array<Lang.Double>>;

    // [poleRA (deg), poleDec (deg)]  -- IAU equatorial pole at J2000.
    const POLES = [
        [281.0103d,   61.4155d  ], // Mercury
        [272.76d,     67.16d    ], // Venus
        [  0.0d,      90.0d     ], // Earth (by definition)
        [317.68143d,  52.88650d ], // Mars
        [268.056595d, 64.495303d], // Jupiter
        [ 40.589d,    83.537d   ], // Saturn
        [257.311d,   -15.175d   ], // Uranus (tipped on its side)
        [299.36d,     42.95d    ], // Neptune
        [132.993d,    -6.163d   ]  // Pluto
    ] as Lang.Array<Lang.Array<Lang.Double>>;

    // [W0 (deg), Wdot (deg/Earth-day)] -- prime meridian. Negative Wdot = retrograde.
    const ROT = [
        [329.5469d,    6.1385025d  ], // Mercury
        [160.20d,     -1.4813688d  ], // Venus (retrograde)
        [280.4606d,  360.9856235d  ], // Earth (= GMST at J2000)
        [176.630d,   350.89198226d ], // Mars
        [284.95d,    870.5360000d  ], // Jupiter System III
        [ 38.90d,    810.7939024d  ], // Saturn System III
        [203.81d,   -501.1600928d  ], // Uranus (retrograde)
        [253.18d,    536.3128492d  ], // Neptune System II
        [302.695d,    56.3625225d  ]  // Pluto
    ] as Lang.Array<Lang.Array<Lang.Double>>;

    // Observer location per planet: [lat (deg), east longitude (deg)].
    // Earth's entry is a placeholder (the view overrides it with GPS).
    // The other 8 are named landmarks chosen for character — see SITE_NAMES.
    const SITES = [
        [ 30.0d,    195.0d   ],  // Mercury: Caloris Basin
        [ 65.2d,      3.3d   ],  // Venus:   Maxwell Montes
        [  0.0d,      0.0d   ],  // Earth:   overridden by Position.getInfo()
        [ -4.5895d, 137.4417d],  // Mars:    Gale Crater (Curiosity)
        [-22.0d,    240.0d   ],  // Jupiter: Great Red Spot (System III)
        [ 78.0d,      0.0d   ],  // Saturn:  North Polar Hexagon
        [ 30.0d,      0.0d   ],  // Uranus:  Cloud bands (no real landmarks)
        [-22.0d,      0.0d   ],  // Neptune: Great Dark Spot (Voyager site)
        [ 25.0d,    155.0d   ]   // Pluto:   Tombaugh Regio ("the heart")
    ] as Lang.Array<Lang.Array<Lang.Double>>;

    // Short, recognizable site label for each planet (used in the top label,
    // e.g. "JUPITER · Red Spot"). Empty for Earth (handled separately via
    // nearest-city lookup from GPS).
    const SITE_NAMES = [
        "Caloris",            // Mercury
        "Maxwell Montes",     // Venus
        "",                   // Earth (filled in by Cities.nearest)
        "Gale",               // Mars
        "Red Spot",           // Jupiter
        "Polar Hexagon",      // Saturn
        "Cloud Bands",        // Uranus
        "Dark Spot",          // Neptune
        "Tombaugh Regio"      // Pluto
    ] as Lang.Array<Lang.String>;

    // Mean solar day length in Earth hours. (Solar day, not sidereal.)
    const SOL_HOURS = [
        4222.6d,  // Mercury (~176 Earth days due to 3:2 spin-orbit resonance)
        2802.0d,  // Venus (~117 Earth days, retrograde)
          24.0d,  // Earth
          24.66d, // Mars
           9.93d, // Jupiter
          10.66d, // Saturn
          17.24d, // Uranus
          16.11d, // Neptune
         153.28d  // Pluto (~6.39 Earth days)
    ] as Lang.Array<Lang.Double>;
}
