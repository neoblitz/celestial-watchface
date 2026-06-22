using Toybox.Math;

// Approximate topocentric positions of Phobos and Deimos as seen from a site on
// Mars. Uses circular, equatorial-plane orbits propagated by mean motion, then a
// full 3-D vector reduction to the observer's local horizon (so parallax — which is
// large for Phobos, only ~2.8 Mars radii away — is handled correctly).
//
// WHAT IS RELIABLE: which moon is above the horizon, its altitude/azimuth to within
// ~a degree, and the characteristic motion (Phobos rising in the WEST ~3x per sol,
// Deimos drifting slowly and staying up for days).
//
// WHAT IS APPROXIMATE: the absolute along-orbit phase. The epoch mean longitudes
// (PH_L0 / DE_L0) are best-effort; if rise/set timing looks shifted, calibrate by
// nudging PH_CAL / DE_CAL (degrees) against a trusted source on a known date.
module MarsMoons {

    const R_MARS = 3396.19d;                 // Mars equatorial radius, km

    // Mars prime-meridian angle (IAU): W = W0 + WDOT * d, d = days since J2000 (TT).
    const W0   = 176.630d;
    const WDOT = 350.89198226d;              // deg/day (sidereal rotation)

    // Phobos orbital elements (circular/equatorial approximation).
    const PH_A   = 9376.0d;                  // semi-major axis, km
    const PH_N   = 1128.844556d;             // mean motion, deg/day
    const PH_L0  = 232.412d;                 // mean longitude at J2000 (approx)

    // Deimos orbital elements.
    const DE_A   = 23463.2d;
    const DE_N   = 285.161888d;
    const DE_L0  = 28.963d;

    function d2r(x) { return x * Math.PI / 180.0d; }
    function r2d(x) { return x * 180.0d / Math.PI; }
    function norm360(x) { return x - 360.0d * Math.floor(x / 360.0d); }

    class MoonResult {
        var up;    // Boolean: above the local horizon
        var alt;   // altitude, degrees
        var az;    // azimuth from north, degrees [0,360)
    }

    class MoonsState {
        var phobos;
        var deimos;
    }

    function moonState(d, a, n, l0, cal, latDeg, eastLonDeg) {
        var lm = norm360(l0 + n * d + cal);
        var w  = norm360(W0 + WDOT * d);
        var theta = norm360(w + eastLonDeg);     // observer inertial longitude

        var phi = d2r(latDeg);
        var lmr = d2r(lm);
        var thr = d2r(theta);

        // Moon position vector (Mars-equatorial inertial frame, km).
        var mx = a * Math.cos(lmr);
        var my = a * Math.sin(lmr);
        var mz = 0.0d;

        // Observer unit vector (local "up") and surface position.
        var ox = Math.cos(phi) * Math.cos(thr);
        var oy = Math.cos(phi) * Math.sin(thr);
        var oz = Math.sin(phi);
        var px = R_MARS * ox;
        var py = R_MARS * oy;
        var pz = R_MARS * oz;

        // Local east = z x up (normalized), north = up x east.
        var hor = Math.sqrt(ox * ox + oy * oy);
        var ex = -oy / hor;
        var ey =  ox / hor;
        var nx = oy * 0.0d - oz * ey;
        var ny = oz * ex - ox * 0.0d;
        var nz = ox * ey - oy * ex;

        // Vector from observer to moon.
        var rx = mx - px;
        var ry = my - py;
        var rz = mz - pz;
        var rlen = Math.sqrt(rx * rx + ry * ry + rz * rz);

        var upc = rx * ox + ry * oy + rz * oz;
        var ec  = rx * ex + ry * ey;             // east comp (ez = 0)
        var ncp = rx * nx + ry * ny + rz * nz;

        var res = new MoonResult();
        res.alt = r2d(Math.asin(upc / rlen));
        res.az  = norm360(r2d(Math.atan2(ec, ncp)));
        res.up  = (res.alt > 0.0d);
        return res;
    }

    // unixSeconds: UTC seconds since the Unix epoch. lat/eastLon in degrees.
    // phobosCal / deimosCal: user phase-calibration nudges, in degrees (from settings).
    function compute(unixSeconds, latDeg, eastLonDeg, phobosCal, deimosCal) {
        var s = unixSeconds.toDouble();
        var jdtt = 2440587.5d + s / 86400.0d + 69.184d / 86400.0d;
        var d = jdtt - 2451545.0d;

        var out = new MoonsState();
        out.phobos = moonState(d, PH_A, PH_N, PH_L0, phobosCal, latDeg, eastLonDeg);
        out.deimos = moonState(d, DE_A, DE_N, DE_L0, deimosCal, latDeg, eastLonDeg);
        return out;
    }
}
