using Toybox.Math;
using Toybox.Lang;

// Apparent positions of selected solar-system bodies as seen from Gale Crater.
//
// Algorithm:
//   1. Propagate each body's J2000 ecliptic Keplerian elements (mean longitude
//      via linear rate, eccentric anomaly via Newton iteration on Kepler's eq).
//   2. Translate from heliocentric to Mars-centric.
//   3. Rotate ecliptic -> Earth-equatorial (J2000 obliquity 23.44 deg),
//      then Earth-equatorial -> Mars-equatorial (Mars IAU pole).
//   4. Project to Gale's local up/east/north horizon (alt/az).
//
// Accuracy is ~1 degree at watch resolution; good enough for "yes, Jupiter is
// in this part of the sky." Mercury and Mars itself are intentionally excluded
// (Mercury not requested; you can't see Mars from Mars). The Moon is computed
// separately via a simplified lunar mean longitude; from Mars distance the
// Earth-Moon angular separation is ~0.1 deg so they'll plot as a tight pair.
module Kepler {

    // [a (AU), e, i (deg), Omega (deg), longPeri (deg), L0 (deg), Ldot (deg/day)]
    const MERCURY = [  0.38709927d, 0.20563593d,  7.00497902d,  48.33076593d,  77.45779628d, 252.25032350d, 4.09233444d];
    const VENUS   = [  0.72333566d, 0.00677672d,  3.39467605d,  76.67984255d, 131.60246718d, 181.97909950d, 1.60213034d];
    const EARTH   = [  1.00000261d, 0.01671123d, -0.00001531d,   0.0d,        102.93768193d, 100.46457166d, 0.98560910d];
    const MARS    = [  1.52371034d, 0.09339410d,  1.84969142d,  49.55953891d, -23.94362959d,  -4.55343205d, 0.52403840d];
    const JUPITER = [  5.20288700d, 0.04838624d,  1.30439695d, 100.47390909d,  14.72847983d,  34.39644051d, 0.08308529d];
    const SATURN  = [  9.53667594d, 0.05386179d,  2.48599187d, 113.66242448d,  92.59887831d,  49.95424423d, 0.03344414d];
    const URANUS  = [ 19.18916464d, 0.04725744d,  0.77263783d,  74.01692503d, 170.95427630d, 313.23810451d, 0.01172834d];
    const NEPTUNE = [ 30.06992276d, 0.00859048d,  1.77004347d, 131.78422574d,  44.96476227d, -55.12002969d, 0.00598103d];

    const OBLIQUITY = 23.4393d;
    const POLE_RA   = 317.68143d;
    const POLE_DEC  =  52.88650d;
    const W0        = 176.630d;
    const WDOT      = 350.89198226d;

    function d2r(x) { return x * Math.PI / 180.0d; }
    function r2d(x) { return x * 180.0d / Math.PI; }
    function norm360(x) { return x - 360.0d * Math.floor(x / 360.0d); }

    function kepler(M_rad, e) {
        var E = M_rad;
        for (var iter = 0; iter < 8; iter += 1) {
            var dE = (E - e * Math.sin(E) - M_rad) / (1.0d - e * Math.cos(E));
            E = E - dE;
            if (dE < 0) { dE = -dE; }
            if (dE < 1.0e-9d) { break; }
        }
        return E;
    }

    // Heliocentric ecliptic position [X, Y, Z] in AU for given orbital elements.
    function helioEcliptic(el, d) {
        var a = el[0]; var e = el[1];
        var i = d2r(el[2]); var O = d2r(el[3]);
        var pi_lon = d2r(el[4]);
        var L = d2r(norm360(el[5] + el[6] * d));
        var w = pi_lon - O;
        var M = L - pi_lon;
        var Erad = kepler(M, e);
        var xPrime = a * (Math.cos(Erad) - e);
        var yPrime = a * Math.sqrt(1.0d - e * e) * Math.sin(Erad);
        var cO = Math.cos(O);  var sO = Math.sin(O);
        var cW = Math.cos(w);  var sW = Math.sin(w);
        var cI = Math.cos(i);  var sI = Math.sin(i);
        var X = (cO*cW - sO*sW*cI) * xPrime + (-cO*sW - sO*cW*cI) * yPrime;
        var Y = (sO*cW + cO*sW*cI) * xPrime + (-sO*sW + cO*cW*cI) * yPrime;
        var Z = (sW*sI) * xPrime + (cW*sI) * yPrime;
        return [X, Y, Z];
    }

    // Earth-equatorial → Mars-equatorial rotation matrix (constant).
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
        var yx = zy*xz - zz*xy;
        var yy = zz*xx - zx*xz;
        var yz = zx*xy - zy*xx;
        return [[xx, xy, xz], [yx, yy, yz], [zx, zy, zz]];
    }

    class PlanetPos {
        var name;   // display name
        var alt;    // altitude at Gale, deg
        var az;     // azimuth from N (clockwise), deg [0,360)
        var r;      // dot radius px
        var color;  // RGB color
    }

    // Build a PlanetPos given the heliocentric ecliptic position of the body
    // and Mars, plus the local horizon basis at Gale.
    function makePos(name, color, rad, helioBody, marsPos, R,
                    ux, uy, uz, ex, ey, nx, ny, nz) {
        var dx = helioBody[0] - marsPos[0];
        var dy = helioBody[1] - marsPos[1];
        var dz = helioBody[2] - marsPos[2];
        // Ecliptic → Earth-equatorial.
        var ce = Math.cos(d2r(OBLIQUITY));
        var se = Math.sin(d2r(OBLIQUITY));
        var qx = dx;
        var qy = dy * ce - dz * se;
        var qz = dy * se + dz * ce;
        // Earth-eq → Mars-eq.
        var mx = R[0][0]*qx + R[0][1]*qy + R[0][2]*qz;
        var my = R[1][0]*qx + R[1][1]*qy + R[1][2]*qz;
        var mz = R[2][0]*qx + R[2][1]*qy + R[2][2]*qz;
        var u = mx*ux + my*uy + mz*uz;
        var e = mx*ex + my*ey;
        var n = mx*nx + my*ny + mz*nz;
        var mag = Math.sqrt(mx*mx + my*my + mz*mz);
        var p = new PlanetPos();
        p.name  = name;
        p.alt   = r2d(Math.asin(u / mag));
        p.az    = norm360(r2d(Math.atan2(e, n)));
        p.r     = rad;
        p.color = color;
        return p;
    }

    function compute(unixSeconds, latDeg, eastLonDeg) {
        var s = unixSeconds.toDouble();
        var jdtt = 2440587.5d + s / 86400.0d + 69.184d / 86400.0d;
        var d = jdtt - 2451545.0d;

        var marsPos    = helioEcliptic(MARS, d);
        var earthHelio = helioEcliptic(EARTH, d);

        var R = earthToMarsMatrix();
        var w = norm360(W0 + WDOT * d);
        var theta = d2r(norm360(w + eastLonDeg));
        var lat = d2r(latDeg);
        var sL = Math.sin(lat); var cL = Math.cos(lat);
        var sT = Math.sin(theta); var cT = Math.cos(theta);
        var ux = cL * cT; var uy = cL * sT; var uz = sL;
        var ex = -sT; var ey = cT;
        var nx = -sL * cT; var ny = -sL * sT; var nz = cL;

        var out = [];
        out.add(makePos("Mercury", 0xC0B090, 2, helioEcliptic(MERCURY, d),
                        marsPos, R, ux,uy,uz, ex,ey, nx,ny,nz));
        out.add(makePos("Venus",   0xE0E8FF, 4, helioEcliptic(VENUS,   d),
                        marsPos, R, ux,uy,uz, ex,ey, nx,ny,nz));
        out.add(makePos("Earth",   0x88AAFF, 4, earthHelio,
                        marsPos, R, ux,uy,uz, ex,ey, nx,ny,nz));
        out.add(makePos("Jupiter", 0xD8C898, 4, helioEcliptic(JUPITER, d),
                        marsPos, R, ux,uy,uz, ex,ey, nx,ny,nz));
        out.add(makePos("Saturn",  0xE0D080, 3, helioEcliptic(SATURN,  d),
                        marsPos, R, ux,uy,uz, ex,ey, nx,ny,nz));
        out.add(makePos("Uranus",  0x80D0E0, 2, helioEcliptic(URANUS,  d),
                        marsPos, R, ux,uy,uz, ex,ey, nx,ny,nz));
        out.add(makePos("Neptune", 0x6088FF, 2, helioEcliptic(NEPTUNE, d),
                        marsPos, R, ux,uy,uz, ex,ey, nx,ny,nz));
        return out;
    }
}
