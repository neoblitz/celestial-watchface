using Toybox.Math;
using Toybox.Lang;

// Keplerian orbital propagation. Given a body's J2000 mean ecliptic elements,
// returns its heliocentric ecliptic position [X, Y, Z] in AU at a given
// number of days since J2000 (TT).
//
// Used by Site.mc for sun positioning and inter-planet sky projections.
// Element arrays live in Bodies.ELEM; pass them in directly.
module Kepler {

    function d2r(x) { return x * Math.PI / 180.0d; }
    function norm360(x) { return x - 360.0d * Math.floor(x / 360.0d); }

    // Newton iteration on Kepler's equation: M = E - e sin E.
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

    // Heliocentric ecliptic position [X, Y, Z] in AU.
    // el = [a, e, i_deg, Omega_deg, longPeri_deg, L0_deg, Ldot_deg_per_day]
    function helioEcliptic(el, d) {
        var a = el[0]; var e = el[1];
        var i = d2r(el[2]); var O = d2r(el[3]);
        var pi_lon = d2r(el[4]);
        var L = d2r(norm360(el[5] + el[6] * d));
        var w = pi_lon - O;             // argument of perihelion
        var M = L - pi_lon;             // mean anomaly
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
}
