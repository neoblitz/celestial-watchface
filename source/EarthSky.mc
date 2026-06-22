using Toybox.Math;

// Project the bright-star catalog (RA/Dec from MarsSky) to the observer's
// local horizon on Earth. Returns the same StarPos-like shape as
// MarsSky.compute so the view's drawing loop can be shared.
module EarthSky {

    class StarPos {
        var alt;
        var az;
        var r;
        var name;
    }

    function compute(unixSeconds, latDeg, eastLonDeg) {
        var et = EarthTime.compute(unixSeconds, latDeg, eastLonDeg);
        var stars = MarsSky.STARS;
        var names = MarsSky.NAMES;
        var out = [];
        for (var i = 0; i < stars.size(); i += 1) {
            var ra  = stars[i][0];
            var dec = stars[i][1];
            var aa = EarthTime.altAzFromRaDec(ra, dec, et.lstHours, latDeg);
            var sp = new StarPos();
            sp.alt  = aa[0];
            sp.az   = aa[1];
            sp.r    = stars[i][2];
            sp.name = names[i];
            out.add(sp);
        }
        return out;
    }
}
