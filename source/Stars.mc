using Toybox.Math;
using Toybox.Lang;

// Astronomically-grounded star positions as seen from Gale Crater, Mars.
//
// Approach (per frame, for ~40 bright stars):
//   1. Star J2000 (RA, Dec) -> unit vector in Earth's equatorial frame.
//   2. Rotate into MARS's equatorial frame using the IAU pole orientation
//      (Mars's pole is in Cygnus, RA 317.68°, Dec 52.89°), so the sky does
//      NOT spin around Polaris — the Martian pole star is roughly Deneb.
//   3. Compute Mars's prime-meridian angle W and hence Gale's inertial
//      longitude theta. Mars Local Sidereal Time at Gale = theta.
//   4. Hour angle H = theta - RA_mars. Then alt/az from H, dec_mars and
//      Gale's planetographic latitude.
//
// Accuracy: positions good to small fractions of a degree (atmospheric
// refraction, proper motion, precession-since-J2000 all ignored — none of
// which matters at this screen resolution). Yale BSC magnitudes baked in.
module Stars {

    // IAU Mars pole orientation (J2000), degrees.
    const POLE_RA  = 317.68143d;
    const POLE_DEC =  52.88650d;

    // Mars prime-meridian rotation: W = W0 + WDOT * days_since_J2000_TT.
    const W0   = 176.630d;
    const WDOT = 350.89198226d;

    function d2r(x) { return x * Math.PI / 180.0d; }
    function r2d(x) { return x * 180.0d / Math.PI; }
    function norm360(x) { return x - 360.0d * Math.floor(x / 360.0d); }

    // 40 brightest stars: [RA_deg, Dec_deg, screen_radius_px].
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

    // Result for a single star.
    class StarPos {
        var alt;   // altitude, deg (>0 means above horizon)
        var az;    // azimuth from north (clockwise), deg [0,360)
        var r;     // dot radius px (3=brightest, 1=faintest)
        var name;  // common name string
    }

    function earthToMarsMatrix() {
        var paR = d2r(POLE_RA);
        var pdR = d2r(POLE_DEC);
        var zx = Math.cos(pdR) * Math.cos(paR);
        var zy = Math.cos(pdR) * Math.sin(paR);
        var zz = Math.sin(pdR);
        var nR = d2r(POLE_RA + 90.0d);
        var xx = Math.cos(nR);
        var xy = Math.sin(nR);
        var xz = 0.0d;
        var yx = zy * xz - zz * xy;
        var yy = zz * xx - zx * xz;
        var yz = zx * xy - zy * xx;
        return [[xx, xy, xz], [yx, yy, yz], [zx, zy, zz]];
    }

    // Compute positions for every catalog star at the given UTC time and site.
    // Returns Array of StarPos in catalog order; only entries with alt>0 should
    // be drawn.
    function compute(unixSeconds, latDeg, eastLonDeg) {
        var s = unixSeconds.toDouble();
        var jdtt = 2440587.5d + s / 86400.0d + 69.184d / 86400.0d;
        var d = jdtt - 2451545.0d;

        // Gale's inertial longitude in Mars equatorial frame.
        var w     = norm360(W0 + WDOT * d);
        var theta = d2r(norm360(w + eastLonDeg));

        var lat = d2r(latDeg);
        var R = earthToMarsMatrix();

        // Local east/north unit vectors at Gale (in Mars-equatorial frame).
        var sinL = Math.sin(lat); var cosL = Math.cos(lat);
        var sinT = Math.sin(theta); var cosT = Math.cos(theta);
        var ux = cosL * cosT;        // up
        var uy = cosL * sinT;
        var uz = sinL;
        var ex = -sinT;              // east
        var ey =  cosT;
        var ez = 0.0d;
        var nx = -sinL * cosT;       // north
        var ny = -sinL * sinT;
        var nz =  cosL;

        var out = [];
        for (var i = 0; i < STARS.size(); i += 1) {
            var ra  = d2r(STARS[i][0]);
            var dec = d2r(STARS[i][1]);
            // Unit vector in Earth-equatorial frame.
            var cd = Math.cos(dec);
            var ex0 = cd * Math.cos(ra);
            var ey0 = cd * Math.sin(ra);
            var ez0 = Math.sin(dec);
            // Rotate into Mars-equatorial.
            var mx = R[0][0]*ex0 + R[0][1]*ey0 + R[0][2]*ez0;
            var my = R[1][0]*ex0 + R[1][1]*ey0 + R[1][2]*ez0;
            var mz = R[2][0]*ex0 + R[2][1]*ey0 + R[2][2]*ez0;
            // Project to local up/east/north basis.
            var u = mx*ux + my*uy + mz*uz;
            var e = mx*ex + my*ey + mz*ez;
            var n = mx*nx + my*ny + mz*nz;
            var sp = new StarPos();
            sp.alt = r2d(Math.asin(u));
            sp.az  = norm360(r2d(Math.atan2(e, n)));
            sp.r    = STARS[i][2];
            sp.name = NAMES[i];
            out.add(sp);
        }
        return out;
    }
}
