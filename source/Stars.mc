using Toybox.Lang;

// Catalog of the ~40 brightest stars (Yale BSC subset), with J2000 RA/Dec,
// common name, and a pre-quantized screen radius derived from apparent
// magnitude (3 = brightest, 1 = faintest). Used by Site.stars() to project
// the sky to any planet's local horizon.
//
// No proper motion, no precession-since-J2000 — irrelevant at watch resolution.
module Stars {

    // [RA_deg, Dec_deg, screen_radius_px]
    const STARS = [
        [ 101.288d, -16.716d, 3], [  95.988d, -52.696d, 3],
        [ 213.917d,  19.183d, 2], [ 219.900d, -60.835d, 3],
        [ 279.236d,  38.784d, 2], [  79.173d,  45.998d, 2],
        [  78.635d,  -8.202d, 2], [ 114.825d,   5.225d, 2],
        [  24.429d, -57.237d, 2], [  88.793d,   7.407d, 2],
        [ 210.956d, -60.373d, 2], [ 297.695d,   8.868d, 2],
        [ 186.650d, -63.099d, 2], [  68.981d,  16.509d, 2],
        [ 247.352d, -26.432d, 1], [ 201.298d, -11.161d, 1],
        [ 116.329d,  28.026d, 1], [ 344.412d, -29.622d, 1],
        [ 310.359d,  45.280d, 1], [ 191.929d, -59.689d, 1],
        [ 152.093d,  11.967d, 1], [ 104.655d, -28.972d, 1],
        [ 263.401d, -37.104d, 1], [ 113.649d,  31.888d, 1],
        [ 187.791d, -57.113d, 1], [  81.282d,   6.350d, 1],
        [  81.573d,  28.608d, 1], [ 138.300d, -69.717d, 1],
        [  84.054d,  -1.202d, 1], [ 332.058d, -46.961d, 1],
        [  85.189d,  -1.943d, 1], [ 193.506d,  55.960d, 1],
        [  51.081d,  49.861d, 1], [ 165.931d,  61.751d, 1],
        [ 107.099d, -26.393d, 1], [ 276.043d, -34.385d, 1],
        [ 125.628d, -59.510d, 1], [ 206.884d,  49.313d, 1],
        [ 264.333d, -42.998d, 1], [  89.885d,  44.947d, 1]
    ] as Lang.Array<Lang.Array<Lang.Numeric>>;

    // Parallel name array (kept separate so the numeric catalog stays compact).
    const NAMES = [
        "Sirius", "Canopus", "Arcturus", "Rigel Kent", "Vega",
        "Capella", "Rigel", "Procyon", "Achernar", "Betelgeuse",
        "Hadar", "Altair", "Acrux", "Aldebaran", "Antares",
        "Spica", "Pollux", "Fomalhaut", "Deneb", "Mimosa",
        "Regulus", "Adhara", "Shaula", "Castor", "Gacrux",
        "Bellatrix", "Elnath", "Miaplacidus", "Alnilam", "Alnair",
        "Alnitak", "Alioth", "Mirfak", "Dubhe", "Wezen",
        "Kaus Aust.", "Avior", "Alkaid", "Sargas", "Menkalinan"
    ] as Lang.Array<Lang.String>;
}
